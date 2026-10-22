import 'package:flutter/material.dart';
import '../../../theme/she_torque_theme.dart';

/// HerRide Community tab — initial Phase-1 scaffold presenting group rides,
/// safety advisories, and community announcements.
class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HerRide Community',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sisterhood on two wheels • Peer safety network',
                  style:
                      TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        SheTorqueTheme.secondaryPink.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'PHASE 2 PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.secondaryPink,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Upcoming Group Ride Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1124), Color(0xFF161B22)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          SheTorqueTheme.secondaryPink.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_rounded,
                        color: SheTorqueTheme.secondaryPink, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Weekend Sunrise Breakfast Ride',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '14 Riders',
                      style: TextStyle(
                        fontSize: 11,
                        color: SheTorqueTheme.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Bengaluru to Kolar CCD • Convoy tracking & real-time SOS relay enabled.',
                style: TextStyle(fontSize: 13, color: SheTorqueTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      size: 14, color: SheTorqueTheme.textMuted),
                  const SizedBox(width: 6),
                  const Text('Sunday, 06:00 AM',
                      style: TextStyle(
                          fontSize: 12, color: SheTorqueTheme.textMuted)),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SheTorqueTheme.secondaryPink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'HerRide Convoy RSVP will open in Phase 2.'),
                        ),
                      );
                    },
                    child: const Text('RSVP',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Pink Spot / Road Hazard Advisory Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SheTorqueTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SheTorqueTheme.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: SheTorqueTheme.primaryCyan, size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pink Spot Safety Network',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Verified female-friendly pitstops, fuel stations, and emergency mechanic safe havens.',
                      style: TextStyle(
                          fontSize: 12, color: SheTorqueTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
