import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/features/assets/data/services/asset_note_vocabulary.dart';
import 'package:sijil_it/features/assets/domain/entities/return_due.dart';

/// The expected-return date: when it counts as late, and how it survives a
/// round trip through the chatter.
///
/// Both halves matter and neither is visible from the other. The value object
/// decides what "overdue" means, and four screens rely on it agreeing with
/// itself down to the day boundary; the note vocabulary decides how the date
/// is written into Odoo, and every past assignment has to keep parsing after
/// anybody edits the wording.
void main() {
  /// Pinned, so nothing here flakes when the clock rolls past midnight.
  final now = DateTime(2026, 8, 30, 14, 30);

  ReturnDue evaluate(DateTime? date, {bool isAssigned = true}) =>
      ReturnDue.evaluate(date: date, isAssigned: isAssigned, now: now);

  group('when an asset is late', () {
    test('no date is not the same as on time', () {
      // The distinction the whole feature rests on. Most handovers are
      // permanent, and a fleet that reported every dateless assignment as
      // "on time" would be a fleet whose overdue screen nobody trusts.
      final due = evaluate(null);

      expect(due.state, ReturnDueState.none);
      expect(due.isOverdue, isFalse);
      expect(due.isSet, isFalse);
      expect(due.state.needsAttention, isFalse);
    });

    test('a date that has passed is overdue', () {
      final due = evaluate(DateTime(2026, 8, 26));

      expect(due.state, ReturnDueState.overdue);
      expect(due.daysLate, 4);
      // Both readings come from one number, so "4 days late" and "-4 days
      // left" can never disagree.
      expect(due.daysRemaining, -4);
    });

    test('today is not yet late, whatever the time of day', () {
      // Evaluated at half past two in the afternoon against a date with no
      // time on it at all. Comparing the raw moments would have made every
      // asset due today overdue from one minute past midnight.
      final due = evaluate(DateTime(2026, 8, 30));

      expect(due.state, ReturnDueState.dueSoon);
      expect(due.daysRemaining, 0);
      expect(due.daysLate, 0);
    });

    test('the warning window is the last few days, not the whole loan', () {
      final edge = evaluate(
        DateTime(2026, 8, 30 + AppConstants.returnDueSoonDays),
      );
      final beyond = evaluate(
        DateTime(2026, 8, 31 + AppConstants.returnDueSoonDays),
      );

      expect(edge.state, ReturnDueState.dueSoon);
      // A badge that lights up a fortnight out is a badge that is always lit.
      expect(beyond.state, ReturnDueState.scheduled);
      expect(beyond.state.needsAttention, isFalse);
    });

    test('an asset nobody holds is never late', () {
      // The rule that keeps a returned laptop off the overdue list. The note
      // that set its due date is still in the chatter — it is history — so the
      // date alone would keep counting for ever.
      final due = evaluate(DateTime(2020, 1, 1), isAssigned: false);

      expect(due.state, ReturnDueState.none);
      expect(due.isOverdue, isFalse);
    });
  });

  group('the clause written into the chatter', () {
    test('a date survives being written and read back', () {
      final clause = AssetNoteVocabulary.dueClause(DateTime(2026, 9, 30));

      expect(clause, contains('2026-09-30'));
      expect(AssetNoteVocabulary.dueDateIn(clause), DateTime(2026, 9, 30));
    });

    test('it parses out of the middle of a full assignment note', () {
      // The clause rides along inside the handover sentence rather than being
      // a note of its own, so that one event is one line of history. Which
      // means it has to be found anywhere in the body, not at the start.
      const body =
          'Assigned to Ahmed Mohamed on 2026-08-30. Due back on 2026-09-15. '
          '— handed over with the charger';

      expect(AssetNoteVocabulary.dueDateIn(body), DateTime(2026, 9, 15));
    });

    test('a handover with no date clears the previous holder\'s', () {
      // Written out rather than omitted. The date is read back as "the newest
      // note mentioning Due back", so a silent note would let last quarter's
      // loan date attach itself to a freshly-issued laptop.
      final clause = AssetNoteVocabulary.dueClause(null);

      expect(clause, contains(AssetNoteVocabulary.duePrefix));
      expect(AssetNoteVocabulary.dueDateIn(clause), isNull);
    });

    test('a note that never mentioned a date reads as no date', () {
      expect(
        AssetNoteVocabulary.dueDateIn('Returned by Ahmed on 2026-08-30.'),
        isNull,
      );
      expect(AssetNoteVocabulary.dueDateIn(''), isNull);
    });

    test('a truncated date is refused rather than half-read', () {
      // `DateTime.tryParse` is happy to read '2026-09' as September the first,
      // which would silently invent a due date two weeks off.
      expect(AssetNoteVocabulary.dueDateIn('Due back on 2026-09'), isNull);
    });
  });
}
