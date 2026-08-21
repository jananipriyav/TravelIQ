import 'package:flutter/material.dart';
import '../services/trip_service.dart';
import '../utils/error_messages.dart';

class TravelHistoryScreen extends StatefulWidget {
  const TravelHistoryScreen({super.key});

  @override
  State<TravelHistoryScreen> createState() => _TravelHistoryScreenState();
}

class _TravelHistoryScreenState extends State<TravelHistoryScreen> {
  final _tripService = TripService();
  bool _isLoading = true;
  String? _errorMessage;
  List<SavedTrip> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final trips = await _tripService.getTripHistory();
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load your travel history: ${friendlyErrorMessage(e)}';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Removes the trip from view immediately and offers a few seconds to
  /// undo. Only actually deletes it from the database if the undo window
  /// passes without the user tapping Undo.
  Future<void> _deleteWithUndo(SavedTrip trip) async {
    final removedIndex = _trips.indexWhere((t) => t.id == trip.id);
    if (removedIndex == -1) return;

    setState(() => _trips.removeAt(removedIndex));

    final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trip to "${trip.finalDestination}" deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            setState(() => _trips.insert(removedIndex, trip));
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final reason = await snackBarController.closed;
    if (reason == SnackBarClosedReason.action) {
      return; // user tapped Undo — the trip was already restored above
    }

    // Undo window passed without being used — now actually delete it.
    try {
      await _tripService.deleteTrip(trip.id);
    } catch (e) {
      // The real delete failed — put it back and let the user know why.
      if (!mounted) return;
      setState(() => _trips.insert(removedIndex, trip));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete trip: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel History')),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _emptyState(_errorMessage!, icon: Icons.error_outline, showRetry: true)
                : _trips.isEmpty
                    ? _emptyState(
                        'No trips yet — plan your first one from Home!',
                        icon: Icons.history,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _trips.length,
                        itemBuilder: (context, index) => _tripCard(_trips[index]),
                      ),
      ),
    );
  }

  Widget _emptyState(String message, {required IconData icon, bool showRetry = false}) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        ),
        if (showRetry) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(onPressed: _loadHistory, child: const Text('Retry')),
          ),
        ],
      ],
    );
  }

  Widget _tripCard(SavedTrip trip) {
    final primary = Theme.of(context).colorScheme.primary;

    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteWithUndo(trip),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      child: Card(
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: primary.withOpacity(0.12),
          child: Icon(Icons.route, color: primary),
        ),
        title: Text(
          '${trip.startLocation} → ${trip.finalDestination}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_formatDate(trip.createdAt), style: const TextStyle(fontSize: 12)),
              Text('· ${trip.stops.length} stops', style: const TextStyle(fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (trip.meetsDeadline ? Colors.green : Colors.orange).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trip.meetsDeadline ? 'On time' : 'Missed deadline',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: trip.meetsDeadline ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Deadline: ${trip.deadline}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                    Text('~${trip.totalTravelMinutes.round()} min total', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Estimated fare: ₹${trip.estimatedCost.round()}',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
                const Divider(height: 24),
                ...trip.stops.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: primary,
                            child: Text(
                              '${s.visitOrder}',
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.placeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                                if (s.transportMode != null)
                                  Text(
                                    '${s.transportMode} · ${s.eta != null ? _formatTime(s.eta!) : ''}'
                                    '${s.legCost != null ? ' · ₹${s.legCost!.round()}' : ''}',
                                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _deleteWithUndo(trip),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    label: const Text('Delete Trip', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}