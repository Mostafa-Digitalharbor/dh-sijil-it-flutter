import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/network/odoo/odoo_name_ref.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_query.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/presentation/widgets/asset_filter_sheet.dart';
import 'package:sijil_it/shared/widgets/app_sheets.dart';
import 'package:sijil_it/shared/widgets/state_views.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The surfaces `responsive_sweep_test` cannot reach.
///
/// That sweep renders every *screen* against seeded data, which means it only
/// ever exercises the success path with content that fits. Two whole families
/// of layout were therefore never measured:
///
/// 1. **The failure and empty treatments.** They carry the longest copy in the
///    product — a title, a cause, a "what to do" card and a button, four
///    blocks where a row normally has one — and they only appear when
///    something has already gone wrong, which is the worst moment to also clip
///    the sentence explaining it.
///
/// 2. **Sheets and dialogs.** They are pushed above a route rather than being
///    the route, so pumping the page never builds them. A bottom sheet is also
///    the layout most likely to overflow: it is height-constrained by
///    definition, and the keyboard takes half of what is left.
///
/// Both families are run at the worst case the app can actually reach — the
/// narrowest device, the longer language, and the largest text the clamp
/// allows.
void main() {
  late FakeOdooData data;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  /// The narrowest device, the longer language, the text ceiling.
  Future<void> pumpWorstCase(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      TestApp(
        size: TestSizes.smallPhone,
        locale: const Locale('ar', 'EG'),
        textScale: AppTextScale.max,
        child: signedInScreen(child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('failure view', () {
    // Every kind, not a sample: the copy differs per kind and the longest one
    // is the one that breaks. `accessDenied` and `fieldUnavailable` also
    // interpolate a server-supplied model or field name into the body, so they
    // are the two that can exceed whatever length the ARB author measured.
    for (final kind in FailureKind.values) {
      testWidgets('${kind.name} fits the worst case', (tester) async {
        await pumpWorstCase(
          tester,
          Scaffold(
            body: FailureView(
              failure: Failure(
                kind: kind,
                model: 'maintenance.equipment',
                operation: OdooOperation.write,
                // The wording Odoo 19 actually sends for a constraint failure.
                serverMessage:
                    'The operation cannot be completed: Missing required '
                    'value for the field Subjects (name).',
              ),
              onRetry: () {},
            ),
          ),
        );
        expectNoOverflow(tester);
      });
    }

    for (final (sizeName, size) in TestSizes.all) {
      testWidgets('renders on a $sizeName', (tester) async {
        await tester.pumpWidget(
          TestApp(
            size: size,
            child: signedInScreen(
              Scaffold(
                body: FailureView(
                  failure: const Failure(kind: FailureKind.accessDenied),
                  onRetry: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });
    }
  });

  group('empty state', () {
    testWidgets('fits the worst case with an action', (tester) async {
      await pumpWorstCase(
        tester,
        Scaffold(
          body: EmptyStateView(
            title: 'لا توجد أصول بعد',
            message:
                'الأصول التي تضيفها أو تستوردها إلى أودو ستظهر هنا، '
                'ويمكنك البدء بإضافة أول أصل من الزر بالأسفل.',
            actionLabel: 'إضافة أصل',
            onAction: () {},
          ),
        ),
      );
      expectNoOverflow(tester);
    });
  });

  group('confirm dialog', () {
    // The delete confirmation is the one dialog whose message the user has to
    // finish reading before they answer it. `AlertDialog` clips rather than
    // scrolls unless it is told otherwise, and the Arabic copy at the text
    // ceiling is taller than the box it is given.
    testWidgets('long copy stays reachable at the text ceiling', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          size: TestSizes.smallPhone,
          locale: const Locale('ar', 'EG'),
          textScale: AppTextScale.max,
          child: signedInScreen(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AppConfirmDialog.show(
                    context,
                    title: 'حذف هذا الأصل؟',
                    message:
                        'سيُحذف الأصل من أودو نهائيًا لجميع المستخدمين، '
                        'بما في ذلك سجل التسليم والإرجاع والصور المرفقة به. '
                        'لا يمكن التراجع عن هذا الإجراء.',
                    confirmLabel: 'حذف نهائيًا',
                    isDestructive: true,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expectNoOverflow(tester);
      // The last line of the warning has to survive, not merely be laid out.
      expect(find.textContaining('لا يمكن التراجع'), findsOneWidget);
    });
  });

  group('asset filter sheet', () {
    Widget host() => Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => AssetFilterSheet.show(
            context,
            filters: const AssetFilters(),
            sort: AssetSort.defaultSort,
            categories: const <OdooNameRef>[
              OdooNameRef(1, 'أجهزة كمبيوتر محمولة'),
              OdooNameRef(2, 'شاشات وأجهزة عرض'),
            ],
            manufacturers: const <String>['Dell', 'Hewlett-Packard'],
            departments: const <OdooNameRef>[OdooNameRef(3, 'تقنية المعلومات')],
          ),
          child: const Text('open'),
        ),
      ),
    );

    for (final (sizeName, size) in TestSizes.all) {
      testWidgets('fits a $sizeName', (tester) async {
        await tester.pumpWidget(
          TestApp(size: size, child: signedInScreen(host())),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });
    }

    testWidgets('fits the worst case', (tester) async {
      await pumpWorstCase(tester, host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });
  });

  group('option sheet', () {
    // The shape behind the status picker: a title, a subtitle, and a row per
    // option carrying an icon, a label and a selected tick.
    Widget host() => Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => AppOptionSheet.show<AssetStatus>(
            context,
            title: 'تغيير الحالة',
            subtitle:
                'تُسجَّل هذه الحالات كملاحظة في أودو لأن أودو القياسي '
                'لا يحتوي على حقل لها.',
            selected: AssetStatus.available,
            options: <AppSheetOption<AssetStatus>>[
              for (final status in AssetStatus.values)
                AppSheetOption<AssetStatus>(
                  value: status,
                  label: 'حالة الأصل ${status.name}',
                  icon: Icons.circle_outlined,
                ),
            ],
          ),
          child: const Text('open'),
        ),
      ),
    );

    for (final (sizeName, size) in TestSizes.all) {
      testWidgets('fits a $sizeName', (tester) async {
        await tester.pumpWidget(
          TestApp(size: size, child: signedInScreen(host())),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });
    }

    testWidgets('fits the worst case', (tester) async {
      await pumpWorstCase(tester, host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });
  });

  group('snackbar', () {
    // A failure snackbar carries `FailurePresenter.shortMessage`, which for a
    // business rule is Odoo's own sentence — unbounded, and written on
    // somebody else's server.
    testWidgets('a long server message does not overflow', (tester) async {
      await pumpWorstCase(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AppSnack.failure(
                context,
                const Failure(
                  kind: FailureKind.businessRule,
                  serverMessage:
                      'لا يمكن إتمام العملية: يجب إرجاع الأصل من الموظف '
                      'الحالي قبل تسليمه إلى موظف آخر، وذلك لأن الأصل '
                      'مسجَّل حاليًا باسم موظف آخر في أودو.',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });
  });
}
