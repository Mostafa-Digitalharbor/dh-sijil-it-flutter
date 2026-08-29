import 'package:flutter/material.dart';

import '../../../../app/di/injector.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/notifications/reminder_scheduler.dart';
import '../../../../core/storage/preferences/app_preferences.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_segmented.dart';

/// The warranty-reminder switch, and how far ahead it fires.
///
/// Stateful and local rather than routed through [SettingsCubit]: turning it
/// on triggers an OS permission prompt whose answer only this widget waits
/// for, and the count it reports comes from the system rather than from the
/// app's own idea of what it scheduled.
class RemindersCard extends StatefulWidget {
  const RemindersCard({super.key});

  @override
  State<RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends State<RemindersCard> {
  late final AppPreferences _preferences = sl<AppPreferences>();
  late bool _enabled = _preferences.remindersEnabled;
  late int _leadDays = _preferences.reminderLeadDays;

  int _scheduled = 0;
  bool _denied = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_enabled) unawaitedCount();
  }

  /// Asks the OS what it is actually holding, so the card reports the truth
  /// rather than what the app last intended.
  Future<void> unawaitedCount() async {
    final count = await sl<NotificationService>().scheduledCount();
    if (mounted) setState(() => _scheduled = count);
  }

  Future<void> _toggle({required bool value, required AppL10n l10n}) async {
    setState(() => _busy = true);

    if (value) {
      final granted = await sl<NotificationService>().requestPermission();
      if (!granted) {
        // The switch stays off, because it would otherwise promise something
        // the OS has already refused to deliver.
        if (mounted) setState(() => (_denied = true, _busy = false));
        return;
      }
    }

    await _preferences.setRemindersEnabled(value: value);
    if (mounted) setState(() => (_enabled = value, _denied = false));
    await _apply(l10n);
  }

  Future<void> _setLead(int days, AppL10n l10n) async {
    setState(() => (_leadDays = days, _busy = true));
    await _preferences.setReminderLeadDays(days);
    await _apply(l10n);
  }

  /// Rebuilds the whole reminder set from what Odoo currently says.
  Future<void> _apply(AppL10n l10n) async {
    final count = await sl<ReminderScheduler>().refresh(
      ReminderCopy(
        title: l10n.reminderNotificationTitle,
        body: l10n.reminderNotificationBody,
      ),
    );
    if (mounted) setState(() => (_scheduled = count, _busy = false));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return SectionCard(
      title: l10n.remindersTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppCheckRow(
            label: l10n.remindersSubtitle,
            value: _enabled,
            onChanged: (value) =>
                _busy ? null : _toggle(value: value, l10n: l10n),
          ),
          if (_denied) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.remindersDenied,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_enabled) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.remindersLeadLabel, style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            AppSegmented<int>(
              value: _leadDays,
              semanticLabel: l10n.remindersLeadLabel,
              onChanged: (days) => _setLead(days, l10n),
              options: <SegmentOption<int>>[
                for (final days in AppPreferences.reminderLeadOptions)
                  SegmentOption<int>(
                    value: days,
                    label: l10n.remindersLeadDays(days),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.remindersScheduled(_scheduled),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
