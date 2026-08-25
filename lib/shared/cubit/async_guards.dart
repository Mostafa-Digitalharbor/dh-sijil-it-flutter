import 'dart:async';

import '../../app/theme/app_dimens.dart';

/// Discards the answer to a question the user has since re-asked.
///
/// ## The bug this exists to prevent
///
/// Typing "mac" fires a query for `m`, then `ma`, then `mac`. Nothing promises
/// they come back in that order — a slow `ma` resolving after a fast `mac`
/// paints the results for "ma" under the word "mac", and the list is now
/// showing something the user did not ask for with no indication anything is
/// wrong. It is intermittent, it never reproduces on a fast connection, and it
/// is the exact failure a reviewer cannot see by reading a diff.
///
/// Five Cubits each had their own `int _requestId` and their own
/// `if (ticket != _requestId) return;`. Five copies of a race guard is five
/// chances to invert the comparison.
///
/// ```dart
/// final ticket = _search.take();
/// final result = await _searchEmployees(term);
/// if (_search.isStale(ticket) || isClosed) return;
/// ```
class RequestTicket {
  int _latest = 0;

  /// Claims the next ticket. The caller holds it across the await.
  int take() => ++_latest;

  /// Whether a newer request was started while [ticket] was in flight.
  bool isStale(int ticket) => ticket != _latest;

  /// Invalidates everything in flight without starting anything.
  ///
  /// For a screen resetting to its initial state: results already on their way
  /// belong to the state that was just thrown away.
  void cancelAll() => _latest++;
}

/// Delays work until the user stops typing.
///
/// Wrapped rather than repeated because the cancel matters in two places and
/// the second is easy to forget: once before rescheduling, and again in the
/// Cubit's `close`. A timer that survives its Cubit fires into a closed
/// emitter, which throws in debug and is swallowed in release — so the bug
/// only appears in a build nobody is watching.
class Debouncer {
  Debouncer({this.delay = AppDurations.searchDebounce});

  final Duration delay;
  Timer? _timer;

  /// Whether a call is currently pending.
  bool get isPending => _timer?.isActive ?? false;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Drops a pending call without running it.
  void cancel() => _timer?.cancel();

  /// Runs a pending call now, if there is one. For a form's submit button:
  /// the user pressed it before the debounce elapsed, and their last keystroke
  /// still has to count.
  void flush(void Function() action) {
    if (!isPending) return;
    cancel();
    action();
  }

  /// Always call from the Cubit's `close`.
  void dispose() => cancel();
}
