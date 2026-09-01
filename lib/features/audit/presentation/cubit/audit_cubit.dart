import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/odoo/odoo_name_ref.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/usecases/asset_usecases.dart';
import '../../../employees/domain/usecases/employee_usecases.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/usecases/audit_usecases.dart';

/// Which of the three screens the one audit route is showing.
///
/// One route, not three: an audit is a single continuous act, and a walk that
/// can be interrupted by the router losing the session is a walk nobody
/// trusts. Keeping the phase in the state means the count survives everything
/// except leaving on purpose.
enum AuditPhase { setup, counting, report }

class AuditState extends ViewState {
  const AuditState({
    super.status,
    super.failure,
    this.phase = AuditPhase.setup,
    this.categories = const <OdooNameRef>[],
    this.departments = const <OdooNameRef>[],
    this.scope = AuditScope.all,
    this.categoryId,
    this.departmentId,
    this.session,
    this.isResolving = false,
    this.lastCode,
    this.lastScan,
    this.isCommitting = false,
    this.committedNotes,
    this.unknownCode,
  });

  final AuditPhase phase;

  /// Scope choices, read once when the screen opens.
  final List<OdooNameRef> categories;
  final List<OdooNameRef> departments;

  final AuditScope scope;
  final int? categoryId;
  final int? departmentId;

  final AuditSession? session;

  /// A lookup is in flight. The camera stays live; detections are dropped so
  /// one sticker in frame cannot start a dozen lookups.
  final bool isResolving;

  /// Payload of the most recent detection, used to suppress the repeats a
  /// camera produces while a code sits in frame.
  final String? lastCode;

  /// The asset the last scan landed on, for the confirmation flash.
  final AuditEntry? lastScan;

  final bool isCommitting;

  /// How many chatter notes the commit wrote. Null until it has run.
  final int? committedNotes;

  /// A scanned code that matched no asset — worth surfacing during a count:
  /// it usually means a sticker from another system, or one asset wearing
  /// another's label.
  final String? unknownCode;

  /// Whether the scope choice is complete enough to start.
  bool get canStart => switch (scope) {
    AuditScope.all => true,
    AuditScope.category => categoryId != null,
    AuditScope.department => departmentId != null,
  };

  String? get scopeLabel => switch (scope) {
    AuditScope.all => null,
    AuditScope.category => _nameOf(categories, categoryId),
    AuditScope.department => _nameOf(departments, departmentId),
  };

  static String? _nameOf(List<OdooNameRef> options, int? id) {
    if (id == null) return null;
    for (final option in options) {
      if (option.id == id) return option.name;
    }
    return null;
  }

  AuditState copyWith({
    ViewStatus? status,
    Failure? failure,
    AuditPhase? phase,
    List<OdooNameRef>? categories,
    List<OdooNameRef>? departments,
    AuditScope? scope,
    int? categoryId,
    int? departmentId,
    AuditSession? session,
    bool? isResolving,
    String? lastCode,
    AuditEntry? lastScan,
    bool? isCommitting,
    int? committedNotes,
    String? unknownCode,
    bool clearFailure = false,
    bool clearScopeIds = false,
    bool clearFlash = false,
  }) => AuditState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    phase: phase ?? this.phase,
    categories: categories ?? this.categories,
    departments: departments ?? this.departments,
    scope: scope ?? this.scope,
    categoryId: clearScopeIds ? null : (categoryId ?? this.categoryId),
    departmentId: clearScopeIds ? null : (departmentId ?? this.departmentId),
    session: session ?? this.session,
    isResolving: isResolving ?? this.isResolving,
    lastCode: lastCode ?? this.lastCode,
    lastScan: clearFlash ? null : (lastScan ?? this.lastScan),
    isCommitting: isCommitting ?? this.isCommitting,
    committedNotes: committedNotes ?? this.committedNotes,
    unknownCode: clearFlash ? null : (unknownCode ?? this.unknownCode),
  );

  @override
  List<Object?> get props => <Object?>[
    ...super.props,
    phase,
    categories,
    departments,
    scope,
    categoryId,
    departmentId,
    session,
    isResolving,
    lastCode,
    lastScan,
    isCommitting,
    committedNotes,
    unknownCode,
  ];
}

/// The audit's ViewModel.
///
/// Holds the whole walk: the scope choice, the fixed expected set, every scan
/// and the final commit. The camera itself stays in the widget — the same
/// split the scanner uses — so the entire count can be driven from a test by
/// calling [onDetected] with strings.
class AuditCubit extends Cubit<AuditState> {
  AuditCubit({
    required StartAudit startAudit,
    required CommitAudit commitAudit,
    required ResolveScannedCode resolveCode,
    required GetAssetListOptions listOptions,
    required GetDepartments departments,
  }) : _startAudit = startAudit,
       _commitAudit = commitAudit,
       _resolveCode = resolveCode,
       _listOptions = listOptions,
       _departments = departments,
       super(const AuditState());

  final StartAudit _startAudit;
  final CommitAudit _commitAudit;
  final ResolveScannedCode _resolveCode;
  final GetAssetListOptions _listOptions;
  final GetDepartments _departments;

  /// Reads the scope choices. Failing to read them is not fatal — an audit of
  /// everything needs neither list — so this never puts the screen in a
  /// failure state.
  Future<void> loadScopes() async {
    emit(state.copyWith(status: ViewStatus.loading, clearFailure: true));

    final options = await _listOptions();
    final departments = await _departments();
    if (isClosed) return;

    emit(
      state.copyWith(
        status: ViewStatus.success,
        categories: options.fold(
          (_) => const <OdooNameRef>[],
          (value) => value.categories,
        ),
        departments: departments.getOrElse(() => const <OdooNameRef>[]),
      ),
    );
  }

  void setScope(AuditScope scope) =>
      emit(state.copyWith(scope: scope, clearScopeIds: true));

  void setCategory(int? id) =>
      emit(state.copyWith(categoryId: id, clearScopeIds: id == null));

  void setDepartment(int? id) =>
      emit(state.copyWith(departmentId: id, clearScopeIds: id == null));

  /// Reads the expected set and moves to the walk.
  Future<void> start() async {
    if (!state.canStart) return;
    emit(state.copyWith(status: ViewStatus.loading, clearFailure: true));

    final result = await _startAudit(
      AuditScopeParams(
        scope: state.scope,
        categoryId: state.categoryId,
        departmentId: state.departmentId,
        label: state.scopeLabel,
      ),
    );
    if (isClosed) return;

    emit(
      result.fold(
        (failure) =>
            state.copyWith(status: ViewStatus.failure, failure: failure),
        (assets) => state.copyWith(
          status: ViewStatus.success,
          phase: AuditPhase.counting,
          session: AuditSession(
            startedAt: DateTime.now(),
            scope: state.scope,
            scopeLabel: state.scopeLabel,
            expected: <int, Asset>{for (final asset in assets) asset.id: asset},
          ),
        ),
      ),
    );
  }

  /// Handles one detection.
  ///
  /// Re-scanning a sticker already counted is deliberately silent rather than
  /// an error: it is what people do when they are unsure whether the beep
  /// happened, and the session keys results by asset id so it cannot double
  /// count.
  Future<void> onDetected(String code) async {
    final session = state.session;
    if (session == null || session.isFinished) return;

    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == state.lastCode) return;

    // The fast path, and the one almost every scan in a walk takes: the
    // expected set was read once at the start, so an asset in scope is already
    // on the device and needs no round trip at all. Recording it synchronously
    // is what lets somebody walk a shelf at the speed they can point a camera,
    // and it keeps working in a stock room with no signal.
    final known = session.matchLocally(trimmed);
    if (known != null) {
      final updated = session.record(known, DateTime.now());
      emit(
        state.copyWith(
          status: ViewStatus.success,
          session: updated,
          lastCode: trimmed,
          lastScan: updated.results[known.id],
          clearFailure: true,
        ),
      );
      return;
    }

    // Not in scope. That is a finding rather than a count, and the only case
    // worth a lookup: it is either an asset from another department or a
    // sticker from another system, and the audit has to name which.
    //
    // Queued rather than dropped while another lookup is in flight. Dropping
    // was the old behaviour and it lost scans silently — the technician saw no
    // beep, assumed a bad read, and scanned again.
    if (state.isResolving) {
      // Deduplicated: a camera reports the same sticker many times a second,
      // and a queue that took every repeat would turn one out-of-scope asset
      // into thirty round trips.
      if (!_pendingCodes.contains(trimmed)) _pendingCodes.add(trimmed);
      return;
    }

    await _resolveRemote(trimmed);
    await _drainPending();
  }

  /// Codes detected while a lookup was in flight, oldest first.
  final List<String> _pendingCodes = <String>[];

  /// Looks one out-of-scope code up, then drains anything that arrived while
  /// it was running.
  Future<void> _resolveRemote(String trimmed) async {
    final session = state.session;
    if (session == null || session.isFinished) return;

    emit(
      state.copyWith(
        isResolving: true,
        lastCode: trimmed,
        clearFlash: true,
        clearFailure: true,
      ),
    );

    final result = await _resolveCode(trimmed);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(
          isResolving: false,
          status: ViewStatus.failure,
          failure: failure,
        ),
        (asset) {
          if (asset == null) {
            return state.copyWith(isResolving: false, unknownCode: trimmed);
          }
          final updated = session.record(asset, DateTime.now());
          return state.copyWith(
            isResolving: false,
            status: ViewStatus.success,
            session: updated,
            lastScan: updated.results[asset.id],
          );
        },
      ),
    );
  }

  /// Works through the codes that arrived while a lookup was running.
  ///
  /// One at a time and in order, because each is a round trip and firing them
  /// together would be the same load the old code avoided by dropping them.
  /// The difference is that none is lost.
  ///
  /// Flat rather than recursive: [_resolveRemote] deliberately does not call
  /// this, so a walk that queues forty codes runs forty sequential lookups
  /// rather than forty nested ones.
  Future<void> _drainPending() async {
    while (_pendingCodes.isNotEmpty && !isClosed) {
      final next = _pendingCodes.removeAt(0);
      final session = state.session;
      if (session == null || session.isFinished) {
        _pendingCodes.clear();
        return;
      }

      await _resolveRemote(next);
    }
  }

  /// Lets the next detection through again once the code has left the frame.
  void clearLastCode() => emit(state.copyWith(lastCode: '', clearFlash: true));

  /// Ends the walk. Everything unscanned becomes missing at this instant —
  /// which is why it cannot be known before.
  void finish() {
    final session = state.session;
    if (session == null || session.isFinished) return;
    emit(
      state.copyWith(
        phase: AuditPhase.report,
        session: session.copyWith(finishedAt: DateTime.now()),
      ),
    );
  }

  /// Reopens the count — the report is a review step, not a commit.
  void resume() {
    final session = state.session;
    if (session == null) return;
    emit(
      state.copyWith(
        phase: AuditPhase.counting,
        session: AuditSession(
          startedAt: session.startedAt,
          scope: session.scope,
          scopeLabel: session.scopeLabel,
          expected: session.expected,
          results: session.results,
        ),
      ),
    );
  }

  /// Writes the findings to Odoo.
  Future<void> commit() async {
    final session = state.session;
    if (session == null || !session.isFinished || state.isCommitting) return;

    emit(state.copyWith(isCommitting: true, clearFailure: true));
    final result = await _commitAudit(session);
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => state.copyWith(
          isCommitting: false,
          status: ViewStatus.failure,
          failure: failure,
        ),
        (written) => state.copyWith(
          isCommitting: false,
          status: ViewStatus.success,
          committedNotes: written,
        ),
      ),
    );
  }
}
