import 'package:flutter/material.dart';
import '../services/places_service.dart';

class SearchTestScreen extends StatefulWidget {
  const SearchTestScreen({super.key});

  @override
  State<SearchTestScreen> createState() => _SearchTestScreenState();
}

class _SearchTestScreenState extends State<SearchTestScreen> {
  final _searchController = TextEditingController();
  final _placesService = PlacesService();

  List<PlaceResult> _results = [];
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
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search a place',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _isLoading ? null : _search,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) const CircularProgressIndicator(),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final place = _results[index];
                  return ListTile(
                    title: Text(place.displayName),
                    subtitle: Text('Lat: ${place.lat}, Lon: ${place.lon}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}