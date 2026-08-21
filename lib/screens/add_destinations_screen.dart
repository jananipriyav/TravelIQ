import 'dart:async';
import 'package:flutter/material.dart';
import '../services/places_service.dart';
import '../models/destination.dart';
import '../utils/error_messages.dart';
import '../services/transport_advisor.dart';
import '../services/favorites_service.dart';

class AddDestinationsScreen extends StatefulWidget {
  final List<Destination>? initialStops;
  final Destination? initialFinalDestination;
  final TimeOfDay? initialDeadline;
  final OptimizationPriority? initialPriority;
  final bool? initialUseCustomOrder;

  const AddDestinationsScreen({
    super.key,
    this.initialStops,
    this.initialFinalDestination,
    this.initialDeadline,
    this.initialPriority,
    this.initialUseCustomOrder,
  });

  @override
  State<AddDestinationsScreen> createState() => _AddDestinationsScreenState();
}

class _AddDestinationsScreenState extends State<AddDestinationsScreen> {
  final _searchController = TextEditingController();
  final _placesService = PlacesService();
  final _favoritesService = FavoritesService();
  Timer? _debounce;

  List<PlaceResult> _searchResults = [];
  final List<Destination> _stops = [];
  Destination? _finalDestination;
  TimeOfDay? _deadline;
  OptimizationPriority _priority = OptimizationPriority.fastest;
  bool _useCustomOrder = false;
  List<FavoritePlace> _favorites = [];

  bool get _isEditing => widget.initialStops != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialStops != null) _stops.addAll(widget.initialStops!);
    _finalDestination = widget.initialFinalDestination;
    _deadline = widget.initialDeadline;
    if (widget.initialPriority != null) _priority = widget.initialPriority!;
    if (widget.initialUseCustomOrder != null) _useCustomOrder = widget.initialUseCustomOrder!;
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _favoritesService.getFavorites();
      if (!mounted) return;
      setState(() => _favorites = favorites);
    } catch (_) {
      // Favorites are a convenience, not essential — fail silently so a
      // network hiccup here never blocks the rest of trip planning.
    }
  }

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Called on every keystroke. Waits for a short pause in typing before
  /// actually querying Nominatim, so we don't fire a request per letter.
  void _onQueryChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (value.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () => _search());
  }

  Future<void> _search() async {
    final query = _searchController.text;
    if (query.trim().length < 3) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await _placesService.searchPlaces(query);
      if (!mounted) return;
      // Ignore results if the text has changed since this search started
      if (_searchController.text != query) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<bool?> _askIsFinalDestination(String placeName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Is this your final destination?'),
        content: Text(
          'You said you want to reach:\n\n"$placeName"\n\nby a deadline. Is this that place?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, it\'s a stop along the way'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, this is final'),
          ),
        ],
      ),
    );
  }

  Future<int?> _askDwellMinutes({int initial = 30}) async {
    final controller = TextEditingController(text: initial.toString());
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How long will you spend here?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'e.g. 30, 60, 90',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text) ?? 30;
              Navigator.of(context).pop(minutes);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPlace(PlaceResult place) async {
    _debounce?.cancel();
    await _resolveAndAddPlace(
      name: place.displayName,
      lat: place.lat,
      lon: place.lon,
      openingHours: place.openingHours,
    );
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
  }

  /// Quick-adds a saved favorite directly, skipping the search step.
  Future<void> _addFromFavorite(FavoritePlace fav) async {
    await _resolveAndAddPlace(name: fav.name, lat: fav.lat, lon: fav.lon);
  }

  /// Shared logic: asks whether this is the final destination, then
  /// either sets it as such or asks for a dwell time and adds it as a
  /// stop. Used by both search results and favorites.
  Future<void> _resolveAndAddPlace({
    required String name,
    required double lat,
    required double lon,
    String? openingHours,
  }) async {
    final isFinal = await _askIsFinalDestination(name);
    if (isFinal == null) return;

    if (isFinal) {
      setState(() {
        _finalDestination = Destination(name: name, lat: lat, lon: lon, openingHours: openingHours);
      });
      return;
    }

    final minutes = await _askDwellMinutes();
    if (minutes == null) return;
    setState(() {
      _stops.add(
        Destination(name: name, lat: lat, lon: lon, dwellMinutes: minutes, openingHours: openingHours),
      );
    });
  }

  bool _isFavorited(String name) => _favorites.any((f) => f.name == name);

  Future<void> _toggleFavorite(PlaceResult place) async {
    final existing = _favorites.where((f) => f.name == place.displayName).toList();
    if (existing.isNotEmpty) {
      await _removeFavorite(existing.first);
      return;
    }
    try {
      await _favoritesService.addFavorite(name: place.displayName, lat: place.lat, lon: place.lon);
      if (!mounted) return;
      await _loadFavorites();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to favorites.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save favorite: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _removeFavorite(FavoritePlace fav) async {
    final previous = List<FavoritePlace>.from(_favorites);
    setState(() => _favorites.removeWhere((f) => f.id == fav.id));
    try {
      await _favoritesService.removeFavorite(fav.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _favorites = previous); // restore on failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove favorite: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _editDwellTime(int index) async {
    final current = _stops[index];
    final minutes = await _askDwellMinutes(initial: current.dwellMinutes);
    if (minutes == null) return;
    setState(() => _stops[index] = current.copyWith(dwellMinutes: minutes));
  }

  void _removeStop(int index) => setState(() => _stops.removeAt(index));

  void _clearFinalDestination() => setState(() => _finalDestination = null);

  Future<void> _pickDeadline() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _deadline = picked);
  }

  bool get _canContinue => _stops.isNotEmpty && _finalDestination != null && _deadline != null;

  void _onContinue() {
    Navigator.of(context).pop({
      'stops': _stops,
      'finalDestination': _finalDestination,
      'deadline': _deadline,
      'priority': _priority,
      'useCustomOrder': _useCustomOrder,
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Your Trip' : 'Plan Your Trip')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ---- Favorites (quick-add places you've saved before) ----
            if (_favorites.isNotEmpty) ...[
              Text('Favorites', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _favorites.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final fav = _favorites[i];
                    return InputChip(
                      avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                      label: Text(
                        fav.name.split(',').first,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _addFromFavorite(fav),
                      onDeleted: () => _removeFavorite(fav),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ---- Search (live, as you type) ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Start typing a place name…',
                          prefixIcon: Icon(Icons.search, color: primary),
                          border: InputBorder.none,
                        ),
                        onChanged: _onQueryChanged,
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _debounce?.cancel();
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      ),
                  ],
                ),
              ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),

            if (_searchResults.isNotEmpty)
              Card(
                child: Column(
                  children: _searchResults.map((place) {
                    final favorited = _isFavorited(place.displayName);
                    return ListTile(
                      leading: Icon(Icons.location_on_outlined, color: primary),
                      title: Text(place.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _addPlace(place),
                      trailing: IconButton(
                        icon: Icon(
                          favorited ? Icons.star : Icons.star_border,
                          color: favorited ? Colors.amber : Colors.grey,
                        ),
                        tooltip: favorited ? 'Remove from favorites' : 'Save as favorite',
                        onPressed: () => _toggleFavorite(place),
                      ),
                    );
                  }).toList(),
                ),
              )
            else if (_searchController.text.trim().length >= 1 &&
                _searchController.text.trim().length < 3)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Keep typing… (at least 3 letters)',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              )
            else if (_searchController.text.trim().length >= 3 &&
                !_isLoading &&
                _errorMessage == null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'No places found for "${_searchController.text.trim()}". '
                  'Try a nearby landmark or a different spelling.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ),

            const SizedBox(height: 20),

            // ---- Final destination ----
            Text('Final Destination', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_finalDestination == null)
              Card(
                color: Colors.orange.withOpacity(0.08),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Not set yet — search above and mark a place as your final destination.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.flag, color: Colors.white, size: 18),
                  ),
                  title: Text(_finalDestination!.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('No time spent here — it\'s your endpoint'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearFinalDestination,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ---- Stops along the way ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stops Along the Way', style: Theme.of(context).textTheme.titleMedium),
                Text('${_stops.length} added', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _useCustomOrder
                  ? 'Drag stops to set the order you need to visit them in. Tap to change dwell time.'
                  : 'Tap a stop to change how long you\'ll spend there.',
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            if (_stops.length >= 2)
              Card(
                color: _useCustomOrder ? Theme.of(context).colorScheme.primary.withOpacity(0.06) : null,
                child: SwitchListTile(
                  title: const Text('I need to visit these in a specific order', style: TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                    _useCustomOrder
                        ? 'Using your order below \u2014 we\'ll still show what the optimal order would look like.'
                        : 'Off: the app will find the fastest/cheapest/eco order for you.',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: _useCustomOrder,
                  onChanged: (value) => setState(() => _useCustomOrder = value),
                ),
              ),
            const SizedBox(height: 8),

            if (_stops.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No stops added yet', style: TextStyle(color: Colors.black54)),
                ),
              )
            else if (_useCustomOrder)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _stops.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _stops.removeAt(oldIndex);
                    _stops.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final dest = _stops[index];
                  return Card(
                    key: ValueKey('stop_${dest.name}_$index'),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primary,
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(dest.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${dest.dwellMinutes} minutes here'),
                      onTap: () => _editDwellTime(index),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _removeStop(index),
                          ),
                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              )
            else
              ..._stops.asMap().entries.map((entry) {
                final index = entry.key;
                final dest = entry.value;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primary,
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(dest.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${dest.dwellMinutes} minutes here'),
                    onTap: () => _editDwellTime(index),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeStop(index),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 20),


            // ---- Deadline ----
            Text('Arrival Deadline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.access_time),
              label: Text(_deadline == null ? 'Select a time' : 'Reach by ${_deadline!.format(context)}'),
            ),

            const SizedBox(height: 20),

            // ---- Optimization priority ----
            Text('Optimize For', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'The deadline is always respected — this only decides which feasible plan wins.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            SegmentedButton<OptimizationPriority>(
              segments: const [
                ButtonSegment(
                  value: OptimizationPriority.fastest,
                  label: Text('Fastest'),
                  icon: Icon(Icons.bolt, size: 18),
                ),
                ButtonSegment(
                  value: OptimizationPriority.cheapest,
                  label: Text('Cheapest'),
                  icon: Icon(Icons.payments_outlined, size: 18),
                ),
                ButtonSegment(
                  value: OptimizationPriority.eco,
                  label: Text('Eco'),
                  icon: Icon(Icons.eco_outlined, size: 18),
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (selection) => setState(() => _priority = selection.first),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _canContinue ? _onContinue : null,
            child: Text(_isEditing ? 'Update Route' : 'Optimize My Route'),
          ),
        ),
      ),
    );
  }
}