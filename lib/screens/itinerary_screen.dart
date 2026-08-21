import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/destination.dart';
import '../services/distance_service.dart';
import '../services/route_optimizer.dart';
import '../services/transport_advisor.dart';
import '../services/trip_service.dart';
import '../services/navigation_service.dart';
import '../services/notification_service.dart';
import '../services/opening_hours_service.dart';
import '../utils/error_messages.dart';
import 'add_destinations_screen.dart';

class ItineraryScreen extends StatefulWidget {
  final Destination start;
  final List<Destination> stops;
  final Destination finalDestination;
  final TimeOfDay deadline;
  final OptimizationPriority priority;
  /// If true, [stops] is treated as a REQUIRED order the user specified,
  /// rather than something the optimizer is free to reorder. The screen
  /// will still compute and offer the fully optimal order for comparison.
  final bool useCustomOrder;

  const ItineraryScreen({
    super.key,
    required this.start,
    required this.stops,
    required this.finalDestination,
    required this.deadline,
    this.priority = OptimizationPriority.fastest,
    this.useCustomOrder = false,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final _distanceService = DistanceService();
  final _optimizer = RouteOptimizer();
  final _transportAdvisor = TransportAdvisor();
  final _tripService = TripService();
  final _navigationService = NavigationService();
  final _notificationService = NotificationService();
  final _openingHoursService = OpeningHoursService();
  final _mapController = MapController();

  bool _remindersEnabled = false;
  bool _isSchedulingReminders = false;

  bool _isSaving = false;
  bool _isSaved = false;

  bool _isLoading = true;
  bool _isSwitching = false;
  String? _errorMessage;

  OptimizedRoute? _route; // whichever route is currently on screen
  OptimizedRoute? _alternativeRoute; // the other one, if there is one, for comparison
  List<LatLng> _routePoints = [];
  List<TransportRecommendation> _recommendations = [];

  // Cached so switching between "your order" and "optimal order" doesn't
  // need to hit OSRM again \u2014 only the display-finalizing step (map
  // geometry + verified transport recommendations) reruns.
  List<List<double>>? _durationsSeconds;
  List<List<double>>? _distancesMeters;

  @override
  void initState() {
    super.initState();
    _computeRoute();
  }

  Future<void> _computeRoute() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final points = [widget.start, ...widget.stops, widget.finalDestination];
      final matrices = await _distanceService.getTravelMatrices(points);
      _durationsSeconds = matrices.durationsSeconds;
      _distancesMeters = matrices.distancesMeters;

      final optimalRoute = _optimizer.findBestRoute(
        start: widget.start,
        stops: widget.stops,
        finalDestination: widget.finalDestination,
        travelTimeMatrix: matrices.durationsSeconds,
        distanceMatrix: matrices.distancesMeters,
        deadline: widget.deadline,
        priority: widget.priority,
      );

      OptimizedRoute primary = optimalRoute;
      OptimizedRoute? alternative;

      if (widget.useCustomOrder) {
        final customRoute = _optimizer.computeFixedOrderRoute(
          start: widget.start,
          stops: widget.stops,
          finalDestination: widget.finalDestination,
          travelTimeMatrix: matrices.durationsSeconds,
          distanceMatrix: matrices.distancesMeters,
          deadline: widget.deadline,
        );
        primary = customRoute;
        // Only worth showing as a comparison if it's actually different.
        final sameOrder = _sameOrder(customRoute, optimalRoute);
        if (!sameOrder) alternative = optimalRoute;
      }

      await _finalizeDisplay(primary, alternative);
    } catch (e) {
      setState(() {
        _errorMessage = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  bool _sameOrder(OptimizedRoute a, OptimizedRoute b) {
    if (a.orderedStops.length != b.orderedStops.length) return false;
    for (int i = 0; i < a.orderedStops.length; i++) {
      if (a.orderedStops[i].destination.name != b.orderedStops[i].destination.name) {
        return false;
      }
    }
    return true;
  }

  /// Computes map geometry and verified per-leg transport recommendations
  /// for [route], and puts it on screen. Used both for the initial load
  /// and when the user switches between "your order" and "optimal order."
  Future<void> _finalizeDisplay(OptimizedRoute route, OptimizedRoute? alternative) async {
    final orderedForMap = [
      widget.start,
      ...route.orderedStops.map((s) => s.destination),
      widget.finalDestination,
    ];
    List<LatLng> geometry = [];
    try {
      final geo = await _distanceService.getRouteGeometry(orderedForMap);
      geometry = geo.map((p) => LatLng(p[0], p[1])).toList();
    } catch (_) {
      geometry = orderedForMap.map((d) => LatLng(d.lat, d.lon)).toList();
    }

    final recommendations = <TransportRecommendation>[];
    Destination legOrigin = widget.start;
    for (final stop in route.orderedStops) {
      final rec = await _transportAdvisor.recommend(
        distanceKm: stop.legDistanceKm,
        originLat: legOrigin.lat,
        originLon: legOrigin.lon,
        destLat: stop.destination.lat,
        destLon: stop.destination.lon,
      );
      recommendations.add(rec);
      legOrigin = stop.destination;
    }
    final finalRec = await _transportAdvisor.recommend(
      distanceKm: route.finalLegDistanceKm,
      originLat: legOrigin.lat,
      originLon: legOrigin.lon,
      destLat: widget.finalDestination.lat,
      destLon: widget.finalDestination.lon,
    );
    recommendations.add(finalRec);

    if (!mounted) return;
    setState(() {
      _route = route;
      _alternativeRoute = alternative;
      _routePoints = geometry;
      _recommendations = recommendations;
      _isLoading = false;
      _isSwitching = false;
      _isSaved = false; // switching orders means this specific plan hasn't been saved yet
    });
  }

  Future<void> _switchToAlternative() async {
    final current = _route;
    final alt = _alternativeRoute;
    if (current == null || alt == null) return;

    setState(() => _isSwitching = true);
    await _finalizeDisplay(alt, current);
  }

  Future<void> _saveTrip() async {
    if (_route == null) return;
    setState(() => _isSaving = true);
    try {
      await _tripService.saveTrip(
        start: widget.start,
        route: _route!,
        finalDestination: widget.finalDestination,
        deadline: widget.deadline,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip saved to your travel history.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save trip: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _navigateTo(double lat, double lon, String label) async {
    try {
      await _navigationService.openDirectionsTo(lat, lon);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open navigation to $label.')),
      );
    }
  }

  Future<void> _editTrip() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => AddDestinationsScreen(
          initialStops: widget.stops,
          initialFinalDestination: widget.finalDestination,
          initialDeadline: widget.deadline,
          initialPriority: widget.priority,
          initialUseCustomOrder: widget.useCustomOrder,
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;

    final stops = result['stops'] as List<Destination>;
    final finalDestination = result['finalDestination'] as Destination;
    final deadline = result['deadline'] as TimeOfDay;
    final priority = result['priority'] as OptimizationPriority? ?? OptimizationPriority.fastest;
    final useCustomOrder = result['useCustomOrder'] as bool? ?? false;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ItineraryScreen(
          start: widget.start,
          stops: stops,
          finalDestination: finalDestination,
          deadline: deadline,
          priority: priority,
          useCustomOrder: useCustomOrder,
        ),
      ),
    );
  }

  /// Builds one Google Maps link covering the ENTIRE optimized route —
  /// origin, all intermediate stops as waypoints (in the optimized
  /// order), and the final destination. Opening this link launches real
  /// turn-by-turn navigation through every stop, not just one point.
  /// No API key needed — this is a plain URL, the same as any link.
  String _buildGoogleMapsRouteUrl() {
    final route = _route;
    if (route == null) return '';

    final origin = '${widget.start.lat},${widget.start.lon}';
    final destination = '${widget.finalDestination.lat},${widget.finalDestination.lon}';
    final waypoints = route.orderedStops
        .map((s) => '${s.destination.lat},${s.destination.lon}')
        .join('|');

    final url = StringBuffer(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination',
    );
    if (waypoints.isNotEmpty) {
      url.write('&waypoints=$waypoints');
    }
    url.write('&travelmode=driving');
    return url.toString();
  }

  String _buildShareText() {
    final route = _route;
    if (route == null) return 'My TravelIQ itinerary';

    final buffer = StringBuffer();
    buffer.writeln('📍 My TravelIQ Trip Plan');
    buffer.writeln();
    buffer.writeln('Start: ${widget.start.name}');

    for (int i = 0; i < route.orderedStops.length; i++) {
      final stop = route.orderedStops[i];
      final rec = i < _recommendations.length ? _recommendations[i] : null;
      buffer.writeln(
        '${i + 1}. ${stop.destination.name} — arrive ${_formatTime(stop.estimatedArrival)}'
        '${rec != null ? ' (${rec.mode})' : ''}',
      );
    }

    buffer.writeln(
      'Final: ${widget.finalDestination.name} — arrive ${_formatTime(route.finalArrival)}',
    );
    buffer.writeln();
    buffer.writeln(
      route.meetsDeadline
          ? '✅ On track to meet the deadline.'
          : '⚠️ This plan runs past the deadline — consider dropping a stop.',
    );
    buffer.writeln();
    buffer.writeln('Planned with TravelIQ');
    buffer.writeln();
    buffer.writeln('🗺️ Open the full route in Google Maps:');
    buffer.writeln(_buildGoogleMapsRouteUrl());

    return buffer.toString();
  }

  Future<void> _shareItinerary() async {
    await SharePlus.instance.share(
      ShareParams(text: _buildShareText(), subject: 'My TravelIQ Trip Plan'),
    );
  }

  Future<void> _toggleReminders() async {
    if (_remindersEnabled) {
      await _notificationService.cancelAll();
      setState(() => _remindersEnabled = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Departure reminders turned off.')),
      );
      return;
    }

    setState(() => _isSchedulingReminders = true);

    await _notificationService.init();
    final granted = await _notificationService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() => _isSchedulingReminders = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission was not granted.')),
      );
      return;
    }

    final route = _route!;
    await _notificationService.cancelAll();

    int scheduledCount = 0;
    int id = 0;
    for (int i = 0; i < route.orderedStops.length; i++) {
      final stop = route.orderedStops[i];
      final departureTime =
          stop.estimatedArrival.add(Duration(minutes: stop.destination.dwellMinutes));
      final reminderTime = departureTime.subtract(const Duration(minutes: 5));
      final nextName = i + 1 < route.orderedStops.length
          ? route.orderedStops[i + 1].destination.name
          : widget.finalDestination.name;

      final wasFuture = reminderTime.isAfter(DateTime.now());
      await _notificationService.scheduleReminder(
        id: id++,
        title: 'Time to leave ${stop.destination.name}',
        body: 'Head out now to reach $nextName on schedule.',
        scheduledTime: reminderTime,
      );
      if (wasFuture) scheduledCount++;
    }

    if (!mounted) return;
    setState(() {
      _remindersEnabled = true;
      _isSchedulingReminders = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduledCount > 0
              ? 'Reminders set for $scheduledCount stop(s).'
              : 'No advance reminders needed for this plan.',
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  LatLngBounds _boundsForRoute() {
    final all = [
      LatLng(widget.start.lat, widget.start.lon),
      ...widget.stops.map((s) => LatLng(s.lat, s.lon)),
      LatLng(widget.finalDestination.lat, widget.finalDestination.lon),
    ];
    return LatLngBounds.fromPoints(all);
  }

  double get _totalEstimatedCost =>
      _recommendations.fold(0.0, (sum, r) => sum + r.estimatedCostRupees);

  double get _totalDistanceKm {
    if (_route == null) return 0;
    final legDistances = _route!.orderedStops.map((s) => s.legDistanceKm).toList();
    legDistances.add(_route!.finalLegDistanceKm);
    return legDistances.fold(0.0, (sum, d) => sum + d);
  }

  double get _totalCo2Grams {
    if (_route == null) return 0;
    final legDistances = [
      ..._route!.orderedStops.map((s) => s.legDistanceKm),
      _route!.finalLegDistanceKm,
    ];
    double total = 0;
    for (int i = 0; i < _recommendations.length; i++) {
      total += _recommendations[i].co2GramsPerKm * legDistances[i];
    }
    return total;
  }

  double get _co2SavedGrams {
    final baseline = _transportAdvisor.baselineCarCo2Grams(_totalDistanceKm);
    final saved = baseline - _totalCo2Grams;
    return saved < 0 ? 0 : saved;
  }

  String _priorityLabel(OptimizationPriority p) {
    switch (p) {
      case OptimizationPriority.fastest:
        return 'Fastest';
      case OptimizationPriority.cheapest:
        return 'Cheapest';
      case OptimizationPriority.eco:
        return 'Eco-Friendly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Optimized Itinerary'),
        actions: [
          if (!_isLoading && _errorMessage == null) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Itinerary',
              onPressed: _shareItinerary,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Trip',
              onPressed: _editTrip,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Optimizing your route and checking real transit options\u2026',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _computeRoute,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildResult(),
    );
  }

  Widget _buildResult() {
    final route = _route!;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // ---- MAP ----
        SizedBox(
          height: 250,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: _boundsForRoute(),
                padding: const EdgeInsets.all(40),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.smart_travel_planner',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, strokeWidth: 4, color: primary),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.start.lat, widget.start.lon),
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                  ),
                  for (int i = 0; i < route.orderedStops.length; i++)
                    Marker(
                      point: LatLng(
                        route.orderedStops[i].destination.lat,
                        route.orderedStops[i].destination.lon,
                      ),
                      width: 36,
                      height: 36,
                      child: _numberedPin('${i + 1}', Colors.deepPurple),
                    ),
                  Marker(
                    point: LatLng(widget.finalDestination.lat, widget.finalDestination.lon),
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.flag_circle, color: Colors.green, size: 34),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ---- LIST BELOW MAP ----
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (route.isUserOrdered)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reorder, size: 15, color: Colors.deepPurple),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Showing YOUR order, not the optimizer\'s pick.',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.deepPurple),
                        ),
                      ),
                    ],
                  ),
                ),

              Card(
                color: route.meetsDeadline
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        route.meetsDeadline ? Icons.check_circle : Icons.warning_amber,
                        color: route.meetsDeadline ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          route.meetsDeadline
                              ? 'This plan gets you there by ${_formatTime(route.finalArrival)} \u2014 on time.'
                              : 'Even this order arrives at ${_formatTime(route.finalArrival)}, '
                                  'after your deadline.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Comparison card: your order vs. optimal order ----
              if (_alternativeRoute != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.blue.withOpacity(0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Text(
                              route.isUserOrdered ? 'The Optimal Order Would Be' : 'Your Requested Order Would Be',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _alternativeRoute!.orderedStops.map((s) => s.destination.name.split(',').first).join('  \u2192  '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _comparisonSummary(route, _alternativeRoute!),
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isSwitching ? null : _switchToAlternative,
                            icon: _isSwitching
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.swap_horiz, size: 16),
                            label: Text(
                              route.isUserOrdered ? 'Switch to Optimal Order' : 'Switch to My Order',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Estimated total fare: \u20b9${_totalEstimatedCost.round()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Tooltip(
                        message: 'Metro legs are verified against real station '
                            'locations. Other modes are distance-based estimates.',
                        child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  if (!route.isUserOrdered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            route.priorityUsed == OptimizationPriority.eco
                                ? Icons.eco_outlined
                                : route.priorityUsed == OptimizationPriority.cheapest
                                    ? Icons.payments_outlined
                                    : Icons.bolt,
                            size: 13,
                            color: primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Optimized for ${_priorityLabel(route.priorityUsed)}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_co2SavedGrams > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco, size: 13, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${(_co2SavedGrams / 1000).toStringAsFixed(1)} kg CO\u2082 saved vs. driving',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: _isSaved
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        label: const Text('Saved to Travel History'),
                      )
                    : ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveTrip,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.bookmark_add_outlined),
                        label: Text(_isSaving ? 'Saving\u2026' : 'Save to Travel History'),
                      ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSchedulingReminders ? null : _toggleReminders,
                  icon: _isSchedulingReminders
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_remindersEnabled ? Icons.notifications_active : Icons.notifications_none),
                  label: Text(
                    _isSchedulingReminders
                        ? 'Setting reminders\u2026'
                        : _remindersEnabled
                            ? 'Departure Reminders On'
                            : 'Enable Departure Reminders',
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _timelineTile(
                icon: Icons.my_location,
                title: 'Start',
                subtitle: widget.start.name,
                time: null,
                isFirst: true,
              ),
              for (int i = 0; i < route.orderedStops.length; i++)
                _timelineTile(
                  icon: Icons.place,
                  title: route.orderedStops[i].destination.name,
                  subtitle: 'Estimated arrival \u00b7 staying '
                      '${route.orderedStops[i].destination.dwellMinutes} min',
                  time: _formatTime(route.orderedStops[i].estimatedArrival),
                  recommendation: _recommendations[i],
                  onNavigate: () => _navigateTo(
                    route.orderedStops[i].destination.lat,
                    route.orderedStops[i].destination.lon,
                    route.orderedStops[i].destination.name,
                  ),
                  showsClosedWarning: _openingHoursService.isOpenAt(
                        route.orderedStops[i].destination.openingHours,
                        route.orderedStops[i].estimatedArrival,
                      ) ==
                      OpenStatus.closed,
                ),
              _timelineTile(
                icon: Icons.flag,
                title: widget.finalDestination.name,
                subtitle: 'Final destination',
                time: _formatTime(route.finalArrival),
                isLast: true,
                highlight: true,
                recommendation: _recommendations.last,
                onNavigate: () => _navigateTo(
                  widget.finalDestination.lat,
                  widget.finalDestination.lon,
                  widget.finalDestination.name,
                ),
                showsClosedWarning: _openingHoursService.isOpenAt(
                      widget.finalDestination.openingHours,
                      route.finalArrival,
                    ) ==
                    OpenStatus.closed,
              ),

              const SizedBox(height: 12),
              Text(
                'Total travel and stop time: ${route.totalTravelMinutes.round()} minutes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  String _comparisonSummary(OptimizedRoute shown, OptimizedRoute alternative) {
    final diff = (alternative.totalTravelMinutes - shown.totalTravelMinutes).round();
    if (diff == 0) {
      return 'Same total time \u2014 just a different order of stops.';
    }
    if (diff < 0) {
      return '${diff.abs()} minutes faster than the order shown above.';
    }
    return '${diff.abs()} minutes slower, but follows your required order.';
  }

  Widget _numberedPin(String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _timelineTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? time,
    bool isFirst = false,
    bool isLast = false,
    bool highlight = false,
    TransportRecommendation? recommendation,
    VoidCallback? onNavigate,
    bool showsClosedWarning = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (!isFirst) Container(width: 2, height: 12, color: Colors.grey.shade300),
            CircleAvatar(
              radius: 16,
              backgroundColor: highlight ? Colors.green : Theme.of(context).colorScheme.primary,
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            if (!isLast) Container(width: 2, height: recommendation != null ? 56 : 40, color: Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommendation != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(recommendation.icon, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 5),
                        Text(
                          '${recommendation.mode} \u00b7 '
                          '${recommendation.estimatedCostRupees == 0 ? "Free" : "\u20b9${recommendation.estimatedCostRupees.round()}"}',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                        if (recommendation.isVerified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 10, color: Colors.green.shade700),
                                const SizedBox(width: 3),
                                Text(
                                  'Verified',
                                  style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (showsClosedWarning)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_outlined, size: 12, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'May be closed at this time',
                            style: TextStyle(fontSize: 10.5, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (time != null)
                      Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (onNavigate != null)
                      IconButton(
                        icon: Icon(Icons.directions, color: Theme.of(context).colorScheme.primary),
                        tooltip: 'Navigate here',
                        onPressed: onNavigate,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}