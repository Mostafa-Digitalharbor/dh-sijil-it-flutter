import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/logger.dart';

/// One thing the app wants the user to be told about, on a date.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });

  /// Stable across reschedules, so the same fact does not stack up.
  ///
  /// Derived from the asset id and the window, never from a counter: the whole
  /// set is rebuilt on every sync, and a counter would fire the same warranty
  /// warning once per sync until the phone was full of them.
  final int id;

  final String title;
  final String body;
  final DateTime at;
}

/// Local notifications, and nothing else.
///
/// ## Why there is no push
///
/// Odoo has no push channel this app could subscribe to, and adding a server
/// component is out of scope (spec §2 forbids shipping an addon). What is
/// left is what the OS can do on the app's behalf: a notification handed to
/// the system with a date on it fires whether or not the app ever runs again.
///
/// That constrains what can be notified about. A warranty expiry is a *date
/// the app already knows*, so it schedules perfectly. "A maintenance request
/// was assigned to you" is a change on the server that nothing on the device
/// can learn about while the app is closed, and it is deliberately not
/// pretended at here.
class NotificationService {
  NotificationService(this._plugin);

  factory NotificationService.createDefault() =>
      NotificationService(FlutterLocalNotificationsPlugin());

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  static const String _channelId = 'sijil_reminders';
  static const String _channelName = 'Asset reminders';

  /// Sets up channels and the timezone database.
  ///
  /// Deliberately not called during bootstrap: it asks the OS for a
  /// permission, and a permission prompt on first launch — before the user has
  /// seen what the app is — is the fastest way to have it denied forever.
  Future<bool> initialise() async {
    if (_ready) return true;

    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly below instead, so the prompt is attached to
          // the switch the user just turned on.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(settings: settings);
      _ready = true;
      return true;
    } on Object catch (error, stackTrace) {
      AppLogger.error('Notifications unavailable', error, stackTrace);
      return false;
    }
  }

  /// Asks the OS, at the moment the user turns reminders on.
  Future<bool> requestPermission() async {
    if (!await initialise()) return false;

    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } on Object catch (error) {
      AppLogger.warn('Notification permission request failed — $error');
      return false;
    }
  }

  /// Replaces every scheduled reminder with [reminders].
  ///
  /// Replace rather than add: the source of truth is Odoo, and an asset whose
  /// warranty was extended — or which was scrapped — must not go on warning
  /// about a date that is no longer true. Cancelling everything first is the
  /// only way to be sure a stale one is gone, because the app cannot know
  /// which ids it wrote on a previous install.
  Future<void> reschedule(List<ScheduledReminder> reminders) async {
    if (!await initialise()) return;

    try {
      await _plugin.cancelAll();

      final now = DateTime.now();
      for (final reminder in reminders) {
        // A date in the past cannot be scheduled, and firing it immediately
        // would mean a burst of notifications on every sync.
        if (!reminder.at.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
          notificationDetails: _details,
          // Inexact on purpose: an exact alarm needs a separate, intrusive
          // permission on Android 12+, and "some time that morning" is the
          // right precision for a warranty that expires in a month.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      final scheduled = reminders.where((r) => r.at.isAfter(now)).toList();
      AppLogger.info('Scheduled ${scheduled.map((r) => r.id).join(', ')}');
    } on Object catch (error, stackTrace) {
      // A device that refuses to schedule is not a reason to fail the sync
      // that produced the list.
      AppLogger.error('Could not schedule reminders', error, stackTrace);
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// How many are actually with the OS. Used by the settings screen so the
  /// switch reports the truth rather than what the app last intended.
  Future<int> scheduledCount() async {
    if (!await initialise()) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
