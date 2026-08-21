import 'package:flutter/material.dart';
import '../services/places_service.dart';
import '../models/destination.dart';

class TripDetailsScreen extends StatefulWidget {
  final List<Destination> destinations;

  const TripDetailsScreen({super.key, required this.destinations});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final _searchController = TextEditingController();
  final _placesService = PlacesService();

  List<PlaceResult> _searchResults = [];
  Destination? _finalDestination;
  TimeOfDay? _deadline;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await _placesService.searchPlaces(_searchController.text);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed. Try again.';
        _isLoading = false;
      });
    }
  }

  void _selectFinalDestination(PlaceResult place) {
    setState(() {
      _finalDestination = Destination(name: place.displayName, lat: place.lat, lon: place.lon);
      _searchResults = [];
      _searchController.clear();
    });
  }

  Future<void> _pickDeadline() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  bool get _canContinue => _finalDestination != null && _deadline != null;

  void _onContinue() {
    Navigator.of(context).pop({
      'finalDestination': _finalDestination,
      'deadline': _deadline,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Final Destination and Deadline')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Where do you need to end up, and by when?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Final destination search
              if (_finalDestination == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search final destination',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _isLoading ? null : _search,
                    ),
                  ],
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                if (_searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          title: Text(
                            place.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.flag, color: Colors.green),
                          onTap: () => _selectFinalDestination(place),
                        );
                      },
                    ),
                  ),
              ] else ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.flag, color: Colors.green),
                    title: const Text('Final Destination'),
                    subtitle: Text(
                      _finalDestination!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => setState(() => _finalDestination = null),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Deadline picker
              Text('Arrival Deadline', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDeadline,
                icon: const Icon(Icons.access_time),
                label: Text(
                  _deadline == null
                      ? 'Select a time'
                      : 'Reach by ${_deadline!.format(context)}',
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _canContinue ? _onContinue : null,
                child: const Text('Optimize My Route'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}