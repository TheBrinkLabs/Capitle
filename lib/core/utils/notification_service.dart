import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../data/models/app_settings.dart';

class NotificationService {
  static const _streakSaverId = 2;
  static const _channelId = 'capitle_channel';
  static const _channelName = 'Capitle';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    // initializeTimeZones() only loads the timezone database — it does
    // NOT set tz.local to the device's actual timezone. Without this,
    // tz.local silently defaults to UTC, throwing every scheduled time
    // off by the device's UTC offset. Detect the real device timezone
    // and set it explicitly.
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
      debugPrint('[Capitle notif] Device timezone detected: ${deviceTimezone.identifier}, '
          'tz.local now = ${tz.local.name}');
    } catch (e) {
      debugPrint('[Capitle notif] Timezone detection FAILED, defaulting to UTC: $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Android 13+ (API 33+) requires an explicit runtime permission
    // request — without this, scheduled notifications are silently
    // never shown. This is also what surfaces the system "Allow
    // notifications?" prompt the first time the app runs.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidImpl?.requestNotificationsPermission();
    debugPrint('[Capitle notif] Notifications permission granted: $granted');

    // NOTE: no requestExactAlarmsPermission() call here, deliberately.
    // The manifest declares USE_EXACT_ALARM (not SCHEDULE_EXACT_ALARM),
    // which Android grants silently at install with no user-facing
    // prompt or settings toggle — same approach expo-notifications uses,
    // which is how Higgins gets reliable exact notifications with zero
    // visible permission friction.
  }

  /// Reschedules the streak-saver alert based on current settings and
  /// today's completion status. Call this:
  /// - on app launch
  /// - immediately after the user finishes their last active puzzle for
  ///   the day, so the alert doesn't fire later that same day
  /// - immediately after the alert time or toggle changes in Settings
  Future<void> scheduleFromSettings(
    AppSettings settings, {
    required bool completedToday,
  }) async {
    await cancelAll();
    if (settings.streakSaverAlert) {
      await _scheduleStreakSaver(settings.streakSaverTime, completedToday);
    }
  }

  Future<void> _scheduleStreakSaver(TimeOfDay time, bool completedToday) async {
    // If today's puzzles are already done, skip straight to tomorrow's
    // occurrence — otherwise the alert would still fire today even though
    // there's nothing left to save. Otherwise, this correctly resolves to
    // later today if the picked time hasn't passed yet, or tomorrow if it
    // has — both handled by _nextInstanceOfTime below.
    final next = _nextInstanceOfTime(time.hour, time.minute, skipToday: completedToday);
    final now = tz.TZDateTime.now(tz.local);
    debugPrint('[Capitle notif] Scheduling for $next (now=$now, tz.local=${tz.local.name}, '
        'completedToday=$completedToday)');

    try {
      await _plugin.zonedSchedule(
        _streakSaverId,
        '🔥 Don\'t break your streak!',
        'You haven\'t played today\'s Capitle yet. Quick — before midnight!',
        next,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            // Small status-bar icon — a clean single-shape silhouette.
            // Android discards all color for this slot and masks purely on
            // alpha, so a busy multi-color icon renders as a blob rather
            // than a shape.
            icon: 'ic_notification',
            // Full-colour app icon for the expanded notification. Points
            // at a DRAWABLE resource, not the mipmap launcher icon —
            // DrawableResourceAndroidBitmap only looks in the drawable
            // resource type, and mipmap is a distinct type Android uses
            // specifically for launcher icons. Needs an actual copy of
            // the icon placed at
            // android/app/src/main/res/drawable/ic_launcher_large.png
            // (see instructions) — a different filename than the mipmap
            // version, to avoid any resource-name collision.
            largeIcon: const DrawableResourceAndroidBitmap('ic_launcher_large'),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // EXACT — final decision after real-world overnight testing showed
        // inexact scheduling unreliable for the actual use case (an 8+ hour
        // overnight gap is exactly when Android's Doze mode is most
        // aggressive). Manifest declares USE_EXACT_ALARM (silently granted,
        // no user prompt) rather than SCHEDULE_EXACT_ALARM.
        // Inexact — required by Google Play policy (exact alarms are
        // restricted to apps whose core function needs exact timing,
        // which flagged in Play Console review). Our earlier "inexact is
        // unreliable overnight" conclusion was very likely a false
        // negative — that test happened while the largeIcon bug was
        // silently crashing zonedSchedule() on every call regardless of
        // scheduling mode (confirmed via logcat), so inexact was never
        // actually given a fair, uncontaminated test. Worth confirming
        // clean now that that bug is fixed.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // When today isn't finished yet: repeat daily at this time, so the
        // alert still fires even on days the app never gets opened.
        // When today IS finished: one-shot for tomorrow only — the app
        // re-arms this correctly the next time it's opened or a puzzle is
        // completed, so the loop continues as long as the app is used.
        matchDateTimeComponents:
            completedToday ? null : DateTimeComponents.time,
      );
      final pending = await _plugin.pendingNotificationRequests();
      final isPending = pending.any((n) => n.id == _streakSaverId);
      debugPrint('[Capitle notif] zonedSchedule call completed OK. '
          'Pending in plugin: $isPending (${pending.length} total pending)');
    } catch (e, st) {
      debugPrint('[Capitle notif] zonedSchedule THREW: $e\n$st');
      rethrow;
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, {bool skipToday = false}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now) || skipToday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final notificationService = NotificationService();
