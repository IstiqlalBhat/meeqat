import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import '../models/masjid.dart';
import 'backend_service.dart';

class PrayerProvider extends ChangeNotifier {
  List<PrayerTime> prayerTimes = [];
  JumuahTimes? jumuah;
  List<Announcement> announcements = [];
  bool isLoading = false;
  String? errorMessage;
  DateTime currentDate = DateTime.now();
  Timer? _timer;

  // Settings
  String backendUrl = 'http://localhost:3000';
  int selectedMasjidId = 0;
  String selectedMasjidName = '';

  PrayerProvider() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentDate = DateTime.now();
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

  PrayerTime? get nextPrayer {
    final now = DateTime.now();
    for (final pt in fivePrayers) {
      final date = pt.athanDate;
      if (date != null && date.isAfter(now)) return pt;
    }
    return null;
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
        // Isha was yesterday conceptually, so add 24h
        return gap + 24 * 3600;
      }
      return gap > 0 ? gap : 6 * 3600;
    }

    return 6 * 3600; // ultimate fallback
  }

  Prayer? get currentPrayer {
    final now = DateTime.now();
    Prayer? current;
    for (final pt in prayerTimes) {
      if (pt.prayer == Prayer.sunrise || pt.prayer == Prayer.sunset) continue;
      final date = pt.athanDate;
      if (date != null && date.isBefore(now)) current = pt.prayer;
    }
    return current;
  }

  bool get isFriday => DateTime.now().weekday == DateTime.friday;

  PrayerTime? get sunrise =>
      prayerTimes.where((p) => p.prayer == Prayer.sunrise).firstOrNull;

  PrayerTime? get sunset =>
      prayerTimes.where((p) => p.prayer == Prayer.sunset).firstOrNull;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    backendUrl = prefs.getString('backendUrl') ?? 'http://localhost:3000';
    selectedMasjidId = prefs.getInt('selectedMasjidId') ?? 0;
    selectedMasjidName = prefs.getString('selectedMasjidName') ?? '';
    notifyListeners();
    await loadTimes();
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
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      prayerTimes = await service.fetchTimes(selectedMasjidId, date: today);
      jumuah = await service.fetchJumuah(selectedMasjidId);
      announcements = await service.fetchAnnouncements(selectedMasjidId);
    } catch (e) {
      errorMessage = 'Unable to fetch prayer times';
    }

    isLoading = false;
    notifyListeners();
  }
}
