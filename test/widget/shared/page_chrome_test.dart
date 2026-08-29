import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/core/storage/preferences/app_preferences.dart';
import 'package:sijil_it/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/widgets/app_brand_header.dart';
import 'package:sijil_it/shared/widgets/app_logo.dart';
import 'package:sijil_it/shared/widgets/app_nav_bar.dart';
import 'package:sijil_it/shared/widgets/app_scaffold.dart';
import 'package:sijil_it/shared/widgets/app_title_block.dart';

import '../../fake_odoo/test_app_harness.dart';

/// The chrome every screen sits inside: the app bar, the page body, the
/// bottom navigation, the pre-sign-in header, and the row heading block.
///
/// None of it belongs to a feature, which is exactly why it is worth testing
/// on its own: a regression here is not one broken screen, it is every screen
/// at once — and the two things that break it are the two nobody looks at,
/// Arabic and a raised text size.
void main() {
  late AppL10n en;
  late AppL10n ar;

  /// Wide enough to be an "expanded" screen, which [TestSizes.tablet] at 834
  /// is not — the breakpoint is 900.
  const desktop = Size(1200, 900);

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
      TestApp(locale: locale, size: size, textScale: textScale, child: child),
    );
    await tester.pump();
  }

  group('AppScaffold', () {
    testWidgets('the title is the screen, and the subtitle is under it', (
      tester,
    ) async {
      await pump(
        tester,
        const AppScaffold(
          title: 'Assets',
          subtitle: '24 items',
          body: SizedBox.shrink(),
        ),
      );

      expect(find.text('Assets'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('24 items')).dy,
        greaterThan(tester.getTopLeft(find.text('Assets')).dy),
      );
    });

    testWidgets('the bar grows with the text size instead of clipping', (
      tester,
    ) async {
      // Pinned at 66 px the bar clips a scaled title by a few pixels — on
      // every screen in the app simultaneously.
      await pump(
        tester,
        const AppScaffold(
          title: 'Assets',
          subtitle: '24 items',
          body: SizedBox.shrink(),
        ),
      );
      final normal = tester.getSize(find.byType(PreferredSize)).height;

      await pump(
        tester,
        const AppScaffold(
          title: 'Assets',
          subtitle: '24 items',
          body: SizedBox.shrink(),
        ),
        textScale: AppTextScale.max,
      );
      final scaled = tester.getSize(find.byType(PreferredSize)).height;

      expect(scaled, greaterThan(normal));
      expectNoOverflow(tester);
    });

    testWidgets('a bar with no subtitle is shorter than one with', (
      tester,
    ) async {
      await pump(
        tester,
        const AppScaffold(title: 'Assets', body: SizedBox.shrink()),
      );
      final bare = tester.getSize(find.byType(PreferredSize)).height;

      await pump(
        tester,
        const AppScaffold(
          title: 'Assets',
          subtitle: '24 items',
          body: SizedBox.shrink(),
        ),
      );

      expect(
        tester.getSize(find.byType(PreferredSize)).height,
        greaterThan(bare),
      );
    });

    testWidgets('the back arrow calls back, not just pop', (tester) async {
      var went = 0;
      await pump(
        tester,
        AppScaffold(
          title: 'Asset',
          showBack: true,
          onBack: () => went++,
          body: const SizedBox.shrink(),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      expect(went, 1);
    });

    testWidgets('and falls back to popping the route when given nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AppScaffold(
                          title: 'Asset',
                          showBack: true,
                          body: SizedBox.shrink(),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Asset'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a supplied leading widget replaces the back arrow', (
      tester,
    ) async {
      // Both, and the row has two competing ways back out of the screen.
      await pump(
        tester,
        const AppScaffold(
          title: 'Asset',
          showBack: true,
          leading: Icon(Icons.close_rounded),
          body: SizedBox.shrink(),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('the back arrow leads in Arabic too — from the right', (
      tester,
    ) async {
      await pump(
        tester,
        const AppScaffold(
          title: 'الأصل',
          showBack: true,
          body: SizedBox.shrink(),
        ),
        locale: const Locale('ar'),
      );

      expect(
        tester.getCenter(find.byIcon(Icons.arrow_back_rounded)).dx,
        greaterThan(tester.getCenter(find.text('الأصل')).dx),
        reason:
            'the way back sits at the start of the row, which in Arabic '
            'is the right edge',
      );
    });

    testWidgets('a title widget replaces the title, and the string stays the '
        'accessible name', (tester) async {
      await pump(
        tester,
        const AppScaffold(
          title: 'Dashboard',
          titleWidget: Text('Good evening, Mostafa'),
          body: SizedBox.shrink(),
        ),
      );

      expect(find.text('Good evening, Mostafa'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('aboveBody is pinned over the body, not scrolled with it', (
      tester,
    ) async {
      await pump(
        tester,
        const AppScaffold(
          title: 'Assets',
          aboveBody: SizedBox(height: 40, child: Text('search')),
          body: Center(child: Text('list')),
        ),
      );

      expect(
        tester.getBottomLeft(find.text('search')).dy,
        lessThan(tester.getTopLeft(find.text('list')).dy),
      );
    });

    testWidgets('a bottom bar becomes a sticky action bar', (tester) async {
      await pump(
        tester,
        const AppScaffold(
          title: 'Return',
          bottomBar: Text('confirm'),
          body: SizedBox.shrink(),
        ),
      );

      expect(find.byType(StickyActionBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StickyActionBar),
          matching: find.text('confirm'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and no bar at all when the screen has no action', (
      tester,
    ) async {
      await pump(
        tester,
        const AppScaffold(title: 'Assets', body: SizedBox.shrink()),
      );

      expect(find.byType(StickyActionBar), findsNothing);
    });

    testWidgets('a long Arabic title ellipsizes rather than overflowing', (
      tester,
    ) async {
      await pump(
        tester,
        const AppScaffold(
          title: 'إدارة الأصول التقنية والأجهزة المحمولة والخوادم',
          subtitle: 'آخر مزامنة قبل ثلاث دقائق من خادم أودو الرئيسي',
          showBack: true,
          actions: [Icon(Icons.search_rounded)],
          body: SizedBox.shrink(),
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });
  });

  group('StickyActionBar', () {
    testWidgets('the hint sits above the action it explains', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: StickyActionBar(hint: Text('4 assets'), child: Text('Confirm')),
        ),
      );

      expect(
        tester.getBottomLeft(find.text('4 assets')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Confirm')).dy),
      );
    });

    testWidgets('it clears the home indicator instead of guessing at it', (
      tester,
    ) async {
      // A confirm button placed with plain padding ends up under the gesture
      // bar on every modern phone.
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.phone,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(bottom: 34)),
              child: const Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: StickyActionBar(child: Text('Confirm')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getBottomLeft(find.text('Confirm')).dy,
        lessThanOrEqualTo(
          tester.getBottomLeft(find.byType(StickyActionBar)).dy - 34,
        ),
      );
    });
  });

  group('AppPageBody', () {
    testWidgets('the gutter is the page gutter, on both edges', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: AppPageBody(children: [SizedBox(height: 20, child: Text('a'))]),
        ),
      );

      final row = tester.getRect(find.text('a'));
      final page = tester.getSize(find.byType(Scaffold)).width;
      expect(row.left, greaterThan(0));
      expect(row.left, closeTo(page - row.right, 0.5));
    });

    testWidgets('and disappears for a screen that pads its own rows', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(
          body: AppPageBody(
            padded: false,
            children: [SizedBox(height: 20, child: Text('a'))],
          ),
        ),
      );

      expect(tester.getRect(find.text('a')).left, 0);
    });

    testWidgets('pull-to-refresh exists only where there is something to '
        'refresh', (tester) async {
      await pump(
        tester,
        const Scaffold(body: AppPageBody(children: [Text('a')])),
      );
      expect(find.byType(RefreshIndicator), findsNothing);

      await pump(
        tester,
        Scaffold(
          body: AppPageBody(
            onRefresh: () async {},
            children: const [Text('a')],
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('a wide screen gets a reading measure, not a full-bleed row', (
      tester,
    ) async {
      // Text that runs the full 1200 px of a desktop window is unreadable.
      await pump(
        tester,
        const Scaffold(body: AppPageBody(children: [Text('a')])),
        size: desktop,
      );

      expect(
        tester.getSize(find.byType(ListView)).width,
        AppDimens.contentMaxWidth,
      );
    });
  });

  group('AppNavBar', () {
    final items = <NavItem>[
      const NavItem(label: 'Home', icon: Icons.home_rounded),
      const NavItem(label: 'Assets', icon: Icons.inventory_2_rounded),
      const NavItem(
        label: 'Scan',
        icon: Icons.qr_code_scanner_rounded,
        isPrimary: true,
      ),
      const NavItem(label: 'People', icon: Icons.people_rounded),
      const NavItem(label: 'More', icon: Icons.grid_view_rounded),
    ];

    Widget bar({int current = 0, void Function(int)? onSelected}) => Scaffold(
      body: const SizedBox.shrink(),
      bottomNavigationBar: AppNavBar(
        items: items,
        currentIndex: current,
        onSelected: onSelected ?? (_) {},
      ),
    );

    /// The [Semantics] this destination declares, by the label it carries.
    SemanticsProperties declared(WidgetTester tester, String label) => tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(AppNavBar),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere((s) => s.properties.label == label)
        .properties;

    testWidgets('every destination is reachable and named', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, bar());

      for (final item in items) {
        expect(
          find.bySemanticsLabel(RegExp(item.label)),
          findsWidgets,
          reason: '${item.label} is unreachable by name',
        );
      }

      // Scan is the exception: a raised glyph with no printed label, which is
      // exactly why it must carry one for a screen reader.
      expect(find.text('Scan'), findsNothing);
      handle.dispose();
    });

    testWidgets('tapping a destination reports its index', (tester) async {
      final taps = <int>[];
      await pump(tester, bar(onSelected: taps.add));

      await tester.tap(find.text('People'));
      await tester.pump();
      expect(taps, [3]);
    });

    testWidgets('the raised scan button reports its index too', (tester) async {
      // It is lifted out of the row by a Transform, which is exactly the kind
      // of thing that ends up outside its own hit area.
      final taps = <int>[];
      await pump(tester, bar(onSelected: taps.add));

      await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
      await tester.pump();
      expect(taps, [2]);
    });

    testWidgets('the current destination is announced as selected', (
      tester,
    ) async {
      // Colour alone does not tell a screen-reader user which tab they are on.
      await pump(tester, bar(current: 3));

      expect(declared(tester, 'People').selected, isTrue);
      expect(declared(tester, 'Home').selected, isFalse);
    });

    testWidgets('and it is tinted differently from the rest', (tester) async {
      await pump(tester, bar(current: 3));
      final selected = tester.widget<Text>(find.text('People')).style?.color;
      final other = tester.widget<Text>(find.text('Home')).style?.color;

      expect(selected, isNotNull);
      expect(selected, isNot(other));
    });

    testWidgets('scan is never selected, whatever the index says', (
      tester,
    ) async {
      // It is an action, not a tab. Rendering it as "where you are" implies
      // somewhere to come back to — and the screen it opens is one the user
      // leaves the moment it finds something.
      await pump(tester, bar(current: 2));

      expect(declared(tester, 'Scan').selected, isNull);
      expect(declared(tester, 'Home').selected, isFalse);
    });

    testWidgets('a glyph replaces the icon where Material has no such shape', (
      tester,
    ) async {
      await pump(
        tester,
        Scaffold(
          bottomNavigationBar: AppNavBar(
            items: const <NavItem>[
              NavItem(label: 'Home', icon: Icons.home_rounded),
              NavItem(
                label: 'More',
                icon: Icons.more_horiz_rounded,
                glyph: GridGlyph(),
              ),
            ],
            currentIndex: 0,
            onSelected: (_) {},
          ),
          body: const SizedBox.shrink(),
        ),
      );

      expect(find.byType(GridGlyph), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });

    testWidgets('it survives five Arabic labels at the text ceiling', (
      tester,
    ) async {
      await pump(
        tester,
        Scaffold(
          bottomNavigationBar: AppNavBar(
            items: const <NavItem>[
              NavItem(label: 'الرئيسية', icon: Icons.home_rounded),
              NavItem(label: 'الأصول', icon: Icons.inventory_2_rounded),
              NavItem(
                label: 'مسح',
                icon: Icons.qr_code_scanner_rounded,
                isPrimary: true,
              ),
              NavItem(label: 'الموظفون', icon: Icons.people_rounded),
              NavItem(label: 'المزيد', icon: Icons.grid_view_rounded),
            ],
            currentIndex: 0,
            onSelected: (_) {},
          ),
          body: const SizedBox.shrink(),
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
    });

    testWidgets('the bar itself grows with the labels', (tester) async {
      await pump(tester, bar());
      final normal = tester.getSize(find.byType(AppNavBar)).height;

      await pump(tester, bar(), textScale: AppTextScale.max);
      expect(
        tester.getSize(find.byType(AppNavBar)).height,
        greaterThan(normal),
      );
    });
  });

  group('GridGlyph', () {
    testWidgets('it draws six tiles, three across and two down', (
      tester,
    ) async {
      await pump(tester, const Center(child: GridGlyph()));

      final tiles = find.descendant(
        of: find.byType(GridGlyph),
        matching: find.byType(Container),
      );
      expect(tiles, findsNWidgets(6));

      // Three share a row, and the second row sits below the first.
      final first = tester.getCenter(tiles.at(0));
      expect(tester.getCenter(tiles.at(1)).dy, first.dy);
      expect(tester.getCenter(tiles.at(2)).dy, first.dy);
      expect(tester.getCenter(tiles.at(3)).dy, greaterThan(first.dy));
    });

    testWidgets('it fills the icon size it is given, not a fixed one', (
      tester,
    ) async {
      await pump(
        tester,
        const Center(
          child: IconTheme(data: IconThemeData(size: 32), child: GridGlyph()),
        ),
      );

      expect(tester.getSize(find.byType(GridGlyph)), const Size(32, 32));
    });

    testWidgets('a different grid draws a different number of tiles', (
      tester,
    ) async {
      await pump(tester, const Center(child: GridGlyph(columns: 2, rows: 2)));

      expect(
        find.descendant(
          of: find.byType(GridGlyph),
          matching: find.byType(Container),
        ),
        findsNWidgets(4),
      );
    });
  });

  group('AppBrandHeader', () {
    late AppPreferences prefs;
    late AppSettingsCubit settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await AppPreferences.create();
      settings = AppSettingsCubit(prefs);
    });

    tearDown(() async => settings.close());

    Future<void> pumpHeader(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      await tester.pumpWidget(
        BlocProvider<AppSettingsCubit>.value(
          value: settings,
          child: TestApp(
            locale: locale,
            themeMode: themeMode,
            size: TestSizes.phone,
            child: const Scaffold(body: Center(child: AppBrandHeader())),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the language control names the language it switches to', (
      tester,
    ) async {
      // A globe glyph tells a user nothing about which languages are on offer.
      await pumpHeader(tester);
      expect(find.text('ع'), findsOneWidget);

      await pumpHeader(tester, locale: const Locale('ar'));
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('and switching it is what a user does before signing in', (
      tester,
    ) async {
      // Settings is behind the sign-in. Someone who cannot read the connection
      // form has no other way to reach this.
      await pumpHeader(tester);

      await tester.tap(find.text('ع'));
      await tester.pump();
      expect(settings.state.locale, const Locale('ar'));
    });

    testWidgets('the theme control shows the mode the tap will switch to', (
      tester,
    ) async {
      await pumpHeader(tester);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

      await pumpHeader(tester, themeMode: ThemeMode.dark);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    });

    testWidgets('tapping it stores the mode that is now on screen', (
      tester,
    ) async {
      await pumpHeader(tester, themeMode: ThemeMode.dark);

      await tester.tap(find.byIcon(Icons.light_mode_rounded));
      await tester.pump();
      expect(settings.state.themeMode, ThemeMode.light);
    });

    testWidgets('both controls are reachable by a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHeader(tester);

      expect(
        find.bySemanticsLabel(RegExp(en.tooltipToggleLanguage)),
        findsWidgets,
      );
      expect(
        find.bySemanticsLabel(RegExp(en.tooltipToggleTheme)),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('the mark stays centred whatever sits beside it', (
      tester,
    ) async {
      await pumpHeader(tester);

      // Centred against the row, not against what is left over beside the
      // controls — otherwise the mark shifts as controls are added.
      final header = tester.getRect(find.byType(AppBrandHeader));
      final mark = tester.getRect(find.byType(AppLogo));
      expect(mark.center.dx, closeTo(header.center.dx, 1));
    });

    testWidgets('the row is a tap target tall, and named in Arabic too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHeader(tester, locale: const Locale('ar'));

      expect(
        tester.getSize(find.byType(AppBrandHeader)).height,
        AppDimens.minTapTarget,
      );
      expect(
        find.bySemanticsLabel(RegExp(ar.tooltipToggleLanguage)),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('AppTitleBlock', () {
    Future<void> pumpBlock(
      WidgetTester tester,
      AppTitleBlock block, {
      Locale locale = const Locale('en'),
      Size size = TestSizes.phone,
      double textScale = 1,
    }) => pump(
      tester,
      Scaffold(
        body: Center(child: Row(children: <Widget>[block])),
      ),
      locale: locale,
      size: size,
      textScale: textScale,
    );

    testWidgets('a title on its own renders one line', (tester) async {
      await pumpBlock(tester, const AppTitleBlock(title: 'ThinkPad L15'));

      expect(find.text('ThinkPad L15'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('an empty subtitle is left out rather than drawn blank', (
      tester,
    ) async {
      // Rendered blank, the row's height stops following its content and the
      // list turns ragged.
      await pumpBlock(
        tester,
        const AppTitleBlock(title: 'ThinkPad L15', subtitle: '', caption: ''),
      );

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('title, subtitle and caption stack in that order', (
      tester,
    ) async {
      await pumpBlock(
        tester,
        const AppTitleBlock(
          title: 'Mostafa Bader',
          subtitle: 'IT Department',
          caption: 'mostafa@example.com',
        ),
      );

      final title = tester.getTopLeft(find.text('Mostafa Bader')).dy;
      final subtitle = tester.getTopLeft(find.text('IT Department')).dy;
      final caption = tester.getTopLeft(find.text('mostafa@example.com')).dy;
      expect(subtitle, greaterThan(title));
      expect(caption, greaterThan(subtitle));
    });

    testWidgets('a widget line renders after the prose lines', (tester) async {
      // The asset rows put a Latin, monospaced tag here — it cannot go through
      // `subtitle`, which follows the language.
      await pumpBlock(
        tester,
        const AppTitleBlock(
          title: 'ThinkPad L15',
          subtitle: 'Lenovo',
          below: Text('DH-LAP-0027'),
        ),
      );

      expect(
        tester.getTopLeft(find.text('DH-LAP-0027')).dy,
        greaterThan(tester.getTopLeft(find.text('Lenovo')).dy),
      );
    });

    testWidgets('it claims the rest of the row it is in', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: Row(
            children: <Widget>[
              SizedBox(width: 40),
              AppTitleBlock(title: 'ThinkPad L15'),
              SizedBox(width: 40),
            ],
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(AppTitleBlock)).width,
        tester.getSize(find.byType(Row)).width - 80,
      );
    });

    testWidgets('and stays out of a column, where an Expanded would throw', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(
          body: Column(
            children: <Widget>[AppTitleBlock(title: 'Notes', expand: false)],
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('every line clips instead of painting a yellow bar', (
      tester,
    ) async {
      // The rule this widget exists to enforce: one copy that forgets
      // `overflow` looks fine in English and breaks the row in Arabic.
      await pumpBlock(
        tester,
        const AppTitleBlock(
          title: 'حاسوب محمول لينوفو ثينك باد الجيل الثالث عشر',
          subtitle: 'قسم تقنية المعلومات — الطابق الثالث، مبنى الإدارة',
          caption: 'mostafa.bader@digital-harbor.example.com',
        ),
        locale: const Locale('ar'),
        size: TestSizes.smallPhone,
        textScale: AppTextScale.max,
      );

      expectNoOverflow(tester);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          text.overflow,
          TextOverflow.ellipsis,
          reason: '"${text.data}" can run off the row',
        );
      }
    });
  });
}
