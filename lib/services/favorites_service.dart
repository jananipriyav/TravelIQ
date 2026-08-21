import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritePlace {
  final String id;
  final String name;
  final double lat;
  final double lon;

  FavoritePlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });
}

class FavoritesService {
  final _client = Supabase.instance.client;

  Future<List<FavoritePlace>> getFavorites() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('favorite_places')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => FavoritePlace(
              id: row['id'],
              name: row['name'] ?? '',
              lat: (row['lat'] as num?)?.toDouble() ?? 0,
              lon: (row['lon'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Future<void> addFavorite({
    required String name,
    required double lat,
    required double lon,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('You must be logged in to save a favorite.');

    await _client.from('favorite_places').insert({
      'user_id': userId,
      'name': name,
      'lat': lat,
      'lon': lon,
    });
  }

  Future<void> removeFavorite(String id) async {
    await _client.from('favorite_places').delete().eq('id', id);
  }
}