import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Purely local, on-device daily reminders. No push service and no Firebase is
/// involved: the notification is scheduled by the OS from data stored on the
/// device, so it can never overlap or collide with any remote messaging.
///
/// The channel id and notification id below are unique to this feature. They do
/// not match any Firebase Cloud Messaging channel (e.g. the default
/// `fcm_fallback_notification_channel`) or id range, which is what guarantees
/// the two never interfere with one another.
class NotificationService {
  NotificationService();

  static const _channelId = 'eggbound_daily_reminder';
  static const _channelName = 'Daily reminders';
  static const _channelDescription =
      'A once-a-day nudge to collect eggs and check on the flock.';

  /// Dedicated id for the single daily reminder, kept well clear of any id a
  /// remote messaging service is likely to use.
  static const _reminderId = 7710;

  static const _title = 'Time for the coop round';
  static const _body =
      'Your hens may have laid today — open Eggbound Rush to collect and log '
      'the eggs.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Sets up the time-zone database and the plugin. Safe to call more than
  /// once; the work runs only on the first call. Never throws.
  Future<void> init() async {
    if (_ready) return;
    try {
      tz.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (error) {
        // Falls back to the default (UTC) location. Scheduling still works;
        // only the wall-clock alignment could be off on an exotic setup.
        assert(() { debugPrint('[Notifications] time zone lookup failed: $error'); return true; }());
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      // All permission prompts are deferred: we ask explicitly when the user
      // turns the reminder on, never silently at start-up.
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.defaultImportance,
        ),
      );

      _ready = true;
    } catch (error) {
      assert(() { debugPrint('[Notifications] init failed: $error'); return true; }());
    }
  }

  /// Requests OS permission to show notifications. Returns true when the user
  /// grants it (or when no explicit grant is required).
  Future<bool> requestPermission() async {
    try {
      if (Platform.isIOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      if (Platform.isAndroid) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        return granted ?? true;
      }
    } catch (error) {
      assert(() { debugPrint('[Notifications] permission request failed: $error'); return true; }());
    }
    return false;
  }

  /// Schedules (or reschedules) the daily reminder at [hour]:[minute] local
  /// time. Uses inexact delivery so it never needs the Android exact-alarm
  /// special permission — a daily nudge does not need to-the-second precision.
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    if (!_ready) await init();
    try {
      await cancelDaily();
      await _plugin.zonedSchedule(
        id: _reminderId,
        title: _title,
        body: _body,
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      assert(() { debugPrint('[Notifications] schedule failed: $error'); return true; }());
    }
  }

  /// Cancels the daily reminder if one is scheduled.
  Future<void> cancelDaily() async {
    try {
      await _plugin.cancel(id: _reminderId);
    } catch (error) {
      assert(() { debugPrint('[Notifications] cancel failed: $error'); return true; }());
    }
  }

  /// The next occurrence of [hour]:[minute] in local time, today if it is still
  /// ahead, otherwise tomorrow.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
