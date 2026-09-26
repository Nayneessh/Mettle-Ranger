import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// "Are you ready to capture the day, RANGER?" — one local notification
/// each morning at 5am in whatever timezone the phone is actually set to
/// (spec-beyond addition, explicit user request). Purely local: no server,
/// no push infrastructure, so it works fully offline like everything else
/// in this app (spec §11) and needs no backend to fail silently against.
///
/// Uses `AndroidScheduleMode.inexactAllowWhileIdle` rather than an exact
/// alarm on purpose: Android 12+ gates exact alarms behind a separate
/// permission the user has to grant by hand in system settings, and a
/// wake-up reminder has no real need for the to-the-second precision a
/// round timer does. The trade is a delivery window of a few minutes, not
/// a missed morning — and no extra permission prompt beyond the ordinary
/// notification one.
///
/// **Caveat, stated plainly rather than overclaimed**: this has the same
/// status as the rest of the capture pipeline — code-complete, never run
/// on a real device. Some Android OEMs (Xiaomi, Samsung and others) apply
/// their own battery-optimization killers on top of what stock Android
/// allows, which can silently suppress a scheduled notification regardless
/// of what this class does correctly. There is no code-level fix for that
/// from inside the app.
class DailyReminderService {
  DailyReminderService._();

  static final DailyReminderService instance = DailyReminderService._();

  static const _notificationId = 5001;
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily training reminder';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimeZone));
    } catch (_) {
      // Falls back to tz.local's own default (UTC) — the reminder still
      // fires daily, just not necessarily at 5am *local* time on a device
      // this lookup fails on.
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  /// Android 13+ gates notifications behind a runtime permission, same
  /// family as camera/microphone. Returns false without throwing if denied
  /// — the app has no core feature riding on this, per spec §11.
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;
    return await androidPlugin.requestNotificationsPermission() ?? false;
  }

  /// Schedules (or re-schedules) the 5am reminder. Idempotent — each call
  /// replaces the same notification id, so it is safe to call on every
  /// app start to pick up a changed device timezone.
  Future<void> scheduleDaily5am() async {
    await _plugin.zonedSchedule(
      _notificationId,
      'Are you ready to capture the day, RANGER?',
      "Log today's training whenever you step on the mat.",
      _next5am(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'One reminder each morning to log training.',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      // iOS-only legacy parameter the plugin's API still requires even on
      // an Android-only build; absoluteTime is its documented modern
      // default.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel() => _plugin.cancel(_notificationId);

  tz.TZDateTime _next5am() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 5);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
