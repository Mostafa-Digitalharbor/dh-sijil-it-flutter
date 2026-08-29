import '../../features/assets/domain/entities/asset.dart';
import '../../features/assets/domain/entities/asset_query.dart';
import '../../features/assets/domain/entities/warranty.dart';
import '../../features/assets/domain/repositories/asset_repository.dart';
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
  const ReminderCopy({required this.title, required this.body});

  final String title;

  /// Takes the asset name and the number of days left.
  final String Function(String asset, int days) body;
}

/// Turns warranties into notifications the OS will fire on its own.
///
/// The dashboard has always known that eight warranties expire this month. The
/// only way anybody found out was by opening the app and looking at it, which
/// is precisely backwards for a date that matters *because* it is approaching.
class ReminderScheduler {
  ReminderScheduler({
    required AssetRepository assets,
    required NotificationService notifications,
    required AppPreferences preferences,
  }) : _assets = assets,
       _notifications = notifications,
       _preferences = preferences;

  final AssetRepository _assets;
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

    return result.fold(
      // Nothing is cancelled on a failed read: a phone that lost signal must
      // not also lose the warnings it was already holding.
      (failure) async {
        AppLogger.warn('Reminder refresh skipped — ${failure.kind.name}');
        return 0;
      },
      (page) async {
        final reminders = plan(page.items, copy, _preferences.reminderLeadDays);
        await _notifications.reschedule(reminders);
        return reminders.length;
      },
    );
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
}
