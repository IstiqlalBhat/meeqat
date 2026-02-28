import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum Prayer {
  fajr,
  sunrise,
  dhuhr,
  asr,
  sunset,
  maghrib,
  isha;

  String get displayName {
    switch (this) {
      case Prayer.fajr: return 'Fajr';
      case Prayer.sunrise: return 'Sunrise';
      case Prayer.dhuhr: return 'Dhuhr';
      case Prayer.asr: return 'Asr';
      case Prayer.sunset: return 'Sunset';
      case Prayer.maghrib: return 'Maghrib';
      case Prayer.isha: return 'Isha';
    }
  }

  String get arabicName {
    switch (this) {
      case Prayer.fajr: return 'فجر';
      case Prayer.sunrise: return 'شروق';
      case Prayer.dhuhr: return 'ظهر';
      case Prayer.asr: return 'عصر';
      case Prayer.sunset: return 'غروب';
      case Prayer.maghrib: return 'مغرب';
      case Prayer.isha: return 'عشاء';
    }
  }

  IconData get icon {
    switch (this) {
      case Prayer.fajr: return Icons.dark_mode_rounded;
      case Prayer.sunrise: return Icons.wb_twilight_rounded;
      case Prayer.dhuhr: return Icons.light_mode_rounded;
      case Prayer.asr: return Icons.wb_sunny_rounded;
      case Prayer.sunset: return Icons.wb_twilight_rounded;
      case Prayer.maghrib: return Icons.nights_stay_rounded;
      case Prayer.isha: return Icons.bedtime_rounded;
    }
  }

  Color get accentLight {
    switch (this) {
      case Prayer.fajr: return const Color(0xFFB5CDD3);
      case Prayer.sunrise: return const Color(0xFFE8C9A0);
      case Prayer.dhuhr: return const Color(0xFFE8C9A0);
      case Prayer.asr: return const Color(0xFFD4A574);
      case Prayer.sunset: return const Color(0xFFE8C9A0);
      case Prayer.maghrib: return const Color(0xFFC4A0D4);
      case Prayer.isha: return const Color(0xFF8EADB5);
    }
  }

  Color get accentDark {
    switch (this) {
      case Prayer.fajr: return const Color(0xFF2E636E);
      case Prayer.sunrise: return const Color(0xFF7B5B2A);
      case Prayer.dhuhr: return const Color(0xFF7B5B2A);
      case Prayer.asr: return const Color(0xFF7B5B2A);
      case Prayer.sunset: return const Color(0xFF7B5B2A);
      case Prayer.maghrib: return const Color(0xFF5C3A62);
      case Prayer.isha: return const Color(0xFF2E636E);
    }
  }

  // Dark-mode variants – tuned for WCAG AA (≥ 4.5:1) on #292524 surface
  Color get _darkAccentDark {
    switch (this) {
      case Prayer.fajr:    return const Color(0xFF7DB4BE); // 6.6:1
      case Prayer.sunrise: return const Color(0xFFC99A4A); // 5.9:1
      case Prayer.dhuhr:   return const Color(0xFFC99A4A); // 5.9:1
      case Prayer.asr:     return const Color(0xFFD4A574); // 6.8:1
      case Prayer.sunset:  return const Color(0xFFC99A4A); // 5.9:1
      case Prayer.maghrib: return const Color(0xFFC090D4); // 5.9:1
      case Prayer.isha:    return const Color(0xFF7DB4BE); // 6.6:1
    }
  }

  Color get _darkAccentLight {
    switch (this) {
      case Prayer.fajr:    return const Color(0xFFA8D4DC);
      case Prayer.sunrise: return const Color(0xFFE0C08A);
      case Prayer.dhuhr:   return const Color(0xFFE0C08A);
      case Prayer.asr:     return const Color(0xFFE8CCA0);
      case Prayer.sunset:  return const Color(0xFFE0C08A);
      case Prayer.maghrib: return const Color(0xFFD4B0E0);
      case Prayer.isha:    return const Color(0xFFA8D4DC);
    }
  }

  /// Returns the accent color adjusted for the current theme brightness.
  Color accentFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkAccentDark : accentDark;

  /// Returns the light accent color adjusted for the current theme brightness.
  Color accentLightFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkAccentLight : accentLight;

  bool get hasIqamah => this != Prayer.sunrise && this != Prayer.sunset;

  static List<Prayer> get mainPrayers =>
      [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];
}

class PrayerTime {
  final Prayer prayer;
  String? athanTime;
  String? iqamahTime;
  String source;

  PrayerTime({
    required this.prayer,
    this.athanTime,
    this.iqamahTime,
    this.source = 'api',
  });

  DateTime? get athanDate => _parseTime(athanTime);
  DateTime? get iqamahDate => _parseTime(iqamahTime);

  static DateTime? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.substring(0, 5).split(':');
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  static String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final input = timeStr.substring(0, 5);
      final parts = input.split(':');
      final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  factory PrayerTime.fromJson(Prayer prayer, Map<String, dynamic> json) {
    return PrayerTime(
      prayer: prayer,
      athanTime: json['athan'] as String?,
      iqamahTime: json['iqamah'] as String?,
      source: json['source'] as String? ?? 'api',
    );
  }
}
