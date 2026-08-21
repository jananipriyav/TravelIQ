import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'map_screen.dart';
import 'add_destinations_screen.dart';
import 'itinerary_screen.dart';
import 'travel_history_screen.dart';
import 'profile_screen.dart';
import '../models/destination.dart';
import '../services/location_service.dart';
import '../utils/error_messages.dart';
import '../services/transport_advisor.dart';

/// The app's main shell after login — a persistent bottom navigation bar
/// hosting Home, Travel History, and Profile as tabs, with "Plan a Trip"
/// as the primary floating action on the Home tab. This is the standard
/// pattern used by most polished travel/ride-hailing apps, replacing the
/// earlier "everything is a pushed screen" navigation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Future<void> _startTripPlanning(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => const AddDestinationsScreen()),
    );
    if (result == null) return;
    if (!context.mounted) return;

    final stops = result['stops'] as List<Destination>;
    final finalDestination = result['finalDestination'] as Destination;
    final deadline = result['deadline'] as TimeOfDay;
    final priority = result['priority'] as OptimizationPriority? ?? OptimizationPriority.fastest;
    final useCustomOrder = result['useCustomOrder'] as bool? ?? false;

    try {
      final position = await LocationService().getCurrentLocation();
      final start = Destination(
        name: 'Current Location',
        lat: position.latitude,
        lon: position.longitude,
      );

      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ItineraryScreen(
            start: start,
            stops: stops,
            finalDestination: finalDestination,
            deadline: deadline,
            priority: priority,
            useCustomOrder: useCustomOrder,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final tabs = [
      _DashboardTab(onPlanTrip: () => _startTripPlanning(context)),
      const TravelHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _startTripPlanning(context),
              icon: const Icon(Icons.route),
              label: const Text('Plan a Trip'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: primary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// The Home tab's dashboard content — greeting, and quick access to the
/// two most-used actions. History and Profile now live as their own tabs
/// instead of being buried as action cards here.
class _DashboardTab extends StatefulWidget {
  final VoidCallback onPlanTrip;
  const _DashboardTab({required this.onPlanTrip});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        final name = profile?['name'] as String?;
        _displayName = (name != null && name.trim().isNotEmpty) ? name : null;
      });
    } catch (_) {
      // Falls back to email in the UI below — not worth an error for a greeting.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final primary = Theme.of(context).colorScheme.primary;
    final greetingName = _displayName ?? user?.email ?? 'User';
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Travel Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$timeGreeting,',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greetingName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Where are you headed today? Let\'s plan the fastest way to get it all done.',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            _actionCard(
              context,
              icon: Icons.route,
              iconColor: primary,
              title: 'Plan a Trip',
              subtitle: 'Add destinations, set a deadline, get an optimized route',
              onTap: widget.onPlanTrip,
            ),
            const SizedBox(height: 12),
            _actionCard(
              context,
              icon: Icons.my_location,
              iconColor: Colors.teal,
              title: 'View My Location',
              subtitle: 'See where you are right now on the map',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
            ),

            const SizedBox(height: 28),
            Text('Tip', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Enable departure reminders on your itinerary so you never lose track of time between stops.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.4),
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

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}