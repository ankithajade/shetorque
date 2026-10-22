import 'package:flutter/material.dart';
import '../../../theme/she_torque_theme.dart';
import '../../../widgets/ride_history_card.dart';

/// Rides tab showing tracked riding logs, distances, and safety scores.
class RidesTab extends StatelessWidget {
  const RidesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: const [
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
        SizedBox(height: 20),

        RideHistoryCard(
          title: 'Nandi Hills Sunrise Ride',
          date: 'Yesterday, 05:30 AM',
          distance: '118.4 km',
          duration: '2h 45m',
          safetyScore: '98/100',
        ),
        SizedBox(height: 12),
        RideHistoryCard(
          title: 'City Commute - Outer Ring Rd',
          date: 'Sep 02, 2026',
          distance: '24.2 km',
          duration: '48m',
          safetyScore: '94/100',
        ),
        SizedBox(height: 12),
        RideHistoryCard(
          title: 'Weekend Ghats Exploration',
          date: 'Aug 28, 2026',
          distance: '264.0 km',
          duration: '5h 12m',
          safetyScore: '96/100',
        ),
      ],
    );
  }
}
