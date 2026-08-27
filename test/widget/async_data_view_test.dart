import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/shared/cubit/view_state.dart';
import 'package:sijil_it/shared/widgets/async_data_view.dart';
import 'package:sijil_it/shared/widgets/skeletons.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../fake_odoo/test_app_harness.dart';

/// The contract that replaced seven copies of the same `switch`.
///
/// The arm that mattered was this one, and every detail screen had it:
///
/// ```dart
/// _ when asset == null => const SizedBox.shrink(),
/// ```
///
/// It is reached when the request *succeeded* and Odoo returned nothing — the
/// record was deleted, or it sits outside the caller's record rules. The user
/// got a blank screen: no title, no cause, no way forward, and nothing to
/// quote to whoever administers their Odoo.
void main() {
  Widget host(Widget child) => TestApp(child: Scaffold(body: child));

  Widget subject({
    required ViewStatus status,
    String? data,
    Failure? failure,
    Widget? emptyView,
    VoidCallback? onRetry,
  }) => host(
    AsyncDataView<String>(
      status: status,
      data: data,
      failure: failure,
      emptyView: emptyView,
      onRetry: onRetry,
      builder: (_, value) => Text(value),
    ),
  );

  testWidgets('renders the data when there is data', (tester) async {
    await tester.pumpWidget(
      subject(status: ViewStatus.success, data: 'MacBook Pro'),
    );
    await tester.pumpAndSettle();

    expect(find.text('MacBook Pro'), findsOneWidget);
  });

  testWidgets('shows a skeleton on the first load', (tester) async {
    await tester.pumpWidget(subject(status: ViewStatus.loading));
    await tester.pump();

    expect(find.byType(SkeletonRowList), findsOneWidget);
  });

  testWidgets('an initial state loads rather than reporting a loss', (
    tester,
  ) async {
    // `initial` is the moment between the screen mounting and `load()` being
    // called. Treating it as "nothing came back" would flash "this record is
    // gone" on every detail screen the app opens.
    await tester.pumpWidget(subject(status: ViewStatus.initial));
    await tester.pump();

    expect(find.byType(SkeletonRowList), findsOneWidget);
    expect(find.byType(FailureView), findsNothing);
  });

  testWidgets('a failure is presented, with its retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      subject(
        status: ViewStatus.failure,
        failure: const Failure(kind: FailureKind.timeout),
        onRetry: () => retried = true,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await loadL10n();
    expect(find.text(l10n.errorTimeoutTitle), findsOneWidget);
    // The fix, not just the cause: the third part is what the user acts on.
    expect(find.text(l10n.errorTimeoutFix), findsOneWidget);

    await tester.tap(find.text(l10n.actionRetry));
    expect(retried, isTrue);
  });

  testWidgets('a failure with no Failure attached still says something', (
    tester,
  ) async {
    // Defensive: the old code read `state.failure!`, which turned a Cubit
    // emitting `failure` without populating the field into a null-check crash
    // on top of whatever had already gone wrong.
    await tester.pumpWidget(subject(status: ViewStatus.failure));
    await tester.pumpAndSettle();

    final l10n = await loadL10n();
    expect(find.text(l10n.errorUnknownTitle), findsOneWidget);
  });

  group('loaded, and nothing came back', () {
    testWidgets('says the record is gone instead of rendering nothing', (
      tester,
    ) async {
      await tester.pumpWidget(subject(status: ViewStatus.success));
      await tester.pumpAndSettle();

      final l10n = await loadL10n();
      expect(find.text(l10n.errorRecordNotFoundTitle), findsOneWidget);
      expect(find.text(l10n.errorRecordNotFoundBody), findsOneWidget);
      expect(find.text(l10n.errorRecordNotFoundFix), findsOneWidget);
    });

    testWidgets('says it in Arabic too', (tester) async {
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('ar', 'EG'),
          child: Scaffold(
            body: AsyncDataView<String>(
              status: ViewStatus.success,
              data: null,
              builder: (_, value) => Text(value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ar = await loadL10n('ar');
      expect(find.text(ar.errorRecordNotFoundTitle), findsOneWidget);
    });

    testWidgets('a refresh that returns nothing is treated the same', (
      tester,
    ) async {
      await tester.pumpWidget(subject(status: ViewStatus.refreshing));
      await tester.pumpAndSettle();

      final l10n = await loadL10n();
      expect(find.text(l10n.errorRecordNotFoundTitle), findsOneWidget);
    });

    testWidgets('unless the screen has a real empty state of its own', (
      tester,
    ) async {
      // An asset with no history has not lost anything — it simply has none
      // yet, and saying "this record is gone" would be a lie.
      await tester.pumpWidget(
        subject(
          status: ViewStatus.success,
          emptyView: const Text('nothing recorded yet'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('nothing recorded yet'), findsOneWidget);
      expect(find.byType(FailureView), findsNothing);
    });
  });

  testWidgets('content already on screen survives a failed refresh', (
    tester,
  ) async {
    // The rule that makes pull-to-refresh safe: a refresh that fails behind
    // content must not replace it with an error page. The snackbar reports it.
    await tester.pumpWidget(
      subject(
        status: ViewStatus.failure,
        data: 'MacBook Pro',
        failure: const Failure(kind: FailureKind.noInternet),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MacBook Pro'), findsOneWidget);
    expect(find.byType(FailureView), findsNothing);
  });
}
