import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_colors.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/entities/warranty.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_chip.dart';
import 'package:sijil_it/shared/widgets/key_value.dart';
import 'package:sijil_it/shared/widgets/mono_text.dart';
import 'package:sijil_it/shared/widgets/status_chip.dart';

import '../../fake_odoo/test_app_harness.dart';

/// The widgets that *show* something: chips, identifiers, labelled facts.
///
/// Most of what can go wrong here is invisible in English. An identifier that
/// reads back to front, a status told only by colour, a blank where Odoo
/// returned `false` — each renders perfectly on the developer's machine.
void main() {
  late AppL10n en;
  late AppL10n ar;

  setUpAll(() async {
    en = await loadL10n();
    ar = await loadL10n('ar');
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
    ThemeMode themeMode = ThemeMode.light,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        themeMode: themeMode,
        textScale: textScale,
        size: TestSizes.phone,
        child: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump();
  }

  group('AppChip', () {
    testWidgets('never tells the state by colour alone', (tester) async {
      // The reason every chip carries a word: greyscale printouts, and the
      // one-in-twelve men who cannot separate the amber from the green.
      await pump(
        tester,
        const AppChip(label: 'Under maintenance', leadingDot: true),
      );

      expect(find.text('Under maintenance'), findsOneWidget);
    });

    testWidgets('a tap target is announced as a button, a label is not', (
      tester,
    ) async {
      await pump(tester, AppChip(label: 'Laptop', onTap: () {}));
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.button == true,
        ),
        findsWidgets,
      );

      await pump(tester, const AppChip(label: 'Laptop'));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Laptop' &&
              w.properties.button == true,
        ),
        findsNothing,
        reason: 'announcing a static label as pressable sends people hunting',
      );
    });

    testWidgets('the suffix reaches the screen reader, not the screen', (
      tester,
    ) async {
      await pump(
        tester,
        const AppChip(
          label: 'Damaged',
          semanticSuffix: 'kept on this device',
          leadingDot: true,
        ),
      );

      expect(find.text('Damaged'), findsOneWidget);
      expect(find.text('Damaged — kept on this device'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Damaged — kept on this device',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the dismiss affordance appears only when it does something', (
      tester,
    ) async {
      var removed = 0;
      await pump(tester, AppChip(label: 'Assigned', onRemove: () => removed++));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(removed, 1);

      await pump(tester, const AppChip(label: 'Assigned'));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('label ink is darkened on light and left raw on dark', (
      tester,
    ) async {
      // The status hues are tuned for fills. At a 12% tint several of them
      // miss 4.5:1 as text, so light mode uses a darkened partner.
      const tone = AppColors.statusMaintenance;

      await pump(tester, const AppChip(label: 'Maintenance', tone: tone));
      final light = AppChip.inkFor(
        tester.element(find.text('Maintenance')),
        tone,
      );

      await pump(
        tester,
        const AppChip(label: 'Maintenance', tone: tone),
        themeMode: ThemeMode.dark,
      );
      // `MaterialApp` cross-fades themes, so a single pump lands on an
      // interpolated `ThemeData` that still reports the old brightness.
      await tester.pumpAndSettle();
      final dark = AppChip.inkFor(
        tester.element(find.text('Maintenance')),
        tone,
      );

      expect(dark, tone);
      expect(light, isNot(tone));
    });

    test('every tone the app puts a label on has a readable partner', () {
      // `inkFor` falls back to the tone itself for anything it does not know,
      // so a status added without an ink entry does not fail to compile or
      // throw — it just renders amber-on-amber-tint and passes review.
      for (final status in AssetStatus.values) {
        final tone = StatusChip.colorFor(status);
        expect(
          AppColors.inkFor(tone),
          isNot(tone),
          reason: '$status has no darkened ink for light mode',
        );
      }
    });
  });

  group('AppChipBar', () {
    testWidgets('an empty bar takes no space at all', (tester) async {
      await pump(tester, const AppChipBar(children: []));
      expect(tester.getSize(find.byType(AppChipBar)), Size.zero);
    });

    testWidgets('the height follows the text scaler', (tester) async {
      // Pinned at a constant this clipped by exactly the few pixels the label
      // grew — which is how a three-pixel overflow stripe reaches the assets
      // screen at an accessibility text size.
      const chips = AppChipBar(
        children: [
          AppChip(label: 'All'),
          AppChip(label: 'Assigned'),
        ],
      );

      await pump(tester, chips);
      final normal = tester.getSize(find.byType(AppChipBar)).height;

      await pump(tester, chips, textScale: AppTextScale.max);
      final scaled = tester.getSize(find.byType(AppChipBar)).height;

      expect(scaled, greaterThan(normal));
    });

    testWidgets('many long chips scroll instead of overflowing', (
      tester,
    ) async {
      await pump(
        tester,
        AppChipBar(
          children: <Widget>[
            for (final label in <String>[
              'All departments',
              'Administration',
              'Development',
              'Finance',
              'Operations',
              'Sales',
            ])
              AppChip(label: label),
          ],
        ),
        locale: const Locale('ar'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  group('MonoText', () {
    testWidgets('an identifier keeps its reading order inside Arabic', (
      tester,
    ) async {
      // `SJL-0042 · 2026-08-24` in an RTL paragraph: the `·` between two Latin
      // runs is a neutral, so bidi resolves it to the paragraph direction and
      // renders the halves swapped.
      await pump(
        tester,
        const MonoText('SJL-0042 · 2026-08-24'),
        locale: const Locale('ar'),
      );

      final context = tester.element(find.text('SJL-0042 · 2026-08-24'));
      expect(Directionality.of(context), TextDirection.ltr);
    });
  });

  group('IdentifierLine', () {
    testWidgets('the tag and the note are separate runs', (tester) async {
      // One string would put Arabic prose and a Latin tag in the same
      // paragraph, and the separator would pick a side.
      await pump(
        tester,
        const IdentifierLine(tag: 'DH-LAP-0012', note: 'يوسف طارق'),
        locale: const Locale('ar'),
      );

      expect(find.text('DH-LAP-0012'), findsOneWidget);
      expect(find.text('يوسف طارق'), findsOneWidget);

      expect(
        Directionality.of(tester.element(find.text('DH-LAP-0012'))),
        TextDirection.ltr,
        reason: 'the tag is what is printed on the sticker',
      );
      expect(
        Directionality.of(tester.element(find.text('يوسف طارق'))),
        TextDirection.rtl,
        reason: 'a name is prose and follows the language',
      );
    });

    testWidgets('a tag with no note renders no dangling separator', (
      tester,
    ) async {
      await pump(tester, const IdentifierLine(tag: 'DH-LAP-0012'));

      expect(find.text('DH-LAP-0012'), findsOneWidget);
      expect(find.text(' · '), findsNothing);
    });

    testWidgets('an empty note is treated as no note', (tester) async {
      await pump(tester, const IdentifierLine(tag: 'DH-LAP-0012', note: ''));
      expect(find.text(' · '), findsNothing);
    });
  });

  group('KeyValue', () {
    testWidgets('an unset Odoo field says so instead of leaving a gap', (
      tester,
    ) async {
      // Odoo returns `false` for unset fields, and a blank row reads as a
      // rendering bug rather than as missing data.
      await pump(tester, const KeyValue(label: 'Serial number', value: null));

      expect(find.text(en.labelUnknown), findsOneWidget);
    });

    testWidgets('whitespace counts as unset', (tester) async {
      await pump(tester, const KeyValue(label: 'Serial number', value: '   '));
      expect(find.text(en.labelUnknown), findsOneWidget);
    });

    testWidgets('a placeholder is dimmer than a real value', (tester) async {
      await pump(tester, const KeyValue(label: 'Serial', value: null));
      final placeholder = tester
          .widget<Text>(find.text(en.labelUnknown))
          .style
          ?.color;

      await pump(
        tester,
        const KeyValue(label: 'Serial', value: 'C02XK1YZQ6L4'),
      );
      final real = tester.widget<Text>(find.text('C02XK1YZQ6L4')).style?.color;

      expect(placeholder, isNot(real));
    });

    testWidgets('a monospace value is Latin-isolated and starts at the edge', (
      tester,
    ) async {
      await pump(
        tester,
        const KeyValue(
          label: 'الرقم التسلسلي',
          value: 'C02XK1YZQ6L4',
          isMonospace: true,
        ),
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.text('C02XK1YZQ6L4'))),
        TextDirection.ltr,
      );
      expectNoOverflow(tester);
    });

    testWidgets('the placeholder is translated', (tester) async {
      await pump(
        tester,
        const KeyValue(label: 'الرقم', value: null),
        locale: const Locale('ar'),
      );

      expect(find.text(ar.labelUnknown), findsOneWidget);
      expect(find.text(en.labelUnknown), findsNothing);
    });
  });

  group('StatusChip', () {
    test('every status has its own words and its own colour', () {
      // A switch that returns the same label for two statuses compiles, ships,
      // and makes two different situations look identical on a list row.
      final labels = <String>{};
      final tones = <Color>{};

      for (final status in AssetStatus.values) {
        final label = StatusChip.labelFor(en, status);
        expect(label.trim(), isNotEmpty, reason: '$status has no label');
        labels.add(label);
        tones.add(StatusChip.colorFor(status));
      }

      expect(labels, hasLength(AssetStatus.values.length));
      expect(tones, hasLength(AssetStatus.values.length));
    });

    test('and its own words in Arabic too', () {
      final labels = <String>{
        for (final status in AssetStatus.values)
          StatusChip.labelFor(ar, status),
      };

      expect(labels, hasLength(AssetStatus.values.length));
      for (final status in AssetStatus.values) {
        expect(
          StatusChip.labelFor(ar, status),
          isNot(StatusChip.labelFor(en, status)),
          reason: '$status is untranslated',
        );
      }
    });

    testWidgets('a locally-held status is marked as such', (tester) async {
      // Three statuses live only in this app's log. Someone filtering by
      // status in the Odoo web client will not find them, so the row says so.
      await pump(
        tester,
        const StatusChip(status: AssetStatus.damaged, isLocal: true),
      );

      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.contains(en.statusKeptInLog) ?? false),
        ),
        findsOneWidget,
      );

      await pump(tester, const StatusChip(status: AssetStatus.damaged));
      expect(find.byIcon(Icons.history_rounded), findsNothing);
    });
  });

  group('WarrantyChip', () {
    Warranty on(DateTime end) =>
        Warranty.evaluate(endDate: end, now: DateTime(2026, 8, 29));

    testWidgets('no warranty date renders nothing at all', (tester) async {
      // An "unknown" pill on every row of a list is noise, not information.
      await pump(tester, const WarrantyChip(warranty: Warranty.unknown));
      expect(tester.getSize(find.byType(WarrantyChip)), Size.zero);
    });

    testWidgets('an expiry counts down, an expiry past counts up', (
      tester,
    ) async {
      await pump(tester, WarrantyChip(warranty: on(DateTime(2026, 9, 7))));
      expect(find.text(en.warrantyExpiresIn(9)), findsOneWidget);

      await pump(tester, WarrantyChip(warranty: on(DateTime(2026, 7, 15))));
      expect(
        find.text(en.warrantyExpiredAgo(45)),
        findsOneWidget,
        reason: 'the days are negative in the model and absolute in the words',
      );
    });

    testWidgets('a healthy warranty says so without a number', (tester) async {
      await pump(tester, WarrantyChip(warranty: on(DateTime(2028, 1, 1))));
      expect(find.text(en.warrantyValid), findsOneWidget);
    });

    test('each state has its own colour', () {
      final tones = <Color>{
        for (final state in WarrantyState.values) WarrantyChip.colorFor(state),
      };
      expect(tones, hasLength(WarrantyState.values.length));
    });
  });
}
