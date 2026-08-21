import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceResult {
  final String displayName;
  final double lat;
  final double lon;
  final String? openingHours; // raw OSM opening_hours tag, if available

  PlaceResult({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.openingHours,
  });
}

class PlacesService {
  Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}'
      '&format=json'
      '&limit=5'
      '&countrycodes=in'
      '&extratags=1', // include OSM extra tags, e.g. opening_hours, if present
    );

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'smart_travel_planner_app',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) {
        final extraTags = item['extratags'] as Map<String, dynamic>?;
        return PlaceResult(
          displayName: item['display_name'],
          lat: double.parse(item['lat']),
          lon: double.parse(item['lon']),
          openingHours: extraTags?['opening_hours'] as String?,
        );
      }).toList();
    } else {
      throw Exception('Failed to search places');
    }
  }
}