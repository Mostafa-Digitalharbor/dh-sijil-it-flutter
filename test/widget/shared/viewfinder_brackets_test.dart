import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/theme/app_dimens.dart';
import 'package:sijil_it/shared/widgets/viewfinder_brackets.dart';

import '../../fake_odoo/test_app_harness.dart';

/// The aim marks on the scanner and the audit counter.
///
/// The two screens drew these separately until they were merged, and the
/// copies had already diverged in the way that matters least visibly and most
/// practically: the audit's was built from absolute `left`/`right` borders, so
/// under Arabic its brackets stayed put while every other element on the
/// screen mirrored. Both still looked like brackets, which is why nobody
/// caught it by eye.
void main() {
  const side = 200.0;

  Future<Rect> bracketBounds(
    WidgetTester tester, {
    required TextDirection direction,
  }) async {
    await tester.pumpWidget(
      TestApp(
        locale: direction == TextDirection.rtl
            ? const Locale('ar', 'EG')
            : const Locale('en'),
        child: const Center(child: ViewfinderBrackets(size: side)),
      ),
    );
    await tester.pumpAndSettle();

    // The first bracket in the stack is `topStart`.
    final first = find
        .descendant(
          of: find.byType(ViewfinderBrackets),
          matching: find.byType(SizedBox),
        )
        .at(1);
    return tester.getRect(first);
  }

  testWidgets('it spans exactly the square it is given', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        child: Center(child: ViewfinderBrackets(size: side)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(ViewfinderBrackets)),
      const Size(side, side),
    );
  });

  testWidgets('the top bracket sits on the leading edge in English', (
    tester,
  ) async {
    final bounds = await bracketBounds(tester, direction: TextDirection.ltr);
    final finder = tester.getRect(find.byType(ViewfinderBrackets));

    expect(bounds.left, closeTo(finder.left, 0.5));
    expect(bounds.top, closeTo(finder.top, 0.5));
  });

  testWidgets('and mirrors to the other edge in Arabic', (tester) async {
    // The whole point of the shared widget. An absolute `left` border passes
    // the English test above and fails this one.
    final bounds = await bracketBounds(tester, direction: TextDirection.rtl);
    final finder = tester.getRect(find.byType(ViewfinderBrackets));

    expect(bounds.right, closeTo(finder.right, 0.5));
    expect(bounds.top, closeTo(finder.top, 0.5));
  });

  testWidgets('with no size it fills its parent', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        child: Center(
          child: SizedBox(
            width: 320,
            height: 120,
            child: Stack(children: <Widget>[ViewfinderBrackets()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(ViewfinderBrackets)),
      const Size(320, 120),
    );
  });

  testWidgets('the scanner variant is the heavier one', (tester) async {
    // Different weights on purpose: the scanner's finder is the whole screen
    // and the audit's is a strip, so the same stroke reads differently.
    expect(AppDimens.scannerCorner, greaterThan(AppDimens.viewfinderCorner));
    expect(
      AppDimens.scannerCornerWidth,
      greaterThan(AppDimens.viewfinderCornerWeight),
    );
  });
}
