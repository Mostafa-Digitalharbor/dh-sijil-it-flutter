import 'package:equatable/equatable.dart';

import '../../core/error/failures.dart';
import '../../core/pagination/paginated_result.dart';

/// The four phases every screen in the app can be in.
///
/// Having one shared vocabulary means the loading, empty and error treatments
/// (spec §26) are implemented once in `shared/widgets` rather than re-invented
/// per screen.
enum ViewStatus {
  initial,
  loading,

  /// A refresh triggered while data is already on screen — the UI keeps the
  /// old content and shows a subtle indicator instead of a full skeleton.
  refreshing,
  success,
  failure;

  bool get isBusy =>
      this == ViewStatus.loading || this == ViewStatus.refreshing;
  bool get isInitialLoad => this == ViewStatus.loading;
}

/// Base class for every Cubit state in the app.
///
/// In our MVVM mapping the Cubit is the ViewModel and this is the immutable
/// view model *output*: a snapshot the widget renders without any further
/// logic. Subclasses add feature-specific fields and implement [props].
abstract class ViewState extends Equatable {
  const ViewState({this.status = ViewStatus.initial, this.failure});

  final ViewStatus status;

  /// Populated only when [status] is [ViewStatus.failure]. Already sanitized.
  final Failure? failure;

  bool get isLoading => status.isInitialLoad;
  bool get isRefreshing => status == ViewStatus.refreshing;
  bool get hasFailed => status == ViewStatus.failure;
  bool get isSuccess => status == ViewStatus.success;

  @override
  List<Object?> get props => [status, failure];
}

/// Base state for a screen that pages through a list.
///
/// ## Why this is a type and not a convention
///
/// Assets, employees and maintenance requests are the same screen with
/// different rows, and all three states already carried the same two fields —
/// a [PaginatedResult] and an `isLoadingMore` flag — plus the same two getters
/// derived from them. Nothing said so, so each screen re-wired the eight
/// arguments [PaginatedListView] needs by hand, and each was free to derive
/// `hasMore` from something slightly different.
///
/// Declaring it lets `PaginatedListView.fromState` take the state itself, so
/// the wiring is written once and a new list screen cannot get it subtly wrong
/// — it either satisfies this contract or it does not compile.
abstract class PaginatedViewState<T> extends ViewState {
  const PaginatedViewState({
    super.status,
    super.failure,
    this.page = const PaginatedResult.empty(),
    this.isLoadingMore = false,
  });

  /// The rows read so far, merged across every page.
  final PaginatedResult<T> page;

  /// A next-page request is in flight.
  ///
  /// Distinct from [ViewStatus.refreshing], which replaces the list rather
  /// than extending it: one shows a footer spinner under rows the user is
  /// still reading, the other shows an indicator at the top.
  final bool isLoadingMore;

  /// The rows themselves. Subclasses add a domain-named alias — `assets`,
  /// `employees` — because that is what reads well at a call site.
  List<T> get items => page.items;

  /// True while the server still has rows beyond the ones read so far.
  bool get hasMore => page.hasMore;

  @override
  List<Object?> get props => [...super.props, page, isLoadingMore];
}

/// Ready-made state for screens that just load one value.
class SimpleViewState<T> extends ViewState {
  const SimpleViewState({super.status, super.failure, this.data});

  final T? data;

  SimpleViewState<T> loading() =>
      SimpleViewState<T>(status: ViewStatus.loading, data: data);

  SimpleViewState<T> refreshing() =>
      SimpleViewState<T>(status: ViewStatus.refreshing, data: data);

  SimpleViewState<T> success(T value) =>
      SimpleViewState<T>(status: ViewStatus.success, data: value);

  SimpleViewState<T> failed(Failure failure) => SimpleViewState<T>(
    status: ViewStatus.failure,
    failure: failure,
    data: data,
  );

  @override
  List<Object?> get props => [...super.props, data];
}
