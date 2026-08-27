import 'package:flutter/material.dart';

import '../../core/error/failures.dart';
import '../cubit/view_state.dart';
import 'skeletons.dart';
import 'state_views.dart';

/// The load / fail / render decision every detail screen makes, made once.
///
/// Nine screens each wrote the same four-armed `switch` over their Cubit
/// state. Four arms repeated nine times is thirty-six chances to get one of
/// them subtly wrong — and seven of them did, all in the same place:
///
/// ```dart
/// _ when asset == null => const SizedBox.shrink(),
/// ```
///
/// That arm is reached when the request *succeeded* and Odoo returned nothing:
/// the record was deleted, or it sits outside the caller's record rules. The
/// user gets a blank screen — no title, no cause, no way forward, and nothing
/// to report to whoever administers their Odoo. It is the one state in the app
/// where something went wrong and the app said nothing at all, which is exactly
/// what the error contract exists to prevent (spec §22).
///
/// So the empty arm is gone. Data that never arrived is a
/// [FailureKind.recordNotFound], and that kind already has copy in both
/// languages saying what happened, why, and what to do about it.
///
/// ## Why the data is passed in rather than read off the state
///
/// The states are not uniform: `SimpleViewState<T>` carries `data`, while
/// `AssignAssetState` carries `asset` and `ReturnAssetState` carries its own.
/// Forcing them all behind one interface would be a refactor of eleven Cubits
/// to save one argument at nine call sites. The caller resolves its own field
/// and hands the result over.
class AsyncDataView<T extends Object> extends StatelessWidget {
  const AsyncDataView({
    required this.status,
    required this.data,
    required this.builder,
    this.failure,
    this.onRetry,
    this.loadingView,
    this.emptyView,
    super.key,
  });

  final ViewStatus status;

  /// Null until the record arrives — or permanently, if it never will.
  final T? data;

  final Widget Function(BuildContext context, T data) builder;

  final Failure? failure;

  /// Re-runs the load. Wired to the button on the failure view.
  final VoidCallback? onRetry;

  /// Overrides the first-load treatment.
  ///
  /// The default is a list of row-shaped placeholders, which suits the screens
  /// that *are* lists. Every other screen should pass the skeleton shaped like
  /// itself — `SkeletonDetail`, `SkeletonForm`, `SkeletonDashboard` — because
  /// a placeholder of the wrong shape reserves the wrong space, and the
  /// content arriving then shoves the layout it was supposed to be holding
  /// still.
  final Widget? loadingView;

  /// Shown instead of the "record is gone" failure when a screen has a
  /// legitimate nothing-here state of its own — a history with no entries yet.
  final Widget? emptyView;

  @override
  Widget build(BuildContext context) {
    final data = this.data;

    // Data wins over status: a refresh that fails behind content already on
    // screen must not replace it with an error page. The failure surfaces as a
    // snackbar instead, which is the caller's job and which every caller does.
    if (data != null) return builder(context, data);

    if (status == ViewStatus.initial || status.isInitialLoad) {
      return loadingView ?? const SkeletonRowList();
    }

    if (status == ViewStatus.failure) {
      return FailureView(
        failure: failure ?? const Failure.unknown(),
        onRetry: onRetry,
      );
    }

    // Loaded, and nothing came back.
    return emptyView ??
        FailureView(
          failure: const Failure(kind: FailureKind.recordNotFound),
          onRetry: onRetry,
        );
  }
}
