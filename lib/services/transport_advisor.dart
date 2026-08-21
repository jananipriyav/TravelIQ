import 'package:flutter/material.dart';
import 'metro_station_service.dart';

class TransportRecommendation {
  final String mode;
  final IconData icon;
  final double estimatedCostRupees;
  final double co2GramsPerKm;
  /// True when this recommendation is backed by real, checked
  /// infrastructure (a metro station actually confirmed nearby via
  /// OpenStreetMap) rather than a distance-based guess.
  final bool isVerified;

  TransportRecommendation({
    required this.mode,
    required this.icon,
    required this.estimatedCostRupees,
    required this.co2GramsPerKm,
    required this.isVerified,
  });
}

/// What the user wants the optimizer to prioritize among all
/// deadline-feasible orderings. The deadline itself is always a hard
/// constraint in every mode — this only decides which feasible option
/// wins.
enum OptimizationPriority { fastest, cheapest, eco }

/// Recommends a transport mode, fare, and approximate emissions for a
/// single leg of a journey.
///
/// For Metro: checks real Chennai Metro station locations (fetched live
/// from OpenStreetMap) and only recommends Metro when an actual station
/// exists within walking distance of BOTH ends of the leg — a verified
/// recommendation, not a guess. This check is a network call, so it's
/// only used on the FINAL chosen route, not during the search itself.
///
/// For search/ranking across many possible route orderings, use
/// [quickEstimate] instead — a synchronous, distance-only version of the
/// same tiering logic, fast enough to run for every permutation.
///
/// CO2 figures are indicative published averages (grams per passenger-km),
/// not measured emissions — used to compare relative footprint between
/// modes, not as a precise carbon accounting figure.
class TransportAdvisor {
  final MetroStationService _metroService = MetroStationService();

  static const double _stationWalkRadiusMeters = 900;

  static const Map<String, double> _co2GramsPerKm = {
    'Walk': 0,
    'Auto Rickshaw': 80,
    'Bus': 30,
    'Metro': 15,
    'Taxi / Cab': 180,
  };

  Future<TransportRecommendation> recommend({
    required double distanceKm,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  }) async {
    if (distanceKm < 1.0) {
      return _walkRecommendation();
    }

    final originStation = await _metroService.nearestStationWithin(
      originLat, originLon, _stationWalkRadiusMeters,
    );
    final destStation = await _metroService.nearestStationWithin(
      destLat, destLon, _stationWalkRadiusMeters,
    );

    if (originStation != null &&
        destStation != null &&
        originStation.name != destStation.name) {
      return TransportRecommendation(
        mode: 'Metro (${originStation.name} \u2192 ${destStation.name})',
        icon: Icons.tram,
        estimatedCostRupees: _chennaiMetroFare(distanceKm),
        co2GramsPerKm: _co2GramsPerKm['Metro']!,
        isVerified: true,
      );
    }

    return _tierRecommendation(distanceKm);
  }

  /// Fast, synchronous, distance-only estimate — no network call. Used
  /// when scoring many candidate route orderings during optimization,
  /// where making a live metro-verification request per leg per
  /// permutation would be far too slow.
  TransportRecommendation quickEstimate(double distanceKm) {
    if (distanceKm < 1.0) return _walkRecommendation();
    return _tierRecommendation(distanceKm);
  }

  TransportRecommendation _walkRecommendation() => TransportRecommendation(
        mode: 'Walk',
        icon: Icons.directions_walk,
        estimatedCostRupees: 0,
        co2GramsPerKm: _co2GramsPerKm['Walk']!,
        isVerified: true,
      );

  TransportRecommendation _tierRecommendation(double distanceKm) {
    if (distanceKm < 5.0) {
      return TransportRecommendation(
        mode: 'Auto Rickshaw',
        icon: Icons.electric_rickshaw,
        estimatedCostRupees: 30 + (distanceKm * 14),
        co2GramsPerKm: _co2GramsPerKm['Auto Rickshaw']!,
        isVerified: false,
      );
    }
    if (distanceKm < 15.0) {
      return TransportRecommendation(
        mode: 'Bus',
        icon: Icons.directions_bus,
        estimatedCostRupees: 10 + (distanceKm * 1.5),
        co2GramsPerKm: _co2GramsPerKm['Bus']!,
        isVerified: false,
      );
    }
    return TransportRecommendation(
      mode: 'Taxi / Cab',
      icon: Icons.local_taxi,
      estimatedCostRupees: 50 + (distanceKm * 12),
      co2GramsPerKm: _co2GramsPerKm['Taxi / Cab']!,
      isVerified: false,
    );
  }

  double _chennaiMetroFare(double distanceKm) {
    if (distanceKm <= 2) return 10;
    if (distanceKm <= 5) return 20;
    if (distanceKm <= 12) return 30;
    if (distanceKm <= 21) return 40;
    return 50;
  }

  /// CO2 if the same total distance had been driven by private taxi/car
  /// instead — used to show how much the chosen plan "saves."
  double baselineCarCo2Grams(double totalDistanceKm) =>
      totalDistanceKm * _co2GramsPerKm['Taxi / Cab']!;
}