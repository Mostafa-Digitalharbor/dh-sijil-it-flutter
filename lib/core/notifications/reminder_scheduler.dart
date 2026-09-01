import '../../features/assets/domain/entities/asset.dart';
import '../../features/assets/domain/entities/asset_query.dart';
import '../../features/assets/domain/entities/warranty.dart';
import '../../features/assets/domain/repositories/asset_repository.dart';
import '../../features/maintenance/domain/entities/maintenance_request.dart';
import '../../features/maintenance/domain/repositories/maintenance_repository.dart';
import '../pagination/page_request.dart';
import '../storage/preferences/app_preferences.dart';
import '../utils/logger.dart';
import 'notification_service.dart';

/// The words a reminder is written in, resolved by the screen that asks for
/// one.
///
/// Passed in rather than looked up here for the same reason `FailurePresenter`
/// takes an `AppL10n`: this layer has no `BuildContext`, and a notification is
/// written in the language the user was using when it was scheduled — the OS
/// fires it months later, long after the app has any say.
class ReminderCopy {
  const ReminderCopy({
    required this.title,
    required this.body,
    required this.maintenanceTitle,
    required this.maintenanceDue,
    required this.maintenanceOverdue,
  });

  final String title;

  /// Takes the asset name and the number of days left.
  final String Function(String asset, int days) body;

  final String maintenanceTitle;

  /// A repair booked for today. Takes the request's subject.
  final String Function(String request) maintenanceDue;

  /// A repair whose date has passed. Takes the subject and how many days late.
  final String Function(String request, int days) maintenanceOverdue;
}

/// Turns warranties into notifications the OS will fire on its own.
///
/// The dashboard has always known that eight warranties expire this month. The
/// only way anybody found out was by opening the app and looking at it, which
/// is precisely backwards for a date that matters *because* it is approaching.
class ReminderScheduler {
  ReminderScheduler({
    required AssetRepository assets,
    required MaintenanceRepository maintenance,
    required NotificationService notifications,
    required AppPreferences preferences,
  }) : _assets = assets,
       _maintenance = maintenance,
       _notifications = notifications,
       _preferences = preferences;

  final AssetRepository _assets;
  final MaintenanceRepository _maintenance;
  final NotificationService _notifications;
  final AppPreferences _preferences;

  /// How many assets are worth warning about.
  ///
  /// A cap, because the OS has its own limit on scheduled notifications (64
  /// on iOS) and silently drops the overflow. Twenty of the most urgent is a
  /// list somebody can act on; two hundred is a phone nobody will unlock.
  static const int maxReminders = 20;

  /// The hour a reminder fires, local time.
  ///
  /// Morning rather than "now plus a window": the action it prompts — raising
  /// a renewal, calling a vendor — is a working-day action.
  static const int hourOfDay = 9;

  /// Rebuilds the whole reminder set from what Odoo currently says.
  ///
  /// Cheap enough to call on every dashboard load: one page read, and the
  /// scheduling itself is local. Doing it there rather than on a timer is what
  /// keeps a reminder from outliving the warranty it is about.
  Future<int> refresh(ReminderCopy copy) async {
    if (!_preferences.remindersEnabled) {
      await _notifications.cancelAll();
      return 0;
    }

    final result = await _assets.getAssets(
      const AssetQuery(
        filters: AssetFilters(
          warrantyStates: <WarrantyState>{
            WarrantyState.expiringCritical,
            WarrantyState.expiringSoon,
          },
        ),
        page: PageRequest(limit: 100),
      ),
    );

    final warranties = result.fold(
      // Nothing is cancelled on a failed read: a phone that lost signal must
      // not also lose the warnings it was already holding.
      (failure) {
        AppLogger.warn('Reminder refresh skipped — ${failure.kind.name}');
        return null;
      },
      (page) => plan(page.items, copy, _preferences.reminderLeadDays),
    );

    if (warranties == null) return 0;

    final reminders = <ScheduledReminder>[
      ...warranties,
      ...await _maintenanceReminders(copy),
    ];

    await _notifications.reschedule(reminders);
    return reminders.length;
  }

  /// The repair side of the same idea.
  ///
  /// Read separately and tolerated separately: Maintenance is an optional Odoo
  /// app, so an instance without it answers with a `modelUnavailable` failure
  /// that must cost the warranty reminders nothing.
  Future<List<ScheduledReminder>> _maintenanceReminders(
    ReminderCopy copy,
  ) async {
    final result = await _maintenance.getRequests(
      // Open only. A closed request cannot be late, however old its date.
      filters: const MaintenanceFilters(),
      page: const PageRequest(limit: 100),
    );

    return result.fold((failure) {
      AppLogger.warn('Maintenance reminders skipped — ${failure.kind.name}');
      return const <ScheduledReminder>[];
    }, (page) => planMaintenance(page.items, copy));
  }

  /// Which reminders a set of assets deserves.
  ///
  /// Pure and static so the decisions — how far ahead, how many, what happens
  /// to an already-expired warranty — are testable without a plugin, a
  /// timezone database or a device.
  static List<ScheduledReminder> plan(
    List<Asset> assets,
    ReminderCopy copy,
    int leadDays, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    final due = <(Asset, DateTime)>[];
    for (final asset in assets) {
      final end = asset.warranty.endDate;
      if (end == null) continue;

      final fireOn = DateTime(
        end.year,
        end.month,
        end.day,
        hourOfDay,
      ).subtract(Duration(days: leadDays));

      // Already past. The dashboard still counts it; a notification about it
      // would be an alarm for something that has already happened.
      if (!fireOn.isAfter(today)) continue;

      due.add((asset, fireOn));
    }

    // Soonest first, so the cap keeps the urgent end rather than whichever
    // page Odoo happened to return.
    due.sort((a, b) => a.$2.compareTo(b.$2));

    return <ScheduledReminder>[
      for (final (asset, fireOn) in due.take(maxReminders))
        ScheduledReminder(
          // Derived from the asset, so rescheduling replaces the warning for
          // that asset instead of stacking a second one beside it.
          id: asset.id,
          title: copy.title,
          body: copy.body(asset.name, asset.warranty.daysRemaining ?? leadDays),
          at: fireOn,
        ),
    ];
  }

  /// Which repairs are worth a notification.
  ///
  /// ## Why this is not [plan] with a different field
  ///
  /// A warranty is a deadline you want warning *before*; a booked repair is an
  /// appointment, and one whose date has passed is a fact you want telling
  /// about *now*. So the two ends are handled differently:
  ///
  /// * **Still ahead** — fires on the morning of the day itself. No lead time:
  ///   a warranty renewal needs a month's notice to arrange, and a repair
  ///   booked for Thursday needs telling on Thursday.
  /// * **Already past** — fires at the next [hourOfDay]. `plan` deliberately
  ///   drops warranties whose date has gone, because an alarm for something
  ///   that has already happened is noise. An overdue repair is the opposite:
  ///   it is *still open*, somebody is still waiting for the device back, and
  ///   nothing else in the product goes and says so.
  ///
  /// The whole set is rebuilt on every dashboard load, so an overdue repair
  /// re-arms for the following morning each time the app is opened, and stops
  /// the moment the request is closed in Odoo.
  static List<ScheduledReminder> planMaintenance(
    List<MaintenanceRequest> requests,
    ReminderCopy copy, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final nextMorning = _nextMorningAfter(today);

    final due = <(MaintenanceRequest, DateTime, int)>[];
    for (final request in requests) {
      final scheduled = request.scheduledFor;
      if (scheduled == null || request.isDone) continue;

      final onTheDay = DateTime(
        scheduled.year,
        scheduled.month,
        scheduled.day,
        hourOfDay,
      );

      if (onTheDay.isAfter(today)) {
        due.add((request, onTheDay, 0));
        continue;
      }

      final lateBy = _wholeDaysBetween(scheduled, today);
      due.add((request, nextMorning, lateBy));
    }

    // Latest-overdue first, then soonest-upcoming: the cap has to keep the
    // repairs somebody is already waiting on rather than next month's.
    due.sort((a, b) {
      if (a.$3 != b.$3) return b.$3.compareTo(a.$3);
      return a.$2.compareTo(b.$2);
    });

    return <ScheduledReminder>[
      for (final (request, fireOn, lateBy) in due.take(maxReminders))
        ScheduledReminder(
          id: _maintenanceIdFor(request.id),
          title: copy.maintenanceTitle,
          body: lateBy > 0
              ? copy.maintenanceOverdue(request.name, lateBy)
              : copy.maintenanceDue(request.name),
          at: fireOn,
        ),
    ];
  }

  /// Notification ids are one flat namespace shared with [plan], so a repair
  /// and an asset that happen to carry the same Odoo id must not cancel each
  /// other out. The offset is far above any id an instance realistically
  /// reaches, and the arithmetic is reversible, which keeps it debuggable.
  static const int maintenanceIdOffset = 1 << 22;

  static int _maintenanceIdFor(int requestId) =>
      maintenanceIdOffset + requestId;

  /// The next [hourOfDay] strictly after [from].
  static DateTime _nextMorningAfter(DateTime from) {
    final todayAt = DateTime(from.year, from.month, from.day, hourOfDay);
    return todayAt.isAfter(from)
        ? todayAt
        : todayAt.add(const Duration(days: 1));
  }

  /// Whole days between two dates, ignoring the time of day.
  ///
  /// Date-only on both sides so a request booked yesterday afternoon reads as
  /// one day late this morning rather than nought.
  static int _wholeDaysBetween(DateTime from, DateTime to) => DateTime(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime(from.year, from.month, from.day)).inDays;
}
