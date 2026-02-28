import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import '../models/masjid.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Default timings: adhan = 0 (off), iqamah = 10 min.
  static const int defaultAdhanTiming = 0;
  static const int defaultIqamahTiming = 10;
  static const int defaultJumuahTiming = 10;

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

  // ── Per-prayer dual pref helpers ──

  static String _adhanKey(String prayerName) => 'notify_adhan_$prayerName';
  static String _iqamahKey(String prayerName) => 'notify_iqamah_$prayerName';
  static String _jumuahKey() => 'notify_jumuah';

  /// Get timing for a specific key (e.g. 'adhan_fajr', 'iqamah_fajr', 'jumuah').
  static Future<int> getTimingForKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'jumuah') {
      return prefs.getInt(_jumuahKey()) ?? defaultJumuahTiming;
    }
    // key format: "adhan_fajr" or "iqamah_fajr"
    final prefKey = 'notify_$key';
    final isAdhan = key.startsWith('adhan_');
    return prefs.getInt(prefKey) ?? (isAdhan ? defaultAdhanTiming : defaultIqamahTiming);
  }

  /// Set timing for a specific key.
  static Future<void> setTimingForKey(String key, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'jumuah') {
      await prefs.setInt(_jumuahKey(), minutes);
    } else {
      await prefs.setInt('notify_$key', minutes);
    }
  }

  /// Load all timings as a map with dual keys.
  static Future<Map<String, int>> getAllTimings() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateToDualKeys(prefs);
    final map = <String, int>{};
    for (final p in Prayer.mainPrayers) {
      map['adhan_${p.name}'] = prefs.getInt(_adhanKey(p.name)) ?? defaultAdhanTiming;
      map['iqamah_${p.name}'] = prefs.getInt(_iqamahKey(p.name)) ?? defaultIqamahTiming;
    }
    map['jumuah'] = prefs.getInt(_jumuahKey()) ?? defaultJumuahTiming;
    return map;
  }

  // ── Migration ──

  static Future<void> _migrateToDualKeys(SharedPreferences prefs) async {
    if (prefs.getBool('_notify_dual_migrated') == true) return;

    // First ensure old migration ran
    await _migrateFromLegacy(prefs);

    // Migrate from single-timing keys (notify_timing_fajr) to dual keys
    for (final p in Prayer.mainPrayers) {
      final oldKey = 'notify_timing_${p.name}';
      final oldVal = prefs.getInt(oldKey);
      if (oldVal != null) {
        if (oldVal > 0) {
          // Old single timing → put on iqamah, adhan off
          await prefs.setInt(_iqamahKey(p.name), oldVal);
          await prefs.setInt(_adhanKey(p.name), 0);
        } else {
          await prefs.setInt(_iqamahKey(p.name), 0);
          await prefs.setInt(_adhanKey(p.name), 0);
        }
        await prefs.remove(oldKey);
      } else {
        // No old key → set defaults if not already set
        if (!prefs.containsKey(_adhanKey(p.name))) {
          await prefs.setInt(_adhanKey(p.name), defaultAdhanTiming);
        }
        if (!prefs.containsKey(_iqamahKey(p.name))) {
          await prefs.setInt(_iqamahKey(p.name), defaultIqamahTiming);
        }
      }
    }

    // Jumuah: migrate from old key
    final oldJumuah = prefs.getInt('notify_timing_jumuah');
    if (oldJumuah != null) {
      await prefs.setInt(_jumuahKey(), oldJumuah);
      await prefs.remove('notify_timing_jumuah');
    } else if (!prefs.containsKey(_jumuahKey())) {
      await prefs.setInt(_jumuahKey(), defaultJumuahTiming);
    }

    await prefs.setBool('_notify_dual_migrated', true);
  }

  /// Legacy migration from even older global keys.
  static Future<void> _migrateFromLegacy(SharedPreferences prefs) async {
    if (prefs.getBool('_notify_timing_migrated') == true) return;

    final enabled = prefs.getBool('notifications_enabled') ?? false;
    final athanOn = prefs.getBool('notify_before_athan') ?? true;
    final iqamahOn = prefs.getBool('notify_before_iqamah') ?? false;
    var athanMin = prefs.getInt('athan_minutes_before') ?? 0;
    final iqamahMin = prefs.getInt('iqamah_minutes_before') ?? 0;

    if (prefs.containsKey('notify_minutes_before')) {
      final old = prefs.getInt('notify_minutes_before') ?? 0;
      if (athanMin == 0) athanMin = old;
      await prefs.remove('notify_minutes_before');
    }

    for (final p in Prayer.mainPrayers) {
      final prayerOn = prefs.getBool('notify_${p.name}') ?? true;

      int timing;
      if (!enabled || !prayerOn) {
        timing = 0;
      } else if (iqamahOn && iqamahMin > 0) {
        timing = iqamahMin;
      } else if (athanOn && athanMin > 0) {
        timing = athanMin;
      } else if (athanOn || iqamahOn) {
        timing = defaultIqamahTiming;
      } else {
        timing = 0;
      }
      await prefs.setInt('notify_timing_${p.name}', timing);
    }

    if (!prefs.containsKey('notify_timing_jumuah')) {
      await prefs.setInt('notify_timing_jumuah', defaultJumuahTiming);
    }

    for (final key in [
      'notify_before_athan',
      'notify_before_iqamah',
      'athan_minutes_before',
      'iqamah_minutes_before',
    ]) {
      await prefs.remove(key);
    }
    for (final p in Prayer.mainPrayers) {
      await prefs.remove('notify_${p.name}');
    }

    await prefs.setBool('_notify_timing_migrated', true);
  }

  // ── Scheduling ──

  static Future<void> schedulePrayerNotifications(
    List<PrayerTime> prayerTimes, {
    JumuahTimes? jumuah,
  }) async {
    await _plugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    await _migrateToDualKeys(prefs);

    final enabled = prefs.getBool('notifications_enabled') ?? false;
    if (!enabled) return;

    final now = DateTime.now();

    for (final pt in prayerTimes) {
      if (pt.prayer == Prayer.sunrise || pt.prayer == Prayer.sunset) continue;

      // Schedule adhan notification
      final adhanTiming = prefs.getInt(_adhanKey(pt.prayer.name)) ?? defaultAdhanTiming;
      if (adhanTiming > 0 && pt.athanDate != null && pt.athanDate!.isAfter(now)) {
        final notifyAt = pt.athanDate!.subtract(Duration(minutes: adhanTiming));
        if (notifyAt.isAfter(now)) {
          await _scheduleOne(
            id: pt.prayer.index * 10,
            title: '${pt.prayer.displayName} (${pt.prayer.arabicName})',
            body: '$adhanTiming min until ${pt.prayer.displayName} adhan',
            dateTime: notifyAt,
          );
        }
      }

      // Schedule iqamah notification
      final iqamahTiming = prefs.getInt(_iqamahKey(pt.prayer.name)) ?? defaultIqamahTiming;
      if (iqamahTiming > 0) {
        final iqamahDate = pt.iqamahDate ?? pt.athanDate;
        if (iqamahDate != null && iqamahDate.isAfter(now)) {
          final notifyAt = iqamahDate.subtract(Duration(minutes: iqamahTiming));
          if (notifyAt.isAfter(now)) {
            await _scheduleOne(
              id: pt.prayer.index * 10 + 1,
              title: '${pt.prayer.displayName} (${pt.prayer.arabicName})',
              body: '$iqamahTiming min until ${pt.prayer.displayName} iqamah',
              dateTime: notifyAt,
            );
          }
        }
      }
    }

    // Jumuah notification
    if (jumuah != null && now.weekday == DateTime.friday) {
      final jumuahTiming = prefs.getInt(_jumuahKey()) ?? defaultJumuahTiming;
      if (jumuahTiming > 0 && jumuah.firstJamaat != null) {
        final jumuahDate = _parseTimeStr(jumuah.firstJamaat);
        if (jumuahDate != null && jumuahDate.isAfter(now)) {
          final notifyAt = jumuahDate.subtract(Duration(minutes: jumuahTiming));
          if (notifyAt.isAfter(now)) {
            await _scheduleOne(
              id: 100,
              title: "Jumu'ah (\u062C\u0645\u0639\u0629)",
              body: "$jumuahTiming min until Jumu'ah",
              dateTime: notifyAt,
            );
          }
        }
      }
    }
  }

  static DateTime? _parseTimeStr(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.substring(0, 5).split(':');
      final now = DateTime.now();
      return DateTime(
          now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
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
