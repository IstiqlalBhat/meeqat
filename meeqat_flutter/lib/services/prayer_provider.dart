import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import '../models/masjid.dart';
import 'backend_service.dart';
import 'notification_service.dart';
import 'ramadan_service.dart';

class PrayerProvider extends ChangeNotifier {
  List<PrayerTime> prayerTimes = [];
  List<PrayerTime> tomorrowPrayerTimes = [];
  JumuahTimes? jumuah;
  List<Announcement> announcements = [];
  bool isLoading = false;
  String? errorMessage;
  DateTime currentDate = DateTime.now();
  DateTime selectedDate = DateTime.now();
  Timer? _timer;

  // Settings
  String backendUrl = 'https://meeqatmain.vercel.app';
  int selectedMasjidId = 0;
  String selectedMasjidName = '';

  // Notification state
  bool notificationsEnabled = false;
  Map<String, int> notificationTimings = {};

  // Ramadan state
  bool ramadanTilesEnabled = true;
  String ramadanTileSize = 'small';

  // Offline download state
  bool isDownloading = false;
  String? downloadError;
  int? lastDownloadStored;
  Map<String, dynamic>? lastBulkMeta;

  bool get isViewingToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  PrayerProvider() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      // Midnight rollover: if viewing today and the day changed, update and reload
      if (isViewingToday && currentDate.day != now.day) {
        selectedDate = now;
        currentDate = now;
        notifyListeners();
        loadTimes();
        return;
      }
      currentDate = now;
      notifyListeners();
    });
    _loadSettings();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get hasMasjid => selectedMasjidId > 0;

  List<PrayerTime> get fivePrayers =>
      prayerTimes.where((p) => p.prayer.hasIqamah).toList();

  PrayerTime? get tomorrowFajr =>
      tomorrowPrayerTimes.where((p) => p.prayer == Prayer.fajr).firstOrNull;

  PrayerTime? get nextPrayer {
    if (!isViewingToday) return null;
    final now = DateTime.now();
    for (final pt in fivePrayers) {
      final date = pt.athanDate;
      if (date != null && date.isAfter(now)) return pt;
    }
    // All today's prayers passed — show tomorrow's Fajr
    return tomorrowFajr;
  }

  bool get isNextPrayerTomorrow {
    if (!isViewingToday) return false;
    final now = DateTime.now();
    for (final pt in fivePrayers) {
      final date = pt.athanDate;
      if (date != null && date.isAfter(now)) return false;
    }
    return tomorrowFajr != null;
  }

  Duration? get timeToNextPrayer {
    final next = nextPrayer;
    if (next == null) return null;
    final target = next.athanDate;
    if (target == null) return null;
    return target.difference(currentDate);
  }

  /// Total gap (in seconds) between the previous prayer and the next prayer.
  /// Used to compute accurate countdown ring progress.
  int get gapToNextPrayer {
    final next = nextPrayer;
    if (next == null) return 6 * 3600; // fallback
    final nextDate = next.athanDate;
    if (nextDate == null) return 6 * 3600;

    // Tomorrow's Fajr — gap is from today's Isha to tomorrow's Fajr
    if (isNextPrayerTomorrow) {
      final fiveList = fivePrayers;
      if (fiveList.isNotEmpty && fiveList.last.athanDate != null) {
        return nextDate.difference(fiveList.last.athanDate!).inSeconds.abs();
      }
      return 6 * 3600;
    }

    final fiveList = fivePrayers;
    final idx = fiveList.indexOf(next);

    if (idx > 0) {
      final prevDate = fiveList[idx - 1].athanDate;
      if (prevDate != null) {
        return nextDate.difference(prevDate).inSeconds;
      }
    }

    // Fajr is next — estimate gap from Isha to Fajr (wrapping midnight)
    if (fiveList.isNotEmpty && fiveList.last.athanDate != null) {
      final ishaDate = fiveList.last.athanDate!;
      final gap = nextDate.difference(ishaDate).inSeconds;
      if (gap < 0) {
        return gap + 24 * 3600;
      }
      return gap > 0 ? gap : 6 * 3600;
    }

    return 6 * 3600; // ultimate fallback
  }

  Prayer? get currentPrayer {
    if (!isViewingToday) return null;
    final now = DateTime.now();
    Prayer? current;
    for (final pt in prayerTimes) {
      if (pt.prayer == Prayer.sunrise || pt.prayer == Prayer.sunset) continue;
      final date = pt.athanDate;
      if (date != null && date.isBefore(now)) current = pt.prayer;
    }
    return current;
  }

  bool get isFriday => selectedDate.weekday == DateTime.friday;

  bool get isRamadan => RamadanService.isRamadan();
  int? get ramadanDay => RamadanService.ramadanDay();

  PrayerTime? get sunrise =>
      prayerTimes.where((p) => p.prayer == Prayer.sunrise).firstOrNull;

  PrayerTime? get sunset =>
      prayerTimes.where((p) => p.prayer == Prayer.sunset).firstOrNull;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    backendUrl = prefs.getString('backendUrl') ?? 'https://meeqatmain.vercel.app';
    selectedMasjidId = prefs.getInt('selectedMasjidId') ?? 0;
    selectedMasjidName = prefs.getString('selectedMasjidName') ?? '';
    ramadanTilesEnabled = prefs.getBool('ramadan_tiles_enabled') ?? true;
    ramadanTileSize = prefs.getString('ramadan_tile_size') ?? 'small';
    notifyListeners();
    await loadTimes();
    await _loadNotificationTimings();
    await loadBulkMeta();
  }

  // ── Notification helpers ──

  Future<void> _loadNotificationTimings() async {
    final prefs = await SharedPreferences.getInstance();
    notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
    notificationTimings = await NotificationService.getAllTimings();
    notifyListeners();
  }

  int getNotificationTiming(String key) {
    if (key == 'jumuah') {
      return notificationTimings[key] ?? NotificationService.defaultJumuahTiming;
    }
    if (key == 'ramadan_sehri') {
      return notificationTimings[key] ?? NotificationService.defaultSehriTiming;
    }
    if (key == 'ramadan_iftar') {
      return notificationTimings[key] ?? NotificationService.defaultIftarTiming;
    }
    final isAdhan = key.startsWith('adhan_');
    return notificationTimings[key] ??
        (isAdhan ? NotificationService.defaultAdhanTiming : NotificationService.defaultIqamahTiming);
  }

  Future<void> setNotificationTiming(String key, int minutes) async {
    await NotificationService.setTimingForKey(key, minutes);
    notificationTimings[key] = minutes;
    notifyListeners();
    NotificationService.schedulePrayerNotifications(prayerTimes, jumuah: jumuah);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    notificationsEnabled = value;
    notifyListeners();
    if (value) {
      NotificationService.schedulePrayerNotifications(prayerTimes, jumuah: jumuah);
    } else {
      await NotificationService.cancelAll();
    }
  }

  Future<void> setRamadanTilesEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ramadan_tiles_enabled', value);
    ramadanTilesEnabled = value;
    notifyListeners();
  }

  Future<void> setRamadanTileSize(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ramadan_tile_size', value);
    ramadanTileSize = value;
    notifyListeners();
  }

  // ── Offline timetable download ──

  Future<void> downloadBulkTimes(int days) async {
    if (!hasMasjid) return;
    isDownloading = true;
    downloadError = null;
    notifyListeners();

    try {
      final service = BackendService(baseUrl: backendUrl);
      final from = DateFormat('yyyy-MM-dd').format(DateTime.now());
      lastDownloadStored = await service.fetchBulkTimes(
        selectedMasjidId,
        fromDate: from,
        days: days,
      );
      lastBulkMeta = await BackendService.getBulkDownloadMeta(selectedMasjidId);
    } catch (e) {
      downloadError = e.toString().replaceFirst('Exception: ', '');
    }

    isDownloading = false;
    notifyListeners();
  }

  Future<void> loadBulkMeta() async {
    if (!hasMasjid) return;
    lastBulkMeta = await BackendService.getBulkDownloadMeta(selectedMasjidId);
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backendUrl', backendUrl);
    await prefs.setInt('selectedMasjidId', selectedMasjidId);
    await prefs.setString('selectedMasjidName', selectedMasjidName);
  }

  Future<void> selectMasjid(Masjid masjid) async {
    selectedMasjidId = masjid.id;
    selectedMasjidName = masjid.name;
    await saveSettings();
    notifyListeners();
    await loadTimes();
  }

  Future<void> loadTimes() async {
    if (!hasMasjid) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final service = BackendService(baseUrl: backendUrl);
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      prayerTimes = await service.fetchTimes(selectedMasjidId, date: dateStr);
      jumuah = await service.fetchJumuah(selectedMasjidId);
      announcements = await service.fetchAnnouncements(selectedMasjidId);
      // Fetch tomorrow's times so we can show Fajr countdown after Isha
      if (isViewingToday) {
        final tomorrow = selectedDate.add(const Duration(days: 1));
        final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);
        try {
          tomorrowPrayerTimes = await service.fetchTimes(
            selectedMasjidId, date: tomorrowStr, dayOffset: 1,
          );
        } catch (_) {
          tomorrowPrayerTimes = [];
        }
        NotificationService.schedulePrayerNotifications(prayerTimes, jumuah: jumuah);
      } else {
        tomorrowPrayerTimes = [];
      }
    } catch (e) {
      errorMessage = 'Unable to fetch prayer times';
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Date navigation ──

  void goToDate(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
    loadTimes();
  }

  void goToNextDay() {
    goToDate(selectedDate.add(const Duration(days: 1)));
  }

  void goToPreviousDay() {
    goToDate(selectedDate.subtract(const Duration(days: 1)));
  }

  void goToToday() {
    final now = DateTime.now();
    goToDate(DateTime(now.year, now.month, now.day));
  }
}
