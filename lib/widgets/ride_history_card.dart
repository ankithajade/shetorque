import 'package:flutter/material.dart';
import '../theme/she_torque_theme.dart';

/// Ride log card displaying ride title, date, distance, duration and safety score.
class RideHistoryCard extends StatelessWidget {
  final String title;
  final String date;
  final String distance;
  final String duration;
  final String safetyScore;

  const RideHistoryCard({
    super.key,
    required this.title,
    required this.date,
    required this.distance,
    required this.duration,
    required this.safetyScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SheTorqueTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.textWhite,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Safety $safetyScore',
                  style: const TextStyle(
                    fontSize: 11,
                    color: SheTorqueTheme.successGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style:
                const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Divider(color: SheTorqueTheme.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten_rounded,
                      size: 16, color: SheTorqueTheme.primaryCyan),
                  const SizedBox(width: 6),
                  Text(
                    distance,
                    style: const TextStyle(
                      color: SheTorqueTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 16, color: SheTorqueTheme.secondaryPink),
                  const SizedBox(width: 6),
                  Text(
                    duration,
                    style: const TextStyle(
                      color: SheTorqueTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
