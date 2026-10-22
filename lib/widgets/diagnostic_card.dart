import 'package:flutter/material.dart';
import '../theme/she_torque_theme.dart';

/// Telemetry metric card with icon, value, title, and progress bar,
/// preserving Nisarga's original card styling.
class DiagnosticCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final double progress;
  final Color progressColor;

  const DiagnosticCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
    required this.progressColor,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: SheTorqueTheme.textWhite,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: SheTorqueTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: SheTorqueTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
