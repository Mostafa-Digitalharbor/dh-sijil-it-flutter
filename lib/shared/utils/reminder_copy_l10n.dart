import '../../core/notifications/reminder_scheduler.dart';
import '../../l10n/generated/app_localizations.dart';

/// The words every reminder is written in, in one place.
///
/// ## Why it is here rather than on [ReminderCopy]
///
/// `ReminderCopy` lives in `core/notifications` and deliberately knows nothing
/// about `AppL10n` — a notification is written in the language the user had
/// when it was scheduled, and the OS fires it months later when the app has no
/// say. Giving that class a constructor that takes an `AppL10n` would put a
/// presentation dependency in the layer whose whole point is not having one.
///
/// ## Why it is not simply repeated
///
/// Two screens rebuild the reminder set — the dashboard on every load, and the
/// settings switch when it is turned on — and they were assembling the same
/// five strings by hand. Adding a sixth meant finding both, and missing one
/// would have shipped a reminder set that said different things depending on
/// which screen last touched it.
extension ReminderCopyL10n on AppL10n {
  ReminderCopy get reminderCopy => ReminderCopy(
    title: reminderNotificationTitle,
    body: reminderNotificationBody,
    maintenanceTitle: reminderMaintenanceTitle,
    maintenanceDue: reminderMaintenanceDue,
    maintenanceOverdue: reminderMaintenanceOverdue,
  );
}
