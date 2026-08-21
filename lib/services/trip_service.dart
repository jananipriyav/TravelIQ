import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/destination.dart';
import 'route_optimizer.dart';
import 'transport_advisor.dart';

class SavedTripStop {
  final String placeName;
  final double lat;
  final double lon;
  final int visitOrder;
  final int dwellMinutes;
  final DateTime? eta;
  final String? transportMode;
  final double? legCost;

  SavedTripStop({
    required this.placeName,
    required this.lat,
    required this.lon,
    required this.visitOrder,
    required this.dwellMinutes,
    required this.eta,
    required this.transportMode,
    required this.legCost,
  });
}

class SavedTrip {
  final String id;
  final String startLocation;
  final String finalDestination;
  final String deadline;
  final bool meetsDeadline;
  final double totalTravelMinutes;
  final double estimatedCost;
  final DateTime createdAt;
  final List<SavedTripStop> stops;

  SavedTrip({
    required this.id,
    required this.startLocation,
    required this.finalDestination,
    required this.deadline,
    required this.meetsDeadline,
    required this.totalTravelMinutes,
    required this.estimatedCost,
    required this.createdAt,
    required this.stops,
  });
}

class TripService {
  final _client = Supabase.instance.client;
  final _transportAdvisor = TransportAdvisor();

  String _formatDeadline(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Saves a completed itinerary to Supabase under the current user.
  /// Re-checks transport mode per leg (including the real metro station
  /// verification) so saved history reflects the same recommendations
  /// shown on the itinerary screen.
  Future<void> saveTrip({
    required Destination start,
    required OptimizedRoute route,
    required Destination finalDestination,
    required TimeOfDay deadline,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be logged in to save a trip.');
    }

    // Work out a recommendation per leg once, in order, reusing the same
    // running "current point" logic as the itinerary screen.
    final legRecommendations = <TransportRecommendation>[];
    Destination legOrigin = start;
    for (final stop in route.orderedStops) {
      final rec = await _transportAdvisor.recommend(
        distanceKm: stop.legDistanceKm,
        originLat: legOrigin.lat,
        originLon: legOrigin.lon,
        destLat: stop.destination.lat,
        destLon: stop.destination.lon,
      );
      legRecommendations.add(rec);
      legOrigin = stop.destination;
    }
    final finalRecommendation = await _transportAdvisor.recommend(
      distanceKm: route.finalLegDistanceKm,
      originLat: legOrigin.lat,
      originLon: legOrigin.lon,
      destLat: finalDestination.lat,
      destLon: finalDestination.lon,
    );

    double totalCost = finalRecommendation.estimatedCostRupees;
    for (final rec in legRecommendations) {
      totalCost += rec.estimatedCostRupees;
    }

    final tripRow = await _client
        .from('trips')
        .insert({
          'user_id': userId,
          'start_location': start.name,
          'start_lat': start.lat,
          'start_lon': start.lon,
          'final_destination': finalDestination.name,
          'final_lat': finalDestination.lat,
          'final_lon': finalDestination.lon,
          'deadline': _formatDeadline(deadline),
          'meets_deadline': route.meetsDeadline,
          'total_travel_minutes': route.totalTravelMinutes,
          'estimated_cost': totalCost,
        })
        .select()
        .single();

    final tripId = tripRow['id'];

    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < route.orderedStops.length; i++) {
      final stop = route.orderedStops[i];
      final rec = legRecommendations[i];
      rows.add({
        'trip_id': tripId,
        'place_name': stop.destination.name,
        'lat': stop.destination.lat,
        'lon': stop.destination.lon,
        'visit_order': i + 1,
        'dwell_minutes': stop.destination.dwellMinutes,
        'eta': stop.estimatedArrival.toIso8601String(),
        'transport_mode': rec.mode,
        'leg_cost': rec.estimatedCostRupees,
      });
    }
    rows.add({
      'trip_id': tripId,
      'place_name': finalDestination.name,
      'lat': finalDestination.lat,
      'lon': finalDestination.lon,
      'visit_order': route.orderedStops.length + 1,
      'dwell_minutes': 0,
      'eta': route.finalArrival.toIso8601String(),
      'transport_mode': finalRecommendation.mode,
      'leg_cost': finalRecommendation.estimatedCostRupees,
    });

    if (rows.isNotEmpty) {
      await _client.from('trip_destinations').insert(rows);
    }
  }

  /// Deletes a saved trip. Its stops in trip_destinations are removed
  /// automatically via the "on delete cascade" foreign key set up in
  /// the schema migration.
  Future<void> deleteTrip(String tripId) async {
    await _client.from('trips').delete().eq('id', tripId);
  }

  /// Fetches all past trips for the current user, most recent first,
  /// each with its ordered list of stops.
  Future<List<SavedTrip>> getTripHistory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final tripsData = await _client
        .from('trips')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final trips = <SavedTrip>[];
    for (final t in tripsData as List) {
      final destData = await _client
          .from('trip_destinations')
          .select()
          .eq('trip_id', t['id'])
          .order('visit_order', ascending: true);

      trips.add(SavedTrip(
        id: t['id'],
        startLocation: t['start_location'] ?? '',
        finalDestination: t['final_destination'] ?? '',
        deadline: t['deadline'] ?? '',
        meetsDeadline: t['meets_deadline'] ?? false,
        totalTravelMinutes: (t['total_travel_minutes'] as num?)?.toDouble() ?? 0,
        estimatedCost: (t['estimated_cost'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(t['created_at']),
        stops: (destData as List)
            .map((d) => SavedTripStop(
                  placeName: d['place_name'] ?? '',
                  lat: (d['lat'] as num?)?.toDouble() ?? 0,
                  lon: (d['lon'] as num?)?.toDouble() ?? 0,
                  visitOrder: d['visit_order'] ?? 0,
                  dwellMinutes: d['dwell_minutes'] ?? 0,
                  eta: d['eta'] != null ? DateTime.parse(d['eta']) : null,
                  transportMode: d['transport_mode'],
                  legCost: (d['leg_cost'] as num?)?.toDouble(),
                ))
            .toList(),
      ));
    }
    return trips;
  }
}