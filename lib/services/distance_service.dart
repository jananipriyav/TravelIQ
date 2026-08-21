import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/destination.dart';

/// Holds both travel-time and distance matrices for the same set of points,
/// since OSRM returns them together in one call.
class TravelMatrices {
  final List<List<double>> durationsSeconds;
  final List<List<double>> distancesMeters;

  TravelMatrices({required this.durationsSeconds, required this.distancesMeters});
}

/// Fetches travel-time/distance data and route geometry from the public
/// OSRM demo server. All calls use the "driving" profile, since that's the
/// only profile the free public server offers.
class DistanceService {
  /// Returns both the duration (seconds) and distance (meters) matrix
  /// between every pair of points, in a single OSRM call.
  Future<TravelMatrices> getTravelMatrices(List<Destination> points) async {
    if (points.length < 2) {
      return TravelMatrices(durationsSeconds: [
        [0]
      ], distancesMeters: [
        [0]
      ]);
    }

    final coords = points.map((p) => '${p.lon},${p.lat}').join(';');
    final url = Uri.parse(
      'https://router.project-osrm.org/table/v1/driving/$coords'
      '?annotations=duration,distance',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch travel data from OSRM');
    }

    final data = jsonDecode(response.body);
    if (data['code'] != 'Ok') {
      throw Exception('OSRM could not compute a route between these points');
    }

    List<List<double>> toMatrix(List<dynamic> raw) => raw
        .map<List<double>>(
          (row) => (row as List<dynamic>)
              .map((v) => v == null ? 0.0 : (v as num).toDouble())
              .toList(),
        )
        .toList();

    return TravelMatrices(
      durationsSeconds: toMatrix(data['durations']),
      distancesMeters: toMatrix(data['distances']),
    );
  }

  /// Returns the actual road-following route geometry (as a list of
  /// lat/lon points, in order) for the given sequence of stops.
  /// Use this AFTER optimization, on the final chosen order, to draw
  /// the real route on the map.
  Future<List<List<double>>> getRouteGeometry(List<Destination> orderedPoints) async {
    if (orderedPoints.length < 2) return [];

    final coords = orderedPoints.map((p) => '${p.lon},${p.lat}').join(';');
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coords'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch route geometry from OSRM');
    }

    final data = jsonDecode(response.body);
    if (data['code'] != 'Ok') {
      throw Exception('OSRM could not draw a route between these points');
    }

    final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
    return coordinates
        .map<List<double>>((c) => [
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ])
        .toList();
  }
}