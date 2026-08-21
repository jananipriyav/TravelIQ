import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  bool _isLoading = true;
  String? _errorMessage;
  ProfileStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final stats = await _profileService.getProfileStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load your profile.';
        _isLoading = false;
      });
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ---- Header ----
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, primary.withOpacity(0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              _initials(_stats!.name.isEmpty ? _stats!.email : _stats!.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _stats!.name.isEmpty ? 'Traveler' : _stats!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _stats!.email,
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text('Your Travel Stats', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),

                    // ---- Stats grid ----
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            icon: Icons.route,
                            color: primary,
                            label: 'Trips Planned',
                            value: '${_stats!.totalTrips}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            label: 'On-Time Rate',
                            value: _stats!.totalTrips == 0
                                ? '—'
                                : '${((_stats!.onTimeTrips / _stats!.totalTrips) * 100).round()}%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            icon: Icons.timer_outlined,
                            color: Colors.deepOrange,
                            label: 'Total Travel Time',
                            value: '${_stats!.totalEstimatedMinutes.round()} min',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            icon: Icons.payments_outlined,
                            color: Colors.teal,
                            label: 'Total Est. Fare',
                            value: '\u20b9${_stats!.totalEstimatedCost.round()}',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    ),
                  ],
                ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}