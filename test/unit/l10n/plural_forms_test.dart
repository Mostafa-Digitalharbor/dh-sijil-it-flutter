import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

/// Arabic agreement, and the English "1 days" bug.
///
/// Seven strings carrying a day, hour or minute count were flat text with the
/// number dropped in. Arabic has five plural categories and needs all of them;
/// English needs two and had one. Both were visibly wrong on the dashboard:
/// the activity feed read "قبل 3 يوم" where Arabic requires "قبل 3 أيام", and
/// a warranty with a day left read "Expires in 1 days".
void main() {
  late AppL10n en;
  late AppL10n ar;

  setUpAll(() async {
    en = await AppL10n.delegate.load(const Locale('en'));
    ar = await AppL10n.delegate.load(const Locale('ar'));
  });

  group('English', () {
    test('one is singular, everything else plural', () {
      expect(en.warrantyExpiresIn(1), 'Expires in 1 day');
      expect(en.warrantyExpiresIn(2), 'Expires in 2 days');
      expect(en.warrantyExpiredAgo(1), 'Expired 1 day ago');
      expect(en.warrantyExpiredAgo(30), 'Expired 30 days ago');
      expect(en.labelHeldDays(1), '1 day');
      expect(en.labelHeldDays(7), '7 days');
      expect(en.returnHeldFor(1), 'held 1 day');
      expect(en.detectFoundCount(1), 'Found 1 database');
      expect(en.detectFoundCount(3), 'Found 3 databases');
      expect(en.employeeItemCount(1), '1 item');
      expect(en.employeeItemCount(0), 'No items');
    });
  });

  group('Arabic', () {
    // CLDR gives Arabic five categories: one, two, few (3–10), many (11–99)
    // and other (100+). Getting `few` wrong is the visible one, because 3–10
    // is the range a relative timestamp actually lands in.
    test('day counts agree with the number', () {
      expect(ar.timeDaysAgo(1), 'قبل يوم');
      expect(ar.timeDaysAgo(2), 'قبل يومين');
      // The bug this file was written for: was "قبل 3 يوم".
      expect(ar.timeDaysAgo(3), 'قبل 3 أيام');
      expect(ar.timeDaysAgo(6), 'قبل 6 أيام');
    });

    test('hours and minutes agree too', () {
      expect(ar.timeHoursAgo(1), 'قبل ساعة');
      expect(ar.timeHoursAgo(2), 'قبل ساعتين');
      expect(ar.timeHoursAgo(5), 'قبل 5 ساعات');
      expect(ar.timeHoursAgo(15), 'قبل 15 ساعة');

      expect(ar.timeMinutesAgo(1), 'قبل دقيقة');
      expect(ar.timeMinutesAgo(3), 'قبل 3 دقائق');
      expect(ar.timeMinutesAgo(45), 'قبل 45 دقيقة');
    });

    test('warranty spans agree', () {
      expect(ar.warrantyExpiresIn(1), 'ينتهي خلال يوم واحد');
      expect(ar.warrantyExpiresIn(2), 'ينتهي خلال يومين');
      expect(ar.warrantyExpiresIn(5), 'ينتهي خلال 5 أيام');
      // 30 lands in `many`, which is why the fixed copy for the 30-day filter
      // reads "يومًا" and was correct all along.
      expect(ar.warrantyExpiresIn(30), 'ينتهي خلال 30 يومًا');
      expect(ar.warrantyExpiredAgo(4), 'انتهى منذ 4 أيام');
    });

    test('held-for spans agree', () {
      expect(ar.labelHeldDays(0), 'أقل من يوم');
      expect(ar.labelHeldDays(1), 'يوم واحد');
      expect(ar.labelHeldDays(2), 'يومان');
      expect(ar.labelHeldDays(9), '9 أيام');
      expect(ar.labelHeldDays(40), '40 يومًا');
    });

    test('counts of things agree', () {
      expect(ar.employeeItemCount(0), 'لا توجد عناصر');
      expect(ar.employeeItemCount(1), 'عنصر واحد');
      expect(ar.employeeItemCount(2), 'عنصران');
      expect(ar.employeeItemCount(4), '4 عناصر');
      expect(ar.detectFoundCount(3), 'تم العثور على 3 قواعد بيانات');
    });

    test('every plural branch still renders Western digits', () {
      const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
      for (final rendered in <String>[
        ar.timeDaysAgo(3),
        ar.timeHoursAgo(5),
        ar.timeMinutesAgo(45),
        ar.warrantyExpiresIn(30),
        ar.labelHeldDays(9),
        ar.employeeItemCount(4),
      ]) {
        expect(
          rendered.split('').any(arabicIndic.contains),
          isFalse,
          reason: rendered,
        );
      }
    });
  });
}
