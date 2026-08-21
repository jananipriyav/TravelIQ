import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileStats {
  final String name;
  final String email;
  final int totalTrips;
  final int onTimeTrips;
  final double totalEstimatedMinutes;
  final double totalEstimatedCost;

  ProfileStats({
    required this.name,
    required this.email,
    required this.totalTrips,
    required this.onTimeTrips,
    required this.totalEstimatedMinutes,
    required this.totalEstimatedCost,
  });
}

class ProfileService {
  final _client = Supabase.instance.client;

  Future<ProfileStats> getProfileStats() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in.');

    final profileRow = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    final tripsData = await _client
        .from('trips')
        .select('total_travel_minutes, estimated_cost, meets_deadline')
        .eq('user_id', user.id);

    final trips = tripsData as List;
    double totalMinutes = 0;
    double totalCost = 0;
    int onTime = 0;
    for (final t in trips) {
      totalMinutes += (t['total_travel_minutes'] as num?)?.toDouble() ?? 0;
      totalCost += (t['estimated_cost'] as num?)?.toDouble() ?? 0;
      if (t['meets_deadline'] == true) onTime++;
    }

    return ProfileStats(
      name: (profileRow?['name'] as String?) ?? '',
      email: (profileRow?['email'] as String?) ?? user.email ?? '',
      totalTrips: trips.length,
      onTimeTrips: onTime,
      totalEstimatedMinutes: totalMinutes,
      totalEstimatedCost: totalCost,
    );
  }
}