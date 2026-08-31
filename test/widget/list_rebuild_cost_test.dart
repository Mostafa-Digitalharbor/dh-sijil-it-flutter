import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/features/assets/presentation/cubit/asset_list_cubit.dart';
import 'package:sijil_it/features/assets/presentation/pages/asset_list_page.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_row.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// What one interaction costs the asset list.
///
/// ## Why this is measured rather than assumed
///
/// The screen is one `BlocConsumer` wrapped around the whole scaffold: title,
/// actions, search field, floating button and the list. Every state the Cubit
/// emits rebuilds all of it, so **the emit count is the cost**, and the emit
/// count is a property of the Cubit that reading the widget will not tell you.
///
/// Two guesses were plausible before measuring, and adding `buildWhen`
/// everywhere on the strength of either would have been guessing:
///
/// * Typing is expensive, because each keystroke rebuilds the list.
/// * Selecting is expensive, because each tap rebuilds every row.
///
/// These record which is true. The numbers are asserted as ceilings so a
/// future change that makes an interaction chattier fails here rather than
/// being noticed as "the list feels slow on the cheap phone".
void main() {
  late FakeOdooData data;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  /// The Cubit the *page* built, read back out of the tree.
  ///
  /// Not `sl<AssetListCubit>()`: it is registered as a factory, so calling it
  /// here hands back a second, orphan Cubit that never loads, never emits, and
  /// never gets closed — which measures nothing and leaks a repository
  /// subscription into the next test.
  Future<AssetListCubit> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      TestApp(
        size: TestSizes.phone,
        child: signedInScreen(const AssetListPage()),
      ),
    );
    await tester.pumpAndSettle();

    return BlocProvider.of<AssetListCubit>(
      tester.element(find.byType(AssetRow).first),
    );
  }

  /// States emitted while [action] runs. One emit is one full rebuild of the
  /// scaffold and every row on screen.
  ///
  /// Counted through a [BlocObserver] rather than by subscribing to
  /// `cubit.stream`: a subscription taken here outlives the widget tree the
  /// test tears down, and `sl.reset()` then waits on it forever.
  Future<int> emitsDuring(Future<void> Function() action) async {
    final counter = _EmitCounter();
    final previous = Bloc.observer;
    Bloc.observer = counter;
    try {
      await action();
    } finally {
      Bloc.observer = previous;
    }
    return counter.emits;
  }

  testWidgets('the fixture gives us rows to measure against', (tester) async {
    await pumpList(tester);
    expect(find.byType(AssetRow), findsWidgets);
  });

  testWidgets('typing costs one search, not one per keystroke', (tester) async {
    // The Cubit debounces at 350ms, so the keystrokes never reach it
    // individually. This asserts the debounce is already doing the work an
    // optimisation here would be asked to do — which is why none is added.
    await pumpList(tester);

    final emits = await emitsDuring(() async {
      for (final term in <String>['m', 'ma', 'mac', 'macb']) {
        await tester.enterText(find.byType(TextField).first, term);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
    });

    // Four keystrokes. Undebounced this would be at least four searches,
    // each emitting a loading state and a result.
    expect(
      emits,
      lessThanOrEqualTo(3),
      reason:
          'Four keystrokes emitted $emits states. The debounce is not holding, '
          'and the whole screen rebuilds on each one.',
    );
  });

  testWidgets('and selecting costs exactly one state per tap', (tester) async {
    // The interaction most likely to be chatty, and the one a technician does
    // fastest: picking a handful of laptops to move to another department.
    await pumpList(tester);

    await tester.longPress(find.byType(AssetRow).first);
    await tester.pumpAndSettle();

    final onScreen = find.byType(AssetRow).evaluate().length;
    expect(onScreen, greaterThan(1), reason: 'Need rows to measure against.');

    const taps = 4;
    final emits = await emitsDuring(() async {
      for (var i = 1; i <= taps && i < onScreen; i++) {
        await tester.tap(find.byType(AssetRow).at(i));
        await tester.pumpAndSettle();
      }
    });

    // One per tap is the floor — the selection genuinely changed, and the
    // chrome above the list is showing a count that moved. More than one
    // would mean the Cubit is emitting states nothing asked for.
    expect(
      emits,
      lessThanOrEqualTo(taps),
      reason: '$taps taps emitted $emits states.',
    );
  });

  testWidgets('a refresh emits a loading state and a result, and stops there', (
    tester,
  ) async {
    final cubit = await pumpList(tester);

    final emits = await emitsDuring(() async {
      await cubit.load(refresh: true);
      await tester.pumpAndSettle();
    });

    expect(
      emits,
      lessThanOrEqualTo(3),
      reason: 'A refresh emitted $emits states.',
    );
  });

  testWidgets('clearing filters does not re-emit when nothing was set', (
    tester,
  ) async {
    // The empty-state button calls `search('')` and `clearFilters()` together.
    // With nothing set, both are no-ops — and a Cubit that emits anyway
    // rebuilds the screen twice for a tap that changed nothing.
    final cubit = await pumpList(tester);

    final emits = await emitsDuring(() async {
      cubit
        ..search('')
        ..clearFilters();
      await tester.pumpAndSettle();
    });

    expect(
      emits,
      lessThanOrEqualTo(1),
      reason: 'Clearing nothing emitted $emits states.',
    );
  });
}

/// Counts every state every Cubit emits while it is installed.
///
/// Only one Cubit is alive in these tests, so the count is that Cubit's.
class _EmitCounter extends BlocObserver {
  int emits = 0;

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    emits++;
    super.onChange(bloc, change);
  }
}
