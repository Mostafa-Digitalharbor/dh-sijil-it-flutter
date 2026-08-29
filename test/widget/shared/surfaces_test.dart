import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_colors.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/app/theme/app_palette.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_avatar.dart';
import 'package:sijil_it/shared/widgets/app_card.dart';
import 'package:sijil_it/shared/widgets/app_chip.dart';
import 'package:sijil_it/shared/widgets/app_data_views.dart';
import 'package:sijil_it/shared/widgets/app_tiles.dart';
import 'package:sijil_it/shared/widgets/glass_card.dart';
import 'package:sijil_it/shared/widgets/greeting_header.dart';
import 'package:sijil_it/shared/widgets/key_value.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../../fake_odoo/test_app_harness.dart';

/// The surfaces everything else is drawn on, and the small tiles that live on
/// them.
///
/// Every panel in the product is one of four widgets — [AppCard], [GlassCard],
/// [AppHeroCard], [SectionCard] — and that is the whole point of them: radius,
/// border and padding stay identical across nine features because nothing else
/// is allowed to draw a rounded surface. What is worth testing is therefore
/// not that they paint, but the decisions inside them: what becomes tappable,
/// what a screen reader is told, and what happens when the content is bigger
/// than the box.
void main() {
  late AppL10n en;

  setUpAll(() async => en = await loadL10n());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
    ThemeMode themeMode = ThemeMode.light,
    Size size = TestSizes.phone,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        themeMode: themeMode,
        size: size,
        textScale: textScale,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  group('AppCard', () {
    testWidgets('a card with nothing to do is not a button', (tester) async {
      // An InkWell on an inert panel gives a ripple that promises something
      // will happen, and then nothing does.
      await pump(tester, const AppCard(child: Text('Ownership')));

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('and a card with somewhere to go is', (tester) async {
      var taps = 0;
      await pump(
        tester,
        AppCard(onTap: () => taps++, child: const Text('Ownership')),
      );

      await tester.tap(find.text('Ownership'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a screen reader is told a card is a button only when it is', (
      tester,
    ) async {
      bool declaredAsButton(WidgetTester tester) => tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((s) => s.properties.label == 'Ownership')
          .properties
          .button!;

      await pump(
        tester,
        const AppCard(semanticLabel: 'Ownership', child: Text('Ahmed')),
      );
      expect(declaredAsButton(tester), isFalse);

      await pump(
        tester,
        AppCard(
          semanticLabel: 'Ownership',
          onTap: () {},
          child: const Text('Ahmed'),
        ),
      );
      expect(declaredAsButton(tester), isTrue);
    });

    testWidgets('selection is a heavier border, not just a colour', (
      tester,
    ) async {
      await pump(tester, const AppCard(selected: true, child: Text('Ahmed')));

      final shape =
          tester.widget<Material>(find.byType(Material).last).shape!
              as RoundedRectangleBorder;
      expect(shape.side.width, AppDimens.selectedBorder);
      expect(shape.side.width, greaterThan(AppDimens.hairline));
    });

    testWidgets('the flush variant has no padding for rows that pad '
        'themselves', (tester) async {
      await pump(
        tester,
        const AppCard.flush(child: SizedBox(height: 40, width: 40)),
      );

      expect(tester.getSize(find.byType(AppCard)).height, 40);
    });

    testWidgets('the row variant is tighter than the panel variant', (
      tester,
    ) async {
      await pump(tester, const AppCard(child: SizedBox(height: 40, width: 40)));
      final panel = tester.getSize(find.byType(AppCard)).width;

      await pump(
        tester,
        const AppCard.row(child: SizedBox(height: 40, width: 40)),
      );

      expect(tester.getSize(find.byType(AppCard)).width, lessThan(panel));
    });
  });

  group('AppHeroCard', () {
    testWidgets('it writes in white on the brand navy', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => AppHeroCard(
            child: Text(
              '24',
              style: TextStyle(color: AppHeroCard.primaryText(context)),
            ),
          ),
        ),
      );

      final box =
          tester.widget<Container>(find.byType(Container).first).decoration!
              as BoxDecoration;
      expect(box.color, AppColors.navy);
      expect(tester.widget<Text>(find.text('24')).style?.color, Colors.white);
    });

    testWidgets('and on the raised card colour in the dark theme', (
      tester,
    ) async {
      // Navy on an already-navy page would read as nothing at all.
      await pump(
        tester,
        Builder(
          builder: (context) => AppHeroCard(
            child: Text(
              '24',
              style: TextStyle(color: AppHeroCard.primaryText(context)),
            ),
          ),
        ),
        themeMode: ThemeMode.dark,
      );

      final box =
          tester.widget<Container>(find.byType(Container).first).decoration!
              as BoxDecoration;
      expect(box.color, AppColors.cardDark);
      expect(
        tester.widget<Text>(find.text('24')).style?.color,
        isNot(Colors.white),
      );
    });

    testWidgets('its quiet text is quieter than its loud text, in both '
        'themes', (tester) async {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        await pump(
          tester,
          Builder(
            builder: (context) => AppHeroCard(
              child: Column(
                children: <Widget>[
                  Text(
                    'total',
                    style: TextStyle(color: AppHeroCard.subduedText(context)),
                  ),
                  Text(
                    '24',
                    style: TextStyle(color: AppHeroCard.primaryText(context)),
                  ),
                ],
              ),
            ),
          ),
          themeMode: mode,
        );

        expect(
          tester.widget<Text>(find.text('total')).style?.color,
          isNot(tester.widget<Text>(find.text('24')).style?.color),
          reason: 'the two hero text roles are the same colour in $mode',
        );
      }
    });
  });

  group('SectionCard', () {
    testWidgets('the heading is set off from the body', (tester) async {
      await pump(
        tester,
        const SectionCard(title: 'Recent activity', child: Text('body')),
      );

      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('body')).dy,
        greaterThan(tester.getTopLeft(find.text('RECENT ACTIVITY')).dy),
      );
    });

    testWidgets('an Arabic heading is left alone, because it has no case', (
      tester,
    ) async {
      // `toUpperCase` is a no-op on Arabic script; asserting it says the
      // heading is not mangled by a rule written for Latin.
      await pump(
        tester,
        const SectionCard(title: 'النشاط الأخير', child: Text('body')),
        locale: const Locale('ar'),
      );

      expect(find.text('النشاط الأخير'), findsOneWidget);
    });

    testWidgets('a trailing action sits on the heading row', (tester) async {
      await pump(
        tester,
        const SectionCard(
          title: 'Assets',
          trailing: Text('See all'),
          child: Text('body'),
        ),
      );

      expect(
        tester.getCenter(find.text('See all')).dy,
        closeTo(tester.getCenter(find.text('ASSETS')).dy, 2),
      );
      expect(
        tester.getCenter(find.text('See all')).dx,
        greaterThan(tester.getCenter(find.text('ASSETS')).dx),
      );
    });

    testWidgets('a long heading clips rather than shoving the action off', (
      tester,
    ) async {
      await pump(
        tester,
        const SectionCard(
          title: 'إجمالي الأصول المسجلة في النظام لهذا الشهر والشهر الماضي',
          trailing: Text('عرض الكل'),
          child: Text('body'),
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      expect(find.text('عرض الكل'), findsOneWidget);
    });
  });

  group('GlassCard', () {
    testWidgets('it is a lit surface, not a flat one', (tester) async {
      // A flat panel on a dark ground is a 4% luminance step, which reads as
      // a smudge rather than as a card.
      await pump(
        tester,
        const GlassCard(child: Text('donut')),
        themeMode: ThemeMode.dark,
      );

      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(GlassCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final box = decorated.decoration as BoxDecoration;
      final gradient = box.gradient! as LinearGradient;
      expect(gradient.colors.first, isNot(gradient.colors.last));
    });

    testWidgets('an untappable card carries no ink', (tester) async {
      await pump(tester, const GlassCard(child: Text('donut')));
      expect(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('and a tappable one reports the tap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        GlassCard(onTap: () => taps++, child: const Text('donut')),
      );

      await tester.tap(find.text('donut'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a status tone replaces the border, not the fill', (
      tester,
    ) async {
      await pump(
        tester,
        const GlassCard(borderColor: AppColors.danger, child: Text('overdue')),
      );

      final box =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(GlassCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(box.border!.top.color, AppColors.danger);
      expect(box.gradient, isNotNull);
    });
  });

  group('AmbientGlow', () {
    testWidgets('it is atmosphere, so it is not announced', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const AmbientGlow());

      expect(
        find.descendant(
          of: find.byType(AmbientGlow),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('and taps go straight through it', (tester) async {
      // It is drawn over the top of the page; if it ate the pointer the first
      // card on every dashboard would be dead.
      var taps = 0;
      await pump(
        tester,
        Stack(
          children: <Widget>[
            SizedBox(
              height: 320,
              child: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('under'),
                ),
              ),
            ),
            const AmbientGlow(),
          ],
        ),
      );

      await tester.tap(find.text('under'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('it stays faint enough for text to survive it', (tester) async {
      await pump(tester, const AmbientGlow());

      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(AmbientGlow),
          matching: find.byType(DecoratedBox),
        ),
      )) {
        final gradient =
            (box.decoration as BoxDecoration).gradient! as RadialGradient;
        expect(
          gradient.colors.first.a,
          lessThan(0.25),
          reason: 'a wash this strong takes text below its contrast ratio',
        );
        expect(gradient.colors.last.a, 0);
      }
    });
  });

  group('AppChipWrap', () {
    testWidgets('chips run onto a second line rather than off the card', (
      tester,
    ) async {
      await pump(
        tester,
        const AppChipWrap(
          children: <Widget>[
            AppChip(label: 'Laptop'),
            AppChip(label: 'Apple Egypt'),
            AppChip(label: 'Warranty valid'),
            AppChip(label: 'Assigned to Ahmed Mohamed'),
          ],
        ),
        size: TestSizes.smallPhone,
      );

      expectNoOverflow(tester);
      expect(
        tester.getTopLeft(find.text('Assigned to Ahmed Mohamed')).dy,
        greaterThan(tester.getTopLeft(find.text('Laptop')).dy),
      );
    });
  });

  group('AppLeadingTile', () {
    testWidgets('the compact variant is smaller than the standard one', (
      tester,
    ) async {
      await pump(tester, const AppLeadingTile(icon: Icons.laptop_rounded));
      final standard = tester.getSize(find.byType(AppLeadingTile)).width;

      await pump(
        tester,
        const AppLeadingTile.small(icon: Icons.laptop_rounded),
      );

      expect(
        tester.getSize(find.byType(AppLeadingTile)).width,
        lessThan(standard),
      );
    });

    testWidgets('the glyph is sized from the tile, not pinned', (tester) async {
      await pump(
        tester,
        const AppLeadingTile(icon: Icons.laptop_rounded, size: 80),
      );

      expect(
        tester.widget<Icon>(find.byIcon(Icons.laptop_rounded)).size,
        80 * 0.48,
      );
    });

    testWidgets('a toned tile tints itself; an untoned one stays neutral', (
      tester,
    ) async {
      await pump(
        tester,
        const AppLeadingTile(
          icon: Icons.build_rounded,
          tone: AppColors.statusMaintenance,
        ),
      );
      final toned =
          tester.widget<Container>(find.byType(Container).last).decoration!
              as BoxDecoration;

      await pump(tester, const AppLeadingTile(icon: Icons.build_rounded));
      final plain =
          tester.widget<Container>(find.byType(Container).last).decoration!
              as BoxDecoration;

      expect(toned.color, isNot(plain.color));
      expect(
        toned.color!.a,
        lessThan(1),
        reason: 'a tint behind an icon, not the raw status hue',
      );
    });
  });

  group('UserAvatar', () {
    test('initials come from the spaces, so they work in either script', () {
      expect(UserAvatar.initialsOf('Mostafa Bader'), 'MB');
      expect(UserAvatar.initialsOf('مصطفى بدر'), 'مب');
      expect(UserAvatar.initialsOf('Ahmed'), 'A');
      expect(UserAvatar.initialsOf('Ahmed Mohamed Ali'), 'AM');
    });

    test('and a name that is not one does not throw', () {
      expect(UserAvatar.initialsOf(''), '?');
      expect(UserAvatar.initialsOf('   '), '?');
      expect(UserAvatar.initialsOf('  Sara   Fouad  '), 'SF');
    });

    testWidgets('initials show when there is no photo', (tester) async {
      await pump(tester, const UserAvatar(name: 'Mostafa Bader'));
      expect(find.text('MB'), findsOneWidget);
    });

    testWidgets('and are not read out beside the name they are drawn from', (
      tester,
    ) async {
      // The dashboard header is the avatar and then the person's name. Left
      // in the tree, TalkBack opens the screen by spelling "M B".
      final handle = tester.ensureSemantics();
      await pump(tester, const GreetingHeader(name: 'Mostafa Bader'));

      expect(find.bySemanticsLabel('MB'), findsNothing);
      expect(find.bySemanticsLabel('Mostafa Bader'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a photo that will not decode falls back to initials', (
      tester,
    ) async {
      // An instance that has been through a bad migration can hold a
      // non-image in image_128.
      await pump(
        tester,
        UserAvatar(
          name: 'Mostafa Bader',
          photo: Uint8List.fromList(<int>[1, 2, 3, 4]),
        ),
      );
      await tester.pump();

      expect(find.text('MB'), findsOneWidget);
    });

    testWidgets('it is a circle with the accent ring', (tester) async {
      await pump(tester, const UserAvatar(name: 'Mostafa Bader'));

      final box =
          tester.widget<Container>(find.byType(Container).last).decoration!
              as BoxDecoration;
      expect(box.shape, BoxShape.circle);
      expect(box.border!.top.width, AppDimens.avatarRing);
    });
  });

  group('InlineFact', () {
    testWidgets('label, value and footnote read left to right', (tester) async {
      await pump(
        tester,
        const InlineFact(
          icon: Icons.person_rounded,
          label: 'Assigned',
          value: 'Ahmed Mohamed',
          trailing: '12 days',
        ),
      );

      expect(
        tester.getCenter(find.text('Ahmed Mohamed')).dx,
        greaterThan(tester.getCenter(find.text('Assigned')).dx),
      );
      expect(
        tester.getCenter(find.text('12 days')).dx,
        greaterThan(tester.getCenter(find.text('Ahmed Mohamed')).dx),
      );
    });

    testWidgets('the value is the loud half', (tester) async {
      await pump(
        tester,
        const InlineFact(
          icon: Icons.person_rounded,
          label: 'Assigned',
          value: 'Ahmed Mohamed',
        ),
      );

      final label = tester.widget<Text>(find.text('Assigned')).style!;
      final value = tester.widget<Text>(find.text('Ahmed Mohamed')).style!;
      expect(value.fontWeight!.index, greaterThan(label.fontWeight!.index));
    });

    testWidgets('a long value clips instead of pushing the footnote out', (
      tester,
    ) async {
      await pump(
        tester,
        const InlineFact(
          icon: Icons.person_rounded,
          label: 'Assigned',
          value: 'Ahmed Mohamed Abdelrahman El-Sayed',
          trailing: '12 days',
        ),
        size: TestSizes.smallPhone,
      );

      expectNoOverflow(tester);
      expect(find.text('12 days'), findsOneWidget);
    });

    testWidgets('it wraps rather than clips once text is scaled up', (
      tester,
    ) async {
      // Three pieces of prose on one line: at 1.3x in Arabic they no longer
      // share a row, and every one of them is worth reading.
      await pump(
        tester,
        const InlineFact(
          icon: Icons.person_rounded,
          label: 'مُسلَّم',
          value: 'أحمد محمد عبد الرحمن',
          trailing: '١٢ يومًا',
        ),
        locale: const Locale('ar'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      expect(
        tester.getTopLeft(find.text('١٢ يومًا')).dy,
        greaterThan(tester.getTopLeft(find.text('مُسلَّم')).dy),
        reason: 'the footnote should have moved to its own line',
      );
    });
  });

  group('SkeletonBox', () {
    testWidgets('it takes exactly the space it is told to hold', (
      tester,
    ) async {
      await pump(
        tester,
        const Align(child: SkeletonBox(width: 120, height: 24)),
      );

      expect(tester.getSize(find.byType(SkeletonBox)), const Size(120, 24));
    });

    testWidgets('without a width it fills its parent, so a column of them '
        'lines up', (tester) async {
      await pump(tester, const SkeletonBox());

      expect(
        tester.getSize(find.byType(SkeletonBox)).width,
        tester.getSize(find.byType(Scaffold)).width,
      );
    });

    testWidgets('it shimmers in both themes without throwing', (tester) async {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        await pump(tester, const SkeletonBox(width: 80), themeMode: mode);
        expect(tester.takeException(), isNull, reason: '$mode');
      }
    });
  });

  group('AppAttentionTile', () {
    testWidgets('a screen reader hears what the number counts', (tester) async {
      // "3" on its own is not a fact.
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const AppAttentionTile(
          icon: Icons.build_rounded,
          tone: AppColors.statusMaintenance,
          value: '3',
          label: 'In maintenance',
        ),
      );

      expect(find.bySemanticsLabel(RegExp('In maintenance')), findsWidgets);
      handle.dispose();
    });

    testWidgets('the number shrinks to fit rather than clipping', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(
          width: 120,
          child: AppAttentionTile(
            icon: Icons.build_rounded,
            tone: AppColors.statusMaintenance,
            value: '1284',
            label: 'قيد الصيانة والإصلاح',
          ),
        ),
        locale: const Locale('ar'),
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      expect(find.byType(FittedBox), findsWidgets);
    });

    testWidgets('it is tinted with the status it counts', (tester) async {
      await pump(
        tester,
        const AppAttentionTile(
          icon: Icons.warning_rounded,
          tone: AppColors.danger,
          value: '2',
          label: 'Overdue',
        ),
      );

      final fill = tester.widget<Material>(find.byType(Material).last).color!;
      expect(fill.r, closeTo(AppColors.danger.r, 0.01));
      expect(fill.a, lessThan(1));
    });

    testWidgets('a tile with nowhere to go is not a button', (tester) async {
      await pump(
        tester,
        const AppAttentionTile(
          icon: Icons.warning_rounded,
          tone: AppColors.danger,
          value: '2',
          label: 'Overdue',
        ),
      );
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('AppActivityTile', () {
    testWidgets('the entry says what happened and when', (tester) async {
      await pump(
        tester,
        const AppActivityTile(
          icon: Icons.swap_horiz_rounded,
          tone: AppColors.statusAssigned,
          title: 'MacBook Pro assigned to Ahmed',
          timestamp: '2 hours ago',
        ),
      );

      expect(find.text('MacBook Pro assigned to Ahmed'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('2 hours ago')).dy,
        greaterThan(
          tester.getTopLeft(find.text('MacBook Pro assigned to Ahmed')).dy,
        ),
      );
    });

    testWidgets('the divider is opt-in, so the last row has none', (
      tester,
    ) async {
      await pump(
        tester,
        const AppActivityTile(
          icon: Icons.swap_horiz_rounded,
          tone: AppColors.statusAssigned,
          title: 'assigned',
          timestamp: 'now',
        ),
      );
      final last =
          tester.widget<Container>(find.byType(Container).first).decoration
              as BoxDecoration?;
      expect(last?.border, isNull);

      await pump(
        tester,
        const AppActivityTile(
          icon: Icons.swap_horiz_rounded,
          tone: AppColors.statusAssigned,
          title: 'assigned',
          timestamp: 'now',
          showDivider: true,
        ),
      );
      final divided =
          tester.widget<Container>(find.byType(Container).first).decoration!
              as BoxDecoration;
      expect(divided.border, isNotNull);
    });

    testWidgets('a two-line entry in Arabic still fits', (tester) async {
      await pump(
        tester,
        const AppActivityTile(
          icon: Icons.swap_horiz_rounded,
          tone: AppColors.statusAssigned,
          title: 'تم تسليم حاسوب ماك بوك برو إلى أحمد محمد من قسم الأنظمة',
          timestamp: 'قبل ساعتين',
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  group('AppSettingTile', () {
    testWidgets('the row is one thing to a screen reader, not three', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        AppSettingTile(
          icon: Icons.language_rounded,
          title: en.settingsLanguage,
          subtitle: 'English',
          onTap: () {},
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('${en.settingsLanguage}. English')),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('the chevron is a promise, and it can be withheld', (
      tester,
    ) async {
      // A chevron says tapping opens something. On a row that is a *choice*,
      // it lies.
      await pump(
        tester,
        AppSettingTile(
          icon: Icons.dark_mode_rounded,
          title: 'Dark',
          onTap: () {},
          showChevron: false,
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await pump(
        tester,
        AppSettingTile(
          icon: Icons.language_rounded,
          title: 'Language',
          onTap: () {},
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('an inert row shows no chevron either', (tester) async {
      await pump(
        tester,
        const AppSettingTile(
          icon: Icons.info_outline_rounded,
          title: 'Version',
          subtitle: '1.0.0',
          onTap: null,
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('a destructive row is toned, title included', (tester) async {
      await pump(
        tester,
        AppSettingTile(
          icon: Icons.logout_rounded,
          title: en.settingsSignOut,
          tone: AppColors.danger,
          onTap: () {},
        ),
      );

      expect(
        tester.widget<Text>(find.text(en.settingsSignOut)).style?.color,
        AppColors.danger,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.logout_rounded)).color,
        AppColors.danger,
      );
    });

    testWidgets('the row is never smaller than a fingertip', (tester) async {
      await pump(
        tester,
        AppSettingTile(icon: Icons.info_rounded, title: 'A', onTap: () {}),
      );

      expect(
        tester.getSize(find.byType(AppSettingTile)).height,
        greaterThanOrEqualTo(AppDimens.minTapTarget),
      );
    });
  });

  group('the palette both card families read', () {
    testWidgets('a glass card is lighter than the page it sits on, in dark '
        'mode', (tester) async {
      late AppPalette palette;
      await pump(
        tester,
        Builder(
          builder: (context) {
            palette = context.palette;
            return const GlassCard(child: Text('x'));
          },
        ),
        themeMode: ThemeMode.dark,
      );

      expect(palette.glassTop, isNot(palette.glassBottom));
    });
  });
}
