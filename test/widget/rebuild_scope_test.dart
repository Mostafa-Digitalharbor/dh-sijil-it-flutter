import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/responsive/responsive.dart';

/// What wakes a widget up, and what must not.
///
/// ## The problem
///
/// `MediaQuery.of(context)` subscribes the caller to *every* field of the
/// MediaQueryData. One of those is `viewInsets`, which changes on **every
/// frame of the keyboard animation** — twenty or so on the way up and twenty
/// on the way down.
///
/// Two dozen widgets in this app ask about the screen size, several of them
/// page roots. Reading it through `MediaQuery.of` meant a single tap on a text
/// field rebuilt most of the screen forty times, for an answer — "am I on a
/// phone" — that had not changed. On a low-end handset that is the difference
/// between a keyboard that slides and one that stutters.
///
/// The aspect-scoped accessors (`sizeOf`, `textScalerOf`, …) subscribe to one
/// field each. These tests hold that line: they count rebuilds while changing
/// a field the widget did not ask about.
void main() {
  /// Mounts [body] under a MediaQuery the test can mutate, counting how often
  /// [body]'s widget rebuilds.
  ///
  /// The probe is passed through `ValueListenableBuilder`'s `child` so the
  /// parent never rebuilds it. That is the whole point: with the probe built
  /// inside the closure it would rebuild on every change regardless of what
  /// it subscribed to, and the test would measure nothing.
  ({Widget widget, ValueNotifier<MediaQueryData> data, _Probe probe}) harness(
    void Function(BuildContext context) body,
  ) {
    final data = ValueNotifier<MediaQueryData>(
      const MediaQueryData(size: Size(390, 844)),
    );
    final probe = _Probe(body: body);

    return (
      probe: probe,
      data: data,
      widget: Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<MediaQueryData>(
          valueListenable: data,
          child: probe,
          builder: (context, value, child) =>
              MediaQuery(data: value, child: child!),
        ),
      ),
    );
  }

  group('context.isCompact', () {
    testWidgets('does not rebuild when the keyboard opens', (tester) async {
      // The regression this whole file exists for.
      _Probe.builds = 0;
      final h = harness((context) => context.isCompact);
      await tester.pumpWidget(h.widget);

      final before = _Probe.builds;
      h.data.value = h.data.value.copyWith(
        viewInsets: const EdgeInsets.only(bottom: 336),
      );
      await tester.pump();

      expect(
        _Probe.builds,
        before,
        reason: 'The keyboard woke a widget that only asked about width.',
      );
    });

    testWidgets('does not rebuild when the text scale changes', (tester) async {
      _Probe.builds = 0;
      final h = harness((context) => context.isCompact);
      await tester.pumpWidget(h.widget);

      final before = _Probe.builds;
      h.data.value = h.data.value.copyWith(
        textScaler: const TextScaler.linear(1.6),
      );
      await tester.pump();

      expect(_Probe.builds, before);
    });

    testWidgets('but does rebuild when the window is resized', (tester) async {
      // The one thing it is actually about. A subscription this narrow is
      // only correct if it still fires for its own field.
      _Probe.builds = 0;
      final h = harness((context) => context.isCompact);
      await tester.pumpWidget(h.widget);

      final before = _Probe.builds;
      h.data.value = h.data.value.copyWith(size: const Size(1280, 800));
      await tester.pump();

      expect(_Probe.builds, greaterThan(before));
    });
  });

  group('context.pagePadding', () {
    testWidgets('does not rebuild when the keyboard opens', (tester) async {
      _Probe.builds = 0;
      final h = harness((context) => context.pagePadding);
      await tester.pumpWidget(h.widget);

      final before = _Probe.builds;
      h.data.value = h.data.value.copyWith(
        viewInsets: const EdgeInsets.only(bottom: 336),
      );
      await tester.pump();

      expect(_Probe.builds, before);
    });

    testWidgets('and agrees with ResponsiveInfo about the gutter', (
      tester,
    ) async {
      // It reads the width directly rather than going through ResponsiveInfo,
      // to avoid the text-scale subscription. That is only safe while the two
      // resolve the breakpoints the same way.
      for (final width in <double>[320, 390, 700, 834, 1024, 1280]) {
        late EdgeInsetsGeometry shorthand;
        late double viaInfo;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  shorthand = context.pagePadding;
                  viaInfo = context.screen.gutter;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(
          shorthand.resolve(TextDirection.ltr).left,
          viaInfo,
          reason: 'The two disagree at ${width}dp.',
        );
      }
    });
  });

  group('context.screen', () {
    testWidgets('is woken by a text-size change, which it depends on', (
      tester,
    ) async {
      // `isLargeText` reflows dense rows to a column, so this subscription is
      // load-bearing and must not be narrowed away.
      _Probe.builds = 0;
      final h = harness((context) => context.screen.isLargeText);
      await tester.pumpWidget(h.widget);

      final before = _Probe.builds;
      h.data.value = h.data.value.copyWith(
        textScaler: const TextScaler.linear(1.6),
      );
      await tester.pump();

      expect(_Probe.builds, greaterThan(before));
    });

    testWidgets('but still not by the keyboard', (tester) async {
      // Nothing derived from ResponsiveInfo depends on viewInsets, so the
      // keyboard must not reach it either.
      _Probe.builds = 0;
      final h = harness((context) => context.screen.size);
      await tester.pumpWidget(h.widget);

      final before = _Probe.builds;
      h.data.value = h.data.value.copyWith(
        viewInsets: const EdgeInsets.only(bottom: 336),
      );
      await tester.pump();

      expect(
        _Probe.builds,
        before,
        reason:
            'ResponsiveInfo is reading MediaQuery.of again. Use the '
            'aspect-scoped accessors.',
      );
    });
  });

  group('the breakpoints', () {
    test('ScreenSize.forWidth is the only mapping', () {
      // One table, so a widget that reads the width directly and one that goes
      // through ResponsiveInfo can never disagree about where a phone ends.
      expect(ScreenSize.forWidth(0), ScreenSize.compact);
      expect(ScreenSize.forWidth(599.9), ScreenSize.compact);
      expect(ScreenSize.forWidth(600), ScreenSize.medium);
      expect(ScreenSize.forWidth(899.9), ScreenSize.medium);
      expect(ScreenSize.forWidth(900), ScreenSize.expanded);
      expect(ScreenSize.forWidth(4000), ScreenSize.expanded);
    });
  });
}

/// Counts how many times it is built, and reads whatever the test asks it to.
class _Probe extends StatelessWidget {
  const _Probe({required this.body});

  final void Function(BuildContext context) body;

  /// Static because the widget instance is const-shaped and the element is
  /// what survives across pumps.
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    body(context);
    return const SizedBox.shrink();
  }
}
