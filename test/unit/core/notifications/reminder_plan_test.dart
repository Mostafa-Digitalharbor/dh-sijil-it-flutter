import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/notifications/notification_service.dart';
import 'package:sijil_it/core/notifications/reminder_scheduler.dart';
import 'package:sijil_it/features/assets/domain/entities/asset.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_status.dart';
import 'package:sijil_it/features/assets/domain/entities/warranty.dart';
import 'package:sijil_it/features/maintenance/domain/entities/maintenance_request.dart';

/// What gets a notification, when, and what does not.
///
/// The scheduling itself needs a device; the decisions do not, and the
/// decisions are where this can go wrong — an alarm for a date that has
/// already passed, two warnings for one asset, or a phone full of a hundred
/// notifications nobody will read.
void main() {
  final now = DateTime(2026, 8, 29, 8);

  const copy = ReminderCopy(
    title: 'A warranty is running out',
    body: _body,
    maintenanceTitle: 'Maintenance due',
    maintenanceDue: _maintenanceDue,
    maintenanceOverdue: _maintenanceOverdue,
  );

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

  _maintenanceGroup();
}

/// Repairs, which are the other half of the same idea and behave differently
/// at the far end of it.
///
/// A warranty is a deadline you want warning *before*, and `plan` drops one
/// whose date has gone — an alarm for something that already happened is
/// noise. A booked repair whose date has gone is the opposite: it is still
/// open, somebody is still waiting for the device back, and nothing else in
/// the product goes and says so.
void _maintenanceGroup() {
  final now = DateTime(2026, 8, 29, 8);

  const copy = ReminderCopy(
    title: 'A warranty is running out',
    body: _body,
    maintenanceTitle: 'Maintenance due',
    maintenanceDue: _maintenanceDue,
    maintenanceOverdue: _maintenanceOverdue,
  );

  MaintenanceRequest requestWith({
    required int id,
    DateTime? scheduledFor,
    bool isDone = false,
    String name = 'Screen flicker',
  }) => MaintenanceRequest(
    id: id,
    name: name,
    priority: MaintenancePriority.low,
    scheduledFor: scheduledFor,
    isDone: isDone,
  );

  List<ScheduledReminder> plan(List<MaintenanceRequest> requests) =>
      ReminderScheduler.planMaintenance(requests, copy, now: now);

  group('maintenance reminders', () {
    test('a repair booked for a future day fires on the morning of it', () {
      final reminders = plan(<MaintenanceRequest>[
        requestWith(id: 7, scheduledFor: DateTime(2026, 9, 3)),
      ]);

      expect(reminders, hasLength(1));
      expect(
        reminders.single.at,
        DateTime(2026, 9, 3, ReminderScheduler.hourOfDay),
        reason:
            'no lead time — a repair booked for Thursday is told on '
            'Thursday, unlike a renewal that needs a month to arrange',
      );
      expect(reminders.single.body, contains('today'));
    });

    test('an overdue repair fires at the next morning, not never', () {
      final reminders = plan(<MaintenanceRequest>[
        requestWith(id: 7, scheduledFor: DateTime(2026, 8, 25)),
      ]);

      expect(reminders, hasLength(1));
      expect(
        reminders.single.at,
        DateTime(2026, 8, 29, ReminderScheduler.hourOfDay),
        reason: 'the request is still open and somebody is still waiting',
      );
    });

    test('and says how late it is', () {
      final reminders = plan(<MaintenanceRequest>[
        requestWith(id: 7, scheduledFor: DateTime(2026, 8, 25)),
      ]);

      expect(reminders.single.body, contains('4 late'));
    });

    test('a repair booked for later today still fires today', () {
      // `now` is 08:00 and the reminder hour is 09:00.
      final reminders = plan(<MaintenanceRequest>[
        requestWith(id: 7, scheduledFor: DateTime(2026, 8, 29)),
      ]);

      expect(
        reminders.single.at,
        DateTime(2026, 8, 29, ReminderScheduler.hourOfDay),
      );
    });

    test('a closed request is never late, however old', () {
      final reminders = plan(<MaintenanceRequest>[
        requestWith(id: 7, scheduledFor: DateTime(2020, 1, 1), isDone: true),
      ]);

      expect(
        reminders,
        isEmpty,
        reason: 'work that is finished cannot be waiting on anybody',
      );
    });

    test('a request with no date is not a deadline', () {
      final reminders = plan(<MaintenanceRequest>[requestWith(id: 7)]);

      expect(reminders, isEmpty);
    });

    test('the most overdue survive the cap', () {
      final reminders = plan(<MaintenanceRequest>[
        for (var i = 0; i < ReminderScheduler.maxReminders + 10; i++)
          requestWith(
            id: i,
            // i = 0 is the latest; the tail is barely late.
            scheduledFor: DateTime(
              2026,
              8,
              29,
            ).subtract(Duration(days: ReminderScheduler.maxReminders + 10 - i)),
          ),
      ]);

      expect(reminders, hasLength(ReminderScheduler.maxReminders));
      expect(
        reminders.first.body,
        contains('${ReminderScheduler.maxReminders + 10} late'),
        reason: 'the cap keeps the repairs somebody is already chasing',
      );
    });

    test('ids cannot collide with a warranty reminder for the same id', () {
      // Both sets go into one flat notification namespace, and an asset and a
      // request sharing an Odoo id would otherwise cancel each other out.
      final maintenance = plan(<MaintenanceRequest>[
        requestWith(id: 42, scheduledFor: DateTime(2026, 9, 3)),
      ]);

      expect(maintenance.single.id, isNot(42));
      expect(maintenance.single.id, ReminderScheduler.maintenanceIdOffset + 42);
    });

    test('the same request twice replaces rather than stacks', () {
      final first = plan(<MaintenanceRequest>[
        requestWith(id: 7, scheduledFor: DateTime(2026, 9, 3)),
      ]);
      final second = plan(<MaintenanceRequest>[
        requestWith(id: 7, scheduledFor: DateTime(2026, 9, 4)),
      ]);

      expect(first.single.id, second.single.id);
    });
  });
}

String _body(String asset, int days) => '$asset — $days';

String _maintenanceDue(String request) => '$request today';

String _maintenanceOverdue(String request, int days) => '$request — $days late';
