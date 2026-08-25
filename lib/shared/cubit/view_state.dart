import 'package:equatable/equatable.dart';

import '../../core/error/failures.dart';

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
