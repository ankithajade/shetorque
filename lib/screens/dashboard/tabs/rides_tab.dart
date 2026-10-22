import 'package:flutter/material.dart';
import '../../../theme/she_torque_theme.dart';
import '../../../widgets/ride_history_card.dart';
import '../../../repositories/rides_repository.dart';
import '../../../models/ride_model.dart';

/// Rides tab displaying tracked riding logs, distances, and safety scores
/// loaded from the Supabase `rides` table with full loading, error, and empty states.
class RidesTab extends StatefulWidget {
  final RidesRepository? repository;

  const RidesTab({super.key, this.repository});

  @override
  State<RidesTab> createState() => _RidesTabState();
}

class _RidesTabState extends State<RidesTab> {
  late final RidesRepository _repo;
  List<RideModel> _rides = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RidesRepository();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repo.getRides();
      if (mounted) {
        setState(() {
          _rides = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load ride logs. Please check your connection.';
        });
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${_monthName(dt.month)} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Jan';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRides,
      color: SheTorqueTheme.primaryCyan,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Rides & Telemetry',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: SheTorqueTheme.textWhite,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tracked ride distances, durations, and safety logs',
                    style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: SheTorqueTheme.primaryCyan),
                onPressed: _loadRides,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Loading State
          if (_isLoading) ...[
            const SizedBox(height: 60),
            const Center(
              child: CircularProgressIndicator(color: SheTorqueTheme.primaryCyan),
            ),
          ]

          // Error State
          else if (_errorMessage != null) ...[
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SheTorqueTheme.dangerRed.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded, color: SheTorqueTheme.dangerRed, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SheTorqueTheme.textWhite, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadRides,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SheTorqueTheme.primaryCyan,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry Loading'),
                  ),
                ],
              ),
            ),
          ]

          // Empty State
          else if (_rides.isEmpty) ...[
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SheTorqueTheme.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.route_rounded, color: SheTorqueTheme.primaryCyan, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Recorded Rides Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: SheTorqueTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start your next ride using the Safe Routing navigation to log journeys, track telemetry, and compute road safety scores.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ]

          // Loaded Rides List
          else ...[
            ..._rides.map((ride) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RideHistoryCard(
                    title: ride.title,
                    date: _formatDate(ride.startedAt),
                    distance: '${ride.distanceKm.toStringAsFixed(1)} km',
                    duration: '${ride.durationMin}m',
                    safetyScore: '${ride.safetyScore.toInt()}/100',
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
