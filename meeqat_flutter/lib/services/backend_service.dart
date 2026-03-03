import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/prayer_time.dart';
import '../models/masjid.dart';

class BackendService {
  final String baseUrl;
  BackendService({required this.baseUrl});

  // ── Offline cache key helpers ──
  static String _cacheKey(int masjidId, String date) => 'times_${masjidId}_$date';
  static String _jumuahCacheKey(int masjidId) => 'jumuah_$masjidId';
  static const _bulkMetaPrefix = 'bulk_meta_';

  Future<List<Masjid>> fetchMasjids() async {
    final res = await http.get(Uri.parse('$baseUrl/api/masjids'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['masjids'] as List).map((m) => Masjid.fromJson(m)).toList();
    }
    throw Exception('Failed to load masjids');
  }

  Future<List<Masjid>> fetchNearbyMasjids(double lat, double lng, {double radius = 50}) async {
    final res = await http.get(Uri.parse(
      '$baseUrl/api/masjids/nearby?lat=$lat&lng=$lng&radius=$radius'
    ));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['masjids'] as List).map((m) => Masjid.fromJson(m)).toList();
    }
    throw Exception('Failed to load nearby masjids');
  }

  Future<List<PrayerTime>> fetchTimes(int masjidId, {String? date, int dayOffset = 0}) async {
    final dateStr = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      var url = '$baseUrl/api/masjids/$masjidId/times?date=$dateStr';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final timesMap = data['times'] as Map<String, dynamic>;
        // Also cache the result for offline use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey(masjidId, dateStr), jsonEncode(timesMap));
        return Prayer.values.map((p) {
          final entry = timesMap[p.name];
          if (entry != null) {
            return PrayerTime.fromJson(p, entry as Map<String, dynamic>, dayOffset: dayOffset);
          }
          return PrayerTime(prayer: p, dayOffset: dayOffset);
        }).toList();
      }
    } catch (_) {
      // Network failed — try offline cache
      final cached = await getCachedTimes(masjidId, dateStr, dayOffset: dayOffset);
      if (cached != null) return cached;
      // Try nearest cached day as last resort
      final nearest = await findNearestCachedDay(masjidId, dateStr, dayOffset: dayOffset);
      if (nearest != null) return nearest;
    }
    throw Exception('Failed to load times');
  }

  Future<JumuahTimes?> fetchJumuah(int masjidId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/masjids/$masjidId/jumuah'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['jumuah'] != null) {
          final jumuah = JumuahTimes.fromJson(data['jumuah']);
          // Cache for offline use
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_jumuahCacheKey(masjidId), jsonEncode(jumuah.toJson()));
          return jumuah;
        }
      }
    } catch (_) {
      // Network failed — try offline cache
      final cached = await getCachedJumuah(masjidId);
      if (cached != null) return cached;
    }
    return null;
  }

  /// Reads cached Jumuah times from SharedPreferences.
  static Future<JumuahTimes?> getCachedJumuah(int masjidId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_jumuahCacheKey(masjidId));
    if (raw == null) return null;
    try {
      return JumuahTimes.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<Announcement>> fetchAnnouncements(int masjidId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/masjids/$masjidId/announcements'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['announcements'] as List).map((a) => Announcement.fromJson(a)).toList();
    }
    return [];
  }

  // ── Bulk download ──

  /// Fetches prayer times for [days] starting from [fromDate] via the bulk
  /// endpoint and stores each day in SharedPreferences for offline use.
  /// Returns the number of days stored.
  Future<int> fetchBulkTimes(int masjidId, {String? fromDate, int days = 180}) async {
    final from = fromDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await http.get(Uri.parse(
      '$baseUrl/api/masjids/$masjidId/times/bulk?from=$from&days=$days',
    ));
    if (res.statusCode != 200) throw Exception('Failed to download timetable');

    final data = jsonDecode(res.body);
    final timetable = data['timetable'] as Map<String, dynamic>? ?? {};

    final prefs = await SharedPreferences.getInstance();
    int stored = 0;
    for (final entry in timetable.entries) {
      final date = entry.key;
      final timesJson = jsonEncode(entry.value);
      await prefs.setString(_cacheKey(masjidId, date), timesJson);
      stored++;
    }

    // Also fetch and cache Jumuah times during bulk download
    try {
      final jumuahRes = await http.get(Uri.parse('$baseUrl/api/masjids/$masjidId/jumuah'));
      if (jumuahRes.statusCode == 200) {
        final jumuahData = jsonDecode(jumuahRes.body);
        if (jumuahData['jumuah'] != null) {
          await prefs.setString(
            _jumuahCacheKey(masjidId),
            jsonEncode(jumuahData['jumuah']),
          );
        }
      }
    } catch (_) {
      // Non-critical — Jumuah cache is best-effort
    }

    // Store download metadata
    await prefs.setString('$_bulkMetaPrefix$masjidId', jsonEncode({
      'from': from,
      'days': days,
      'stored': stored,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));

    return stored;
  }

  /// Reads cached prayer times for a specific date from SharedPreferences.
  static Future<List<PrayerTime>?> getCachedTimes(int masjidId, String date, {int dayOffset = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(masjidId, date));
    if (raw == null) return null;
    try {
      final timesMap = jsonDecode(raw) as Map<String, dynamic>;
      return Prayer.values.map((p) {
        final entry = timesMap[p.name];
        if (entry != null) {
          return PrayerTime.fromJson(p, entry as Map<String, dynamic>, dayOffset: dayOffset);
        }
        return PrayerTime(prayer: p, dayOffset: dayOffset);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Scans +/- 7 days around [targetDate] for any cached data.
  /// Returns the closest match (prayer times shift ~1-2 min/day so nearby is acceptable).
  static Future<List<PrayerTime>?> findNearestCachedDay(int masjidId, String targetDate, {int dayOffset = 0}) async {
    final target = DateTime.parse(targetDate);
    final prefs = await SharedPreferences.getInstance();
    List<PrayerTime>? best;
    int bestDist = 8;

    for (int offset = -7; offset <= 7; offset++) {
      if (offset == 0) continue;
      final d = target.add(Duration(days: offset));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final raw = prefs.getString(_cacheKey(masjidId, dateStr));
      if (raw != null && offset.abs() < bestDist) {
        try {
          final timesMap = jsonDecode(raw) as Map<String, dynamic>;
          best = Prayer.values.map((p) {
            final entry = timesMap[p.name];
            if (entry != null) {
              return PrayerTime.fromJson(p, entry as Map<String, dynamic>, dayOffset: dayOffset);
            }
            return PrayerTime(prayer: p, dayOffset: dayOffset);
          }).toList();
          bestDist = offset.abs();
        } catch (_) {}
      }
    }
    return best;
  }

  /// Returns bulk download metadata for a masjid, or null if never downloaded.
  static Future<Map<String, dynamic>?> getBulkDownloadMeta(int masjidId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_bulkMetaPrefix$masjidId');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Pair a TV display device with a masjid using the pair code from QR scan.
  /// The [qrData] is the full URL from the QR code, e.g.
  /// "https://server/api/tv/pair?code=123456"
  Future<Map<String, dynamic>> pairTvDevice(String pairCode, int masjidId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/tv/pair'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pair_code': pairCode, 'masjid_id': masjidId}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return data;
    }
    throw Exception(data['error'] ?? 'Failed to pair TV device');
  }
}
