import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/notifications/notification_service.dart';
import 'package:sijil_it/core/notifications/reminder_scheduler.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/entities/warranty.dart';

/// What gets a notification, when, and what does not.
///
/// The scheduling itself needs a device; the decisions do not, and the
/// decisions are where this can go wrong — an alarm for a date that has
/// already passed, two warnings for one asset, or a phone full of a hundred
/// notifications nobody will read.
void main() {
  final now = DateTime(2026, 8, 29, 8);

  const copy = ReminderCopy(title: 'A warranty is running out', body: _body);

  Asset assetWith({
    required int id,
    DateTime? warrantyEnd,
    String name = 'MacBook Pro',
  }) => Asset(
    id: id,
    name: name,
    status: AssetStatus.available,
    warranty: warrantyEnd == null
        ? Warranty.unknown
        : Warranty.evaluate(endDate: warrantyEnd, now: now),
  );

  List<ScheduledReminder> plan(List<Asset> assets, {int leadDays = 30}) =>
      ReminderScheduler.plan(assets, copy, leadDays, now: now);

  test('a warranty ending in two months warns a month before it does', () {
    final reminders = plan(<Asset>[
      assetWith(id: 1, warrantyEnd: DateTime(2026, 10, 29)),
    ]);

    expect(reminders, hasLength(1));
    expect(
      reminders.single.at,
      DateTime(2026, 9, 29, ReminderScheduler.hourOfDay),
    );
  });

  test('an asset with no warranty date gets nothing', () {
    // Odoo records `warranty_date` on a minority of equipment. Warning about
    // a date that does not exist is worse than saying nothing.
    expect(plan(<Asset>[assetWith(id: 1)]), isEmpty);
  });

  test('a warranty already inside the window is not warned about', () {
    // The lead time has passed. The dashboard still counts it; an alarm for
    // something that has already happened is noise.
    final reminders = plan(<Asset>[
      assetWith(id: 1, warrantyEnd: DateTime(2026, 9, 5)),
    ]);

    expect(reminders, isEmpty);
  });

  test('and neither is one that expired last year', () {
    expect(
      plan(<Asset>[assetWith(id: 1, warrantyEnd: DateTime(2025, 1, 1))]),
      isEmpty,
    );
  });

  test('a shorter lead time moves the warning, it does not add one', () {
    final month = plan(<Asset>[
      assetWith(id: 1, warrantyEnd: DateTime(2026, 12, 1)),
    ]);
    final week = plan(<Asset>[
      assetWith(id: 1, warrantyEnd: DateTime(2026, 12, 1)),
    ], leadDays: 7);

    expect(week, hasLength(1));
    expect(week.single.at.isAfter(month.single.at), isTrue);
  });

  test('one asset gets one reminder, however often this runs', () {
    // The id is the asset's, so rescheduling replaces the warning rather than
    // stacking a second one beside it. A counter here would have filled the
    // phone with the same warranty once per sync.
    final asset = assetWith(id: 42, warrantyEnd: DateTime(2026, 12, 1));

    final first = plan(<Asset>[asset]);
    final second = plan(<Asset>[asset]);

    expect(first.single.id, 42);
    expect(second.single.id, first.single.id);
  });

  test('the cap keeps the urgent end, not whichever page Odoo returned', () {
    // The OS drops the overflow silently, so which ones survive is decided
    // here rather than by the order of a search_read.
    final assets = <Asset>[
      for (var i = 0; i < ReminderScheduler.maxReminders + 10; i++)
        assetWith(
          id: 100 + i,
          // Later ids expire sooner, so an unsorted cap would keep the wrong
          // half.
          warrantyEnd: DateTime(2027, 1, 1).subtract(Duration(days: i)),
        ),
    ];

    final reminders = plan(assets);

    expect(reminders, hasLength(ReminderScheduler.maxReminders));
    expect(
      reminders.first.at.isBefore(reminders.last.at),
      isTrue,
      reason: 'soonest first',
    );

    final soonest = assets.last;
    expect(
      reminders.map((r) => r.id),
      contains(soonest.id),
      reason: 'the soonest expiry must survive the cap',
    );
  });

  test('the reminder names the asset, because a phone shows one line', () {
    final reminders = plan(<Asset>[
      assetWith(
        id: 1,
        name: 'ThinkPad X1 Carbon',
        warrantyEnd: DateTime(2026, 12, 1),
      ),
    ]);

    expect(reminders.single.body, contains('ThinkPad X1 Carbon'));
    expect(reminders.single.title, isNotEmpty);
  });
}

String _body(String asset, int days) => '$asset — $days';
