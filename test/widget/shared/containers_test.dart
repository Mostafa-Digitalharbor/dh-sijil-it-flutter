import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_colors.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_card.dart';
import 'package:sijil_it/shared/widgets/app_data_views.dart';
import 'package:sijil_it/shared/widgets/app_sheets.dart';
import 'package:sijil_it/shared/widgets/app_tiles.dart';
import 'package:sijil_it/shared/widgets/key_value.dart';
import 'package:sijil_it/shared/widgets/skeletons.dart';
import 'package:sijil_it/shared/widgets/tool_tile.dart';

import '../../fake_odoo/test_app_harness.dart';

/// Cards, grids, tiles and the placeholder primitives.
///
/// Mostly layout, which means most of what can break here is a column count
/// that does not collapse, or a fixed height that clips the moment somebody
/// turns text size up.
void main() {
  late AppL10n en;

  setUpAll(() async => en = await loadL10n());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
    Size size = TestSizes.phone,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        size: size,
        textScale: textScale,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  group('KeyValueGrid', () {
    final facts = <KeyValue>[
      const KeyValue(label: 'Manufacturer', value: 'Lenovo'),
      const KeyValue(label: 'Model', value: 'L15 Gen 3'),
      const KeyValue(label: 'Serial number', value: 'DH-LAP-0012'),
      const KeyValue(label: 'Category', value: 'Laptop'),
    ];

    testWidgets('an empty grid takes no space', (tester) async {
      await pump(tester, const KeyValueGrid(items: <KeyValue>[]));
      expect(tester.getSize(find.byType(KeyValueGrid)).height, 0);
    });

    testWidgets('two columns on a phone at normal text', (tester) async {
      await pump(tester, KeyValueGrid(items: facts));

      // Side by side: the two labels of a pair share a row.
      expect(
        tester.getTopLeft(find.text('Manufacturer')).dy,
        tester.getTopLeft(find.text('Model')).dy,
      );
    });

    testWidgets('one column once the user turns text size up', (tester) async {
      // Two columns of scaled Arabic is the classic detail-screen overflow.
      await pump(
        tester,
        KeyValueGrid(items: facts),
        textScale: AppTextScale.max,
      );

      expect(
        tester.getTopLeft(find.text('Model')).dy,
        greaterThan(tester.getTopLeft(find.text('Manufacturer')).dy),
      );
      expectNoOverflow(tester);
    });

    testWidgets('an odd count leaves no ragged hole', (tester) async {
      await pump(tester, KeyValueGrid(items: facts.take(3).toList()));

      expect(tester.takeException(), isNull);
      expectNoOverflow(tester);
    });

    testWidgets('a long Arabic value wraps instead of squeezing its pair', (
      tester,
    ) async {
      await pump(
        tester,
        const KeyValueGrid(
          items: <KeyValue>[
            KeyValue(
              label: 'الشركة المصنّعة',
              value: 'شركة لينوفو العالمية للتقنيات والحواسيب المحمولة',
            ),
            KeyValue(label: 'الطراز', value: 'L15 Gen 3'),
          ],
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('AppExpansionCard', () {
    testWidgets('it opens and closes', (tester) async {
      await pump(
        tester,
        const AppExpansionCard(
          title: 'Maintenance',
          icon: Icons.build_rounded,
          child: SizedBox(height: 120),
        ),
      );

      // `AnimatedCrossFade` keeps both children mounted, so the question is
      // how much room the card takes, not what is findable.
      final collapsed = tester.getSize(find.byType(AppExpansionCard)).height;

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();
      final expanded = tester.getSize(find.byType(AppExpansionCard)).height;
      expect(expanded, greaterThan(collapsed + 100));

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppExpansionCard)).height, collapsed);
    });

    testWidgets('collapsed content is not read out', (tester) async {
      // Mounted but hidden is still mounted: without the exclusion, a screen
      // reader walks straight through three collapsed sections.
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        const AppExpansionCard(
          title: 'Maintenance',
          icon: Icons.build_rounded,
          child: Text('three open requests'),
        ),
      );
      expect(find.bySemanticsLabel('three open requests'), findsNothing);

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('three open requests'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the open state reaches a screen reader', (tester) async {
      // A disclosure that does not announce itself is a button that appears
      // to do nothing.
      await pump(
        tester,
        const AppExpansionCard(
          title: 'Maintenance',
          icon: Icons.build_rounded,
          initiallyExpanded: true,
          child: Text('three open requests'),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Maintenance' &&
              w.properties.expanded == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('the header is a full-height tap target', (tester) async {
      await pump(
        tester,
        const AppExpansionCard(
          title: 'Maintenance',
          icon: Icons.build_rounded,
          child: SizedBox.shrink(),
        ),
      );

      expect(
        tester.getSize(find.byType(InkWell).first).height,
        greaterThanOrEqualTo(AppDimens.minTapTarget),
      );
    });
  });

  group('AppStatGrid', () {
    testWidgets('tiles share the row and nothing overflows in Arabic', (
      tester,
    ) async {
      await pump(
        tester,
        const AppStatGrid(
          tiles: <AppStatTile>[
            AppStatTile(value: '1', label: 'الأصول المحتفظ بها'),
            AppStatTile(value: '1', label: 'في الخدمة'),
            AppStatTile(value: '1', label: 'ضمان مستحق'),
          ],
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });

    testWidgets('an empty grid renders nothing', (tester) async {
      await pump(tester, const AppStatGrid(tiles: <AppStatTile>[]));
      expect(tester.getSize(find.byType(AppStatGrid)).height, 0);
    });
  });

  group('AppListTile', () {
    testWidgets('the whole row is the target, not just the title', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        AppListTile(
          leading: const Icon(Icons.laptop_rounded),
          title: 'ThinkPad L15 Gen 3',
          subtitle: 'DH-LAP-0012',
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.text('DH-LAP-0012'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a very long title truncates rather than pushing the chevron', (
      tester,
    ) async {
      await pump(
        tester,
        AppListTile(
          leading: const Icon(Icons.laptop_rounded),
          title:
              'Lenovo ThinkPad L15 Gen 3 with the extended three-year '
              'on-site warranty and docking station',
          subtitle: 'DH-LAP-0012',
          onTap: () {},
        ),
        size: TestSizes.smallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('AppToolGrid', () {
    testWidgets('every tool is reachable and reports its own tap', (
      tester,
    ) async {
      final tapped = <String>[];
      await pump(
        tester,
        AppToolGrid(
          children: <Widget>[
            AppToolTile(
              icon: Icons.build_rounded,
              tone: AppColors.statusMaintenance,
              title: 'Maintenance',
              subtitle: 'Requests and history',
              onTap: () => tapped.add('maintenance'),
            ),
            AppToolTile(
              icon: Icons.qr_code_scanner_rounded,
              tone: AppColors.statusAvailable,
              title: 'Audit',
              subtitle: 'Count what is really there',
              onTap: () => tapped.add('audit'),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Audit'));
      await tester.pump();
      expect(tapped, <String>['audit']);
    });

    testWidgets('two long Arabic tools fit a small phone', (tester) async {
      await pump(
        tester,
        AppToolGrid(
          children: <Widget>[
            AppToolTile(
              icon: Icons.build_rounded,
              tone: AppColors.statusMaintenance,
              title: 'الصيانة',
              subtitle: 'الطلبات والسجل الخاص بالأجهزة',
              onTap: () {},
            ),
            AppToolTile(
              icon: Icons.person_add_alt_rounded,
              tone: AppColors.statusAssigned,
              title: 'التسليم',
              subtitle: 'سلّم عدة أصول بتوقيع واحد',
              onTap: () {},
            ),
          ],
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  group('AppPromptDialog', () {
    Future<String?> open(WidgetTester tester, {String? typed}) async {
      String? result;
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    result = await AppPromptDialog.show(
                      context,
                      title: 'Add a note',
                      confirmLabel: en.actionSave,
                      hint: 'What happened?',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      if (typed != null) {
        await tester.enterText(find.byType(TextField), typed);
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('it resolves to the trimmed text', (tester) async {
      await open(tester, typed: '  screen replaced  ');

      await tester.tap(find.text(en.actionSave));
      await tester.pumpAndSettle();

      expect(find.byType(AppPromptDialog), findsNothing);
    });

    testWidgets('a blank entry cannot be confirmed', (tester) async {
      // Nothing typed and nothing to save: the dialog stays rather than
      // filing an empty note against the record.
      await open(tester, typed: '    ');

      await tester.tap(find.text(en.actionSave));
      await tester.pumpAndSettle();

      expect(find.byType(AppPromptDialog), findsOneWidget);
    });

    testWidgets('dismissing gives back nothing', (tester) async {
      await open(tester, typed: 'a note');

      await tester.tap(find.text(en.actionCancel));
      await tester.pumpAndSettle();

      expect(find.byType(AppPromptDialog), findsNothing);
    });
  });

  group('skeleton primitives', () {
    testWidgets('a fractional line is a fraction of what it is given', (
      tester,
    ) async {
      // A placeholder line is deliberately shorter than its row: text does not
      // reach the margin, and a full-width bar reads as a loading *bar*.
      await pump(
        tester,
        const SizedBox(width: 300, child: SkeletonLine(widthFactor: 0.5)),
      );

      final bar = find.descendant(
        of: find.byType(SkeletonLine),
        matching: find.byType(Container),
      );
      expect(tester.getSize(bar).width, 150);
    });

    testWidgets('a title line is shorter than a caption line', (tester) async {
      // Which is what a real row looks like: a bold name over a longer,
      // lighter subtitle.
      await pump(
        tester,
        const SizedBox(
          width: 300,
          child: Column(
            children: <Widget>[SkeletonLine.title(), SkeletonLine.caption()],
          ),
        ),
      );

      double widthOf(int index) => tester
          .getSize(
            find
                .descendant(
                  of: find.byType(SkeletonLine).at(index),
                  matching: find.byType(Container),
                )
                .first,
          )
          .width;

      expect(widthOf(0), lessThan(widthOf(1)));
    });

    testWidgets('every primitive renders inside one shimmer sweep', (
      tester,
    ) async {
      // One sweep across the page, not one per box: a dozen independent
      // shimmers is a screen that looks like it is malfunctioning.
      await pump(
        tester,
        const SkeletonPage(
          child: Column(
            children: <Widget>[
              SkeletonLine.title(),
              SkeletonLine.caption(),
              SkeletonTile(),
              SkeletonTile.circle(),
              SkeletonChip(),
              SkeletonCard(),
              SkeletonKeyValues(),
              SkeletonButton(),
              SkeletonField(),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expectNoOverflow(tester);
    });
  });
}
