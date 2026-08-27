import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/page_request.dart';
import '../../../../shared/cubit/async_guards.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/entities/asset_query.dart';
import '../../../assets/domain/entities/asset_status.dart';
import '../../../assets/domain/usecases/asset_usecases.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../../employees/domain/usecases/employee_usecases.dart';
import '../../domain/entities/handover.dart';
import '../../domain/usecases/handover_usecases.dart';

/// What the handover screen renders.
class HandoverState extends ViewState {
  const HandoverState({
    super.status,
    super.failure,
    this.recipient,
    this.candidates = const <Employee>[],
    this.isSearchingPeople = false,
    this.bundle = const <Asset>[],
    this.available = const <Asset>[],
    this.isSearchingAssets = false,
    this.assetPage = const PageRequest(),
    this.hasMoreAssets = false,
    this.isLoadingMoreAssets = false,
    this.handedOverOn,
    this.notes,
    this.isSigned = false,
    this.isSubmitting = false,
    this.receipt,
  });

  final Employee? recipient;
  final List<Employee> candidates;
  final bool isSearchingPeople;

  /// The assets being handed over, in the order they were added.
  final List<Asset> bundle;

  /// What the picker can offer — assignable assets, minus what is already in
  /// the bundle.
  final List<Asset> available;
  final bool isSearchingAssets;

  /// Where the picker has read up to.
  ///
  /// The sheet used to read one page and stop. A fleet of any size has more
  /// than fifty assignable assets, so anything past the first page was
  /// unreachable — and the sheet gave no sign of it, which is worse than a
  /// visible cap: the technician searched, did not find the laptop, and
  /// concluded it was already assigned.
  final PageRequest assetPage;
  final bool hasMoreAssets;
  final bool isLoadingMoreAssets;

  final DateTime? handedOverOn;
  final String? notes;

  /// Whether the pad currently holds a signature.
  ///
  /// A flag rather than the bytes: rendering the pad is the widget's job and
  /// it already owns the strokes, so pushing an image up the tree on every
  /// touch move would repaint the whole screen to redraw one line. The bytes
  /// are pulled once, at submit.
  final bool isSigned;

  final bool isSubmitting;

  /// Set once the bundle has been submitted — including when Odoo took only
  /// part of it.
  final HandoverReceipt? receipt;

  bool get hasRecipient => recipient != null;

  bool get isFull => bundle.length >= HandoverBundle.maxAssets;

  /// Every gate the confirm button waits on.
  ///
  /// The signature is one of them on purpose: a bundle without it is the
  /// per-asset assign flow, which the app still has for when the recipient is
  /// not there to sign.
  bool get canSubmit =>
      hasRecipient &&
      bundle.isNotEmpty &&
      isSigned &&
      handedOverOn != null &&
      !isSubmitting;

  /// What is still missing, so the screen can say so instead of leaving a
  /// disabled button with no explanation.
  HandoverBlocker? get blocker {
    if (!hasRecipient) return HandoverBlocker.recipient;
    if (bundle.isEmpty) return HandoverBlocker.assets;
    if (!isSigned) return HandoverBlocker.signature;
    return null;
  }

  HandoverState copyWith({
    ViewStatus? status,
    Employee? recipient,
    List<Employee>? candidates,
    bool? isSearchingPeople,
    List<Asset>? bundle,
    List<Asset>? available,
    bool? isSearchingAssets,
    PageRequest? assetPage,
    bool? hasMoreAssets,
    bool? isLoadingMoreAssets,
    DateTime? handedOverOn,
    String? notes,
    bool? isSigned,
    bool? isSubmitting,
    HandoverReceipt? receipt,
    Failure? failure,
    bool clearFailure = false,
    bool clearRecipient = false,
  }) => HandoverState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    recipient: clearRecipient ? null : (recipient ?? this.recipient),
    candidates: candidates ?? this.candidates,
    isSearchingPeople: isSearchingPeople ?? this.isSearchingPeople,
    bundle: bundle ?? this.bundle,
    available: available ?? this.available,
    isSearchingAssets: isSearchingAssets ?? this.isSearchingAssets,
    assetPage: assetPage ?? this.assetPage,
    hasMoreAssets: hasMoreAssets ?? this.hasMoreAssets,
    isLoadingMoreAssets: isLoadingMoreAssets ?? this.isLoadingMoreAssets,
    handedOverOn: handedOverOn ?? this.handedOverOn,
    notes: notes ?? this.notes,
    isSigned: isSigned ?? this.isSigned,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    receipt: receipt ?? this.receipt,
  );

  @override
  List<Object?> get props => <Object?>[
    ...super.props,
    recipient,
    candidates,
    isSearchingPeople,
    bundle,
    available,
    isSearchingAssets,
    assetPage,
    hasMoreAssets,
    isLoadingMoreAssets,
    handedOverOn,
    notes,
    isSigned,
    isSubmitting,
    receipt,
  ];
}

/// The next thing the user has to do.
enum HandoverBlocker { recipient, assets, signature }

/// The handover workflow's ViewModel.
class HandoverCubit extends Cubit<HandoverState> {
  HandoverCubit({
    required SearchEmployees searchEmployees,
    required GetAssetsPage getAssets,
    required SubmitHandover submitHandover,
    DateTime Function()? clock,
  }) : _searchEmployees = searchEmployees,
       _getAssets = getAssets,
       _submitHandover = submitHandover,
       _now = clock ?? DateTime.now,
       super(const HandoverState());

  final SearchEmployees _searchEmployees;
  final GetAssetsPage _getAssets;
  final SubmitHandover _submitHandover;
  final DateTime Function() _now;

  // Two of each: the recipient search and the asset search run against
  // different models and must not cancel one another.
  final Debouncer _peopleSearch = Debouncer();
  final Debouncer _assetSearch = Debouncer();
  final RequestTicket _peopleTicket = RequestTicket();
  final RequestTicket _assetTicket = RequestTicket();

  void start() {
    final now = _now();
    emit(
      HandoverState(
        status: ViewStatus.success,
        handedOverOn: DateTime(now.year, now.month, now.day),
      ),
    );
    searchPeople('');
    searchAssets('');
  }

  // ── Recipient ────────────────────────────────────────────────────────────

  void searchPeople(String term) {
    _peopleSearch.run(() async {
      final ticket = _peopleTicket.take();
      emit(state.copyWith(isSearchingPeople: true));

      final result = await _searchEmployees(term);
      if (_peopleTicket.isStale(ticket) || isClosed) return;

      result.fold(
        // A failed lookup leaves the previous candidates alone: an empty list
        // would read as "nobody by that name", a different fact.
        (_) => emit(state.copyWith(isSearchingPeople: false)),
        (people) =>
            emit(state.copyWith(isSearchingPeople: false, candidates: people)),
      );
    });
  }

  void chooseRecipient(Employee employee) =>
      emit(state.copyWith(recipient: employee));

  void clearRecipient() => emit(state.copyWith(clearRecipient: true));

  // ── The bundle ───────────────────────────────────────────────────────────

  /// The filter the picker offers from, kept in one place so the first page
  /// and every page after it ask the same question.
  ///
  /// Exactly the two states an asset can be handed over from. Odoo cannot
  /// filter on Reserved, so the repository widens the query and narrows the
  /// page — which is why this asks for both rather than listing everything
  /// and filtering here.
  AssetFilters _assetFilters(String term) => AssetFilters(
    query: term.trim().isEmpty ? null : term.trim(),
    statuses: const <AssetStatus>{AssetStatus.available, AssetStatus.reserved},
  );

  String _assetTerm = '';

  void searchAssets(String term) {
    _assetTerm = term;
    _assetSearch.run(() async {
      final ticket = _assetTicket.take();
      emit(state.copyWith(isSearchingAssets: true));

      const first = PageRequest();
      final result = await _getAssets(
        AssetQuery(filters: _assetFilters(term), page: first),
      );
      if (_assetTicket.isStale(ticket) || isClosed) return;

      result.fold(
        (_) => emit(state.copyWith(isSearchingAssets: false)),
        (page) => emit(
          state.copyWith(
            isSearchingAssets: false,
            available: page.items,
            assetPage: first,
            hasMoreAssets: page.hasMore,
          ),
        ),
      );
    });
  }

  /// Reads the next page of assignable assets into the picker.
  ///
  /// Guarded on three things, all of which happen: a request already in
  /// flight (the list fires this as it scrolls), a list that has reached the
  /// end, and a search that has moved on since — the ticket is the same one
  /// [searchAssets] holds, so a page for "mac" cannot land under "macbook".
  Future<void> loadMoreAssets() async {
    if (state.isLoadingMoreAssets || !state.hasMoreAssets) return;

    final ticket = _assetTicket.take();
    emit(state.copyWith(isLoadingMoreAssets: true));

    final next = state.assetPage.next();
    final result = await _getAssets(
      AssetQuery(filters: _assetFilters(_assetTerm), page: next),
    );
    if (_assetTicket.isStale(ticket) || isClosed) return;

    result.fold(
      // A failed page leaves what is already on screen alone: the technician
      // is mid-bundle, and replacing the list with an error would lose the
      // selection they have made so far.
      (_) => emit(state.copyWith(isLoadingMoreAssets: false)),
      (page) => emit(
        state.copyWith(
          isLoadingMoreAssets: false,
          available: <Asset>[...state.available, ...page.items],
          assetPage: next,
          hasMoreAssets: page.hasMore,
        ),
      ),
    );
  }

  void addToBundle(Asset asset) {
    if (state.isFull) return;
    // Scanning or tapping the same asset twice is what people do when they are
    // not sure it registered; it must not appear twice on the receipt.
    if (state.bundle.any((a) => a.id == asset.id)) return;

    emit(state.copyWith(bundle: <Asset>[...state.bundle, asset]));
  }

  void removeFromBundle(int assetId) => emit(
    state.copyWith(bundle: state.bundle.where((a) => a.id != assetId).toList()),
  );

  // ── The rest of the form ─────────────────────────────────────────────────

  void setDate(DateTime date) => emit(state.copyWith(handedOverOn: date));

  void setNotes(String notes) => emit(state.copyWith(notes: notes));

  void setSigned({required bool isSigned}) {
    if (state.isSigned == isSigned) return;
    emit(state.copyWith(isSigned: isSigned));
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  /// [signature] is pulled from the pad at the moment of submission rather
  /// than held in state — see [HandoverState.isSigned].
  Future<void> submit(Uint8List? signature) async {
    final recipient = state.recipient;
    final date = state.handedOverOn;

    if (recipient == null || date == null || signature == null) return;
    if (state.bundle.isEmpty || state.isSubmitting) return;

    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _submitHandover(
      HandoverBundle(
        recipient: recipient,
        assets: state.bundle,
        handedOverOn: date,
        signature: signature,
        notes: state.notes,
      ),
    );
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(isSubmitting: false, failure: failure),
        (receipt) => state.copyWith(isSubmitting: false, receipt: receipt),
      ),
    );
  }

  /// Drops the assets that landed and keeps the ones Odoo refused, so the
  /// retry hands over what is left and never the same asset twice.
  void retryFailed() {
    final receipt = state.receipt;
    if (receipt == null || receipt.failed.isEmpty) return;

    emit(
      HandoverState(
        status: ViewStatus.success,
        recipient: state.recipient,
        candidates: state.candidates,
        available: state.available,
        bundle: receipt.failed,
        handedOverOn: state.handedOverOn,
        notes: state.notes,
      ),
    );

    // The assets that *did* land are still sitting in the picker's list as
    // available. Offering one of them again would build a bundle Odoo has to
    // refuse for the opposite reason.
    searchAssets('');
  }

  void acknowledgeFailure() => emit(state.copyWith(clearFailure: true));

  @override
  Future<void> close() {
    _peopleSearch.dispose();
    _assetSearch.dispose();
    return super.close();
  }
}
