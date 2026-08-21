import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class MetroStation {
  final String name;
  final double lat;
  final double lon;

  MetroStation({required this.name, required this.lat, required this.lon});
}

/// Fetches real Chennai Metro station locations from OpenStreetMap via the
/// free Overpass API — actual mapped infrastructure, not a guess. Results
/// are cached in memory for the life of the app session, since the station
/// list doesn't change while someone is planning a trip.
class MetroStationService {
  static List<MetroStation>? _cachedStations;

  Future<List<MetroStation>> getStations() async {
    if (_cachedStations != null) return _cachedStations!;

    // Bounding box roughly covering Chennai metropolitan area.
    const query = '''
[out:json][timeout:25];
node["railway"="station"]["network"~"Chennai Metro",i](12.80,80.05,13.30,80.35);
out body;
''';

    try {
      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        _cachedStations = [];
        return _cachedStations!;
      }

      final data = jsonDecode(response.body);
      final elements = data['elements'] as List<dynamic>;

      _cachedStations = elements
          .map((e) => MetroStation(
                name: (e['tags']?['name'] ?? 'Metro Station') as String,
                lat: (e['lat'] as num).toDouble(),
                lon: (e['lon'] as num).toDouble(),
              ))
          .toList();
      return _cachedStations!;
    } catch (_) {
      // If Overpass is unreachable or slow, degrade gracefully — the
      // TransportAdvisor will just fall back to distance-based heuristics.
      _cachedStations = [];
      return _cachedStations!;
    }
  }

  /// Returns the nearest metro station to a point, only if one genuinely
  /// exists within [maxDistanceMeters] — otherwise null.
  Future<MetroStation?> nearestStationWithin(
    double lat,
    double lon,
    double maxDistanceMeters,
  ) async {
    final stations = await getStations();
    MetroStation? nearest;
    double nearestDist = double.infinity;

    for (final s in stations) {
      final d = _haversineMeters(lat, lon, s.lat, s.lon);
      if (d < nearestDist) {
        nearestDist = d;
        nearest = s;
      }
    }

    if (nearest != null && nearestDist <= maxDistanceMeters) return nearest;
    return null;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);
}