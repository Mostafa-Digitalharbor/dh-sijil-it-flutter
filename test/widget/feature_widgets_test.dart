import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/entities/warranty.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_detail_sections.dart';
import 'package:sijil_it/features/assignment/presentation/widgets/condition_picker.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/status_chip.dart';

import '../fake_odoo/test_app_harness.dart';

/// Widgets that belong to one feature but carry decisions of their own.
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

  Asset assetWith({required AssetStatus status, bool isStatusLocal = false}) =>
      Asset(
        id: 1,
        name: 'ThinkPad L15 Gen 3',
        status: status,
        isStatusLocal: isStatusLocal,
        warranty: Warranty.unknown,
      );

  group('ConditionPicker', () {
    testWidgets('every condition is offered, and choosing one reports it', (
      tester,
    ) async {
      ReturnCondition? chosen;
      await pump(
        tester,
        ConditionPicker(
          selected: ReturnCondition.good,
          onChanged: (value) => chosen = value,
        ),
      );

      for (final condition in ReturnCondition.values) {
        expect(
          find.text(ConditionLabels.name(en, condition)),
          findsOneWidget,
          reason: '$condition is not offered',
        );
      }

      await tester.tap(
        find.text(ConditionLabels.name(en, ReturnCondition.damaged)),
      );
      await tester.pump();
      expect(chosen, ReturnCondition.damaged);
    });

    testWidgets('each option says what confirming will actually do', (
      tester,
    ) async {
      // The consequence differs per condition — one of them files a
      // maintenance request — and nobody should have to guess which.
      await pump(
        tester,
        ConditionPicker(selected: ReturnCondition.good, onChanged: (_) {}),
      );

      expect(
        find.text(ConditionLabels.effect(en, ReturnCondition.needsMaintenance)),
        findsOneWidget,
      );
    });

    test('every condition has its own words, colour and glyph', () {
      final names = <String>{};
      final tones = <Color>{};
      final icons = <IconData>{};

      for (final condition in ReturnCondition.values) {
        names.add(ConditionLabels.name(en, condition));
        tones.add(ConditionLabels.tone(condition));
        icons.add(ConditionLabels.icon(condition));
        expect(ConditionLabels.effect(en, condition).trim(), isNotEmpty);
      }

      expect(names, hasLength(ReturnCondition.values.length));
      expect(tones, hasLength(ReturnCondition.values.length));
      expect(icons, hasLength(ReturnCondition.values.length));
    });

    test('and its own words in Arabic', () {
      for (final condition in ReturnCondition.values) {
        expect(
          ConditionLabels.name(ar, condition),
          isNot(ConditionLabels.name(en, condition)),
          reason: '$condition is untranslated',
        );
      }
    });

    testWidgets('it collapses to one column rather than clipping', (
      tester,
    ) async {
      // Two columns cannot fit a label plus its consequence line once text is
      // scaled up, and the consequence is the half that matters.
      await pump(
        tester,
        ConditionPicker(selected: ReturnCondition.good, onChanged: (_) {}),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      expect(
        find.text(ConditionLabels.name(ar, ReturnCondition.needsMaintenance)),
        findsOneWidget,
      );
    });

    testWidgets('the selected card is distinguishable without colour', (
      tester,
    ) async {
      // Colour alone fails for the same readers the status chips are worded
      // for, so the selection carries a mark.
      await pump(
        tester,
        ConditionPicker(selected: ReturnCondition.damaged, onChanged: (_) {}),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // And exactly one: two marks means the selection is ambiguous.
      await pump(
        tester,
        ConditionPicker(selected: ReturnCondition.good, onChanged: (_) {}),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('AssetLocalStateNotice', () {
    testWidgets('it explains a status Odoo does not know about', (
      tester,
    ) async {
      // Three statuses live only in this app's log. Someone filtering in the
      // Odoo web client will not find them, and this is where that is said.
      await pump(
        tester,
        AssetLocalStateNotice(
          asset: assetWith(status: AssetStatus.damaged, isStatusLocal: true),
        ),
      );

      expect(find.text(en.statusKeptInLog), findsOneWidget);
      expect(find.text(en.assetLocalStateNote), findsOneWidget);
    });

    testWidgets('and says nothing at all for a status Odoo does know', (
      tester,
    ) async {
      await pump(
        tester,
        AssetLocalStateNotice(asset: assetWith(status: AssetStatus.assigned)),
      );

      expect(
        tester.getSize(find.byType(AssetLocalStateNotice)),
        Size.zero,
        reason: 'a notice about nothing is noise on every other asset',
      );
    });

    testWidgets('it is toned to the status it is explaining', (tester) async {
      await pump(
        tester,
        AssetLocalStateNotice(
          asset: assetWith(status: AssetStatus.lost, isStatusLocal: true),
        ),
      );

      // Same hue the chip above it uses, so the two read as one statement.
      final tone = StatusChip.colorFor(AssetStatus.lost);
      final card = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AssetLocalStateNotice),
              matching: find.byType(Material),
            )
            .first,
      );

      final fill = card.color!;
      expect(fill.r, closeTo(tone.r, 0.01));
      expect(fill.g, closeTo(tone.g, 0.01));
      expect(fill.b, closeTo(tone.b, 0.01));
      expect(
        fill.a,
        lessThan(1),
        reason: 'a tint, not the raw hue — this is a notice, not a warning',
      );
    });

    testWidgets('it fits a small phone in Arabic at the text ceiling', (
      tester,
    ) async {
      await pump(
        tester,
        AssetLocalStateNotice(
          asset: assetWith(status: AssetStatus.damaged, isStatusLocal: true),
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });
}
