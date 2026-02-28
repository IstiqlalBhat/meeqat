import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final result = await android.requestNotificationsPermission();
      return result ?? false;
    }
    return true;
  }

  static Future<void> schedulePrayerNotifications(List<PrayerTime> prayerTimes) async {
    await _plugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? false;
    if (!enabled) return;

    final now = DateTime.now();
    final minutesBefore = prefs.getInt('notify_minutes_before') ?? 0;

    for (final pt in prayerTimes) {
      if (pt.prayer == Prayer.sunrise || pt.prayer == Prayer.sunset) continue;

      final key = 'notify_${pt.prayer.name}';
      final prayerEnabled = prefs.getBool(key) ?? true;
      if (!prayerEnabled) continue;

      final athanDate = pt.athanDate;
      if (athanDate == null || athanDate.isBefore(now)) continue;

      final notifyAt = athanDate.subtract(Duration(minutes: minutesBefore));
      if (notifyAt.isBefore(now)) continue;

      await _scheduleOne(
        id: pt.prayer.index * 10,
        title: '${pt.prayer.displayName} (${pt.prayer.arabicName})',
        body: minutesBefore > 0
            ? '${pt.prayer.displayName} in $minutesBefore minutes'
            : 'Time for ${pt.prayer.displayName} prayer',
        dateTime: notifyAt,
      );
    }
  }

  static Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final tzDateTime = tz.TZDateTime.from(dateTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_times',
          'Prayer Times',
          channelDescription: 'Notifications for prayer times',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
