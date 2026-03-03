class Masjid {
  final int id;
  final String name;
  final String? city;
  final String? state;
  final String? address;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final double? distanceKm;

  Masjid({
    required this.id,
    required this.name,
    this.city,
    this.state,
    this.address,
    this.country,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.distanceKm,
  });

  String get locationString =>
      [city, state].where((s) => s != null && s.isNotEmpty).join(', ');

  String get distanceString {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m away';
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  factory Masjid.fromJson(Map<String, dynamic> json) => Masjid(
    id: json['id'] as int,
    name: json['name'] as String,
    city: json['city'] as String?,
    state: json['state'] as String?,
    address: json['address'] as String?,
    country: json['country'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    imageUrl: json['image_url'] as String?,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
  );
}

class JumuahTimes {
  final String? khutbahTime;
  final String? firstJamaat;
  final String? secondJamaat;

  JumuahTimes({this.khutbahTime, this.firstJamaat, this.secondJamaat});

  factory JumuahTimes.fromJson(Map<String, dynamic> json) => JumuahTimes(
    khutbahTime: json['khutbah_time'] as String?,
    firstJamaat: json['first_jamaat'] as String?,
    secondJamaat: json['second_jamaat'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'khutbah_time': khutbahTime,
    'first_jamaat': firstJamaat,
    'second_jamaat': secondJamaat,
  };
}

class Announcement {
  final int id;
  final String title;
  final String? body;
  final String? imageUrl;
  final String? createdAt;

  Announcement({
    required this.id,
    required this.title,
    this.body,
    this.imageUrl,
    this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as int,
    title: json['title'] as String,
    body: json['body'] as String?,
    imageUrl: json['image_url'] as String?,
    createdAt: json['created_at'] as String?,
  );

  String get formattedDate {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt!);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return '';
    }
  }
}
