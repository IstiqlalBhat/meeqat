import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prayer_time.dart';
import '../models/masjid.dart';

class BackendService {
  final String baseUrl;
  BackendService({required this.baseUrl});

  Future<List<Masjid>> fetchMasjids() async {
    final res = await http.get(Uri.parse('$baseUrl/api/masjids'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['masjids'] as List).map((m) => Masjid.fromJson(m)).toList();
    }
    throw Exception('Failed to load masjids');
  }

  Future<List<PrayerTime>> fetchTimes(int masjidId, {String? date}) async {
    var url = '$baseUrl/api/masjids/$masjidId/times';
    if (date != null) url += '?date=$date';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final timesMap = data['times'] as Map<String, dynamic>;
      return Prayer.values.map((p) {
        final entry = timesMap[p.name];
        if (entry != null) {
          return PrayerTime.fromJson(p, entry as Map<String, dynamic>);
        }
        return PrayerTime(prayer: p);
      }).toList();
    }
    throw Exception('Failed to load times');
  }

  Future<JumuahTimes?> fetchJumuah(int masjidId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/masjids/$masjidId/jumuah'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['jumuah'] != null) {
        return JumuahTimes.fromJson(data['jumuah']);
      }
    }
    return null;
  }

  Future<List<Announcement>> fetchAnnouncements(int masjidId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/masjids/$masjidId/announcements'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['announcements'] as List).map((a) => Announcement.fromJson(a)).toList();
    }
    return [];
  }
}
