import 'package:flutter/material.dart';
import '../models/destination.dart';
import 'transport_advisor.dart';

class RouteStop {
  final Destination destination;
  final DateTime estimatedArrival;
  final double legDistanceKm;

  RouteStop({
    required this.destination,
    required this.estimatedArrival,
    required this.legDistanceKm,
  });
}

class OptimizedRoute {
  final List<RouteStop> orderedStops;
  final DateTime finalArrival;
  final bool meetsDeadline;
  final double totalTravelMinutes;
  final double finalLegDistanceKm;
  final OptimizationPriority priorityUsed;
  /// True if this route follows a user-specified order rather than one
  /// found by searching all possible orderings.
  final bool isUserOrdered;

  OptimizedRoute({
    required this.orderedStops,
    required this.finalArrival,
    required this.meetsDeadline,
    required this.totalTravelMinutes,
    required this.finalLegDistanceKm,
    required this.priorityUsed,
    this.isUserOrdered = false,
  });
}

class RouteOptimizer {
  final TransportAdvisor _advisor = TransportAdvisor();

  /// Finds the best deadline-feasible ordering of [stops], where "best"
  /// depends on [priority] (fastest / cheapest / eco). The deadline is
  /// always a hard constraint — priority only chooses among orderings
  /// that already meet it. Falls back to the least-late ordering if none
  /// meet the deadline.
  OptimizedRoute findBestRoute({
    required Destination start,
    required List<Destination> stops,
    required Destination finalDestination,
    required List<List<double>> travelTimeMatrix,
    required List<List<double>> distanceMatrix,
    required TimeOfDay deadline,
    OptimizationPriority priority = OptimizationPriority.fastest,
  }) {
    final now = DateTime.now();
    final deadlineDateTime = DateTime(
      now.year, now.month, now.day, deadline.hour, deadline.minute,
    );

    if (stops.isEmpty) {
      return _evaluateOrder(
        order: const [],
        start: start,
        stops: stops,
        finalDestination: finalDestination,
        travelTimeMatrix: travelTimeMatrix,
        distanceMatrix: distanceMatrix,
        now: now,
        deadlineDateTime: deadlineDateTime,
        priority: priority,
        isUserOrdered: false,
      );
    }

    final stopIndices = List<int>.generate(stops.length, (i) => i + 1);

    OptimizedRoute? best;
    double bestScore = double.infinity;

    OptimizedRoute? fallback;
    double fallbackOvershootMinutes = double.infinity;

    for (final perm in _permutations(stopIndices)) {
      final candidate = _evaluateOrder(
        order: perm,
        start: start,
        stops: stops,
        finalDestination: finalDestination,
        travelTimeMatrix: travelTimeMatrix,
        distanceMatrix: distanceMatrix,
        now: now,
        deadlineDateTime: deadlineDateTime,
        priority: priority,
        isUserOrdered: false,
      );

      final score = priority == OptimizationPriority.fastest
          ? candidate.totalTravelMinutes
          : _scoreForPriority(candidate, priority);

      if (candidate.meetsDeadline && score < bestScore) {
        bestScore = score;
        best = candidate;
      }

      if (!candidate.meetsDeadline) {
        final overshoot = candidate.finalArrival.difference(deadlineDateTime).inMinutes.toDouble();
        if (overshoot < fallbackOvershootMinutes) {
          fallbackOvershootMinutes = overshoot;
          fallback = candidate;
        }
      }
    }

    return best ?? fallback!;
  }

  /// Evaluates ONE specific, user-chosen order of [stops] (no search) —
  /// used when the user needs to visit places in a particular sequence
  /// rather than letting the algorithm decide.
  OptimizedRoute computeFixedOrderRoute({
    required Destination start,
    required List<Destination> stops,
    required Destination finalDestination,
    required List<List<double>> travelTimeMatrix,
    required List<List<double>> distanceMatrix,
    required TimeOfDay deadline,
    OptimizationPriority priority = OptimizationPriority.fastest,
  }) {
    final now = DateTime.now();
    final deadlineDateTime = DateTime(
      now.year, now.month, now.day, deadline.hour, deadline.minute,
    );
    final order = List<int>.generate(stops.length, (i) => i + 1); // stops are already in the user's order
    return _evaluateOrder(
      order: order,
      start: start,
      stops: stops,
      finalDestination: finalDestination,
      travelTimeMatrix: travelTimeMatrix,
      distanceMatrix: distanceMatrix,
      now: now,
      deadlineDateTime: deadlineDateTime,
      priority: priority,
      isUserOrdered: true,
    );
  }

  double _scoreForPriority(OptimizedRoute route, OptimizationPriority priority) {
    // Re-derives a comparable score from the route's legs for ranking
    // purposes (cost or CO2), matching the same tiers used during search.
    double score = 0;
    Destination? prevForScoring;
    for (final stop in route.orderedStops) {
      final est = _advisor.quickEstimate(stop.legDistanceKm);
      score += priority == OptimizationPriority.cheapest
          ? est.estimatedCostRupees
          : est.co2GramsPerKm * stop.legDistanceKm;
      prevForScoring = stop.destination;
    }
    final finalEst = _advisor.quickEstimate(route.finalLegDistanceKm);
    score += priority == OptimizationPriority.cheapest
        ? finalEst.estimatedCostRupees
        : finalEst.co2GramsPerKm * route.finalLegDistanceKm;
    return score;
  }

  /// Shared evaluation logic: given one specific visiting order (as a
  /// list of 1-based stop indices), compute total time, feasibility,
  /// and per-leg details. Used by both the full search and fixed-order
  /// evaluation, so both stay perfectly consistent with each other.
  OptimizedRoute _evaluateOrder({
    required List<int> order,
    required Destination start,
    required List<Destination> stops,
    required Destination finalDestination,
    required List<List<double>> travelTimeMatrix,
    required List<List<double>> distanceMatrix,
    required DateTime now,
    required DateTime deadlineDateTime,
    required OptimizationPriority priority,
    required bool isUserOrdered,
  }) {
    final finalIndex = stops.length + 1;

    if (order.isEmpty) {
      final travelSeconds = travelTimeMatrix[0][1];
      final arrival = now.add(Duration(seconds: travelSeconds.round()));
      return OptimizedRoute(
        orderedStops: [],
        finalArrival: arrival,
        meetsDeadline: !arrival.isAfter(deadlineDateTime),
        totalTravelMinutes: travelSeconds / 60,
        finalLegDistanceKm: distanceMatrix[0][1] / 1000,
        priorityUsed: priority,
        isUserOrdered: isUserOrdered,
      );
    }

    double totalMinutes = 0;
    int current = 0;
    final List<RouteStop> orderedStops = [];
    DateTime runningTime = now;

    for (final idx in order) {
      final legSeconds = travelTimeMatrix[current][idx];
      final legKm = distanceMatrix[current][idx] / 1000;
      totalMinutes += legSeconds / 60;
      totalMinutes += stops[idx - 1].dwellMinutes;

      runningTime = runningTime.add(Duration(seconds: legSeconds.round()));
      final stopDestination = stops[idx - 1];
      orderedStops.add(RouteStop(
        destination: stopDestination,
        estimatedArrival: runningTime,
        legDistanceKm: legKm,
      ));
      runningTime = runningTime.add(Duration(minutes: stopDestination.dwellMinutes));
      current = idx;
    }

    final finalLegKm = distanceMatrix[current][finalIndex] / 1000;
    totalMinutes += travelTimeMatrix[current][finalIndex] / 60;
    final finalArrival = now.add(Duration(minutes: totalMinutes.round()));

    return OptimizedRoute(
      orderedStops: orderedStops,
      finalArrival: finalArrival,
      meetsDeadline: !finalArrival.isAfter(deadlineDateTime),
      totalTravelMinutes: totalMinutes,
      finalLegDistanceKm: finalLegKm,
      priorityUsed: priority,
      isUserOrdered: isUserOrdered,
    );
  }

  Iterable<List<int>> _permutations(List<int> items) sync* {
    if (items.length <= 1) {
      yield List<int>.from(items);
      return;
    }
    for (int i = 0; i < items.length; i++) {
      final rest = List<int>.from(items)..removeAt(i);
      for (final perm in _permutations(rest)) {
        yield [items[i], ...perm];
      }
    }
  }
}