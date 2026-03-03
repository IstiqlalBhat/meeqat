import 'package:hijri/hijri_calendar.dart';

class RamadanService {
  static bool isRamadan([DateTime? date]) {
    final hijri = HijriCalendar.fromDate(date ?? DateTime.now());
    return hijri.hMonth == 9;
  }

  static int? ramadanDay([DateTime? date]) {
    final hijri = HijriCalendar.fromDate(date ?? DateTime.now());
    if (hijri.hMonth != 9) return null;
    return hijri.hDay;
  }

  static Duration? timeToIftar(DateTime? maghribDate) {
    if (maghribDate == null) return null;
    final now = DateTime.now();
    if (maghribDate.isBefore(now)) return null;
    return maghribDate.difference(now);
  }
}
