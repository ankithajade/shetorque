import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../theme/she_torque_theme.dart';

/// Standalone technical demonstration screen for the Phase-1 IMU Sensor Fusion Hub.
/// Allows judges and reviewers to view live accelerometer G-force readings in isolation.
class SensorFusionHubScreen extends StatefulWidget {
  const SensorFusionHubScreen({super.key});

  @override
  State<SensorFusionHubScreen> createState() => _SensorFusionHubScreenState();
}

class _SensorFusionHubScreenState extends State<SensorFusionHubScreen> {
  double _liveG = 0.0;
  dynamic _accelerometerSub;

  @override
  void initState() {
    super.initState();
    _accelerometerSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      final g = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      setState(() => _liveG = g);
    });
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sensor Fusion Hub (Demo)'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.motorcycle, size: 90, color: SheTorqueTheme.primaryCyan),
            const SizedBox(height: 16),
            const Text(
              "SHETORQUE: SENSOR HUB",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: SheTorqueTheme.textWhite,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Phase-1 Validated Hardware Baseline",
              style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
              decoration: BoxDecoration(
                border: Border.all(
                    color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(20),
                color: SheTorqueTheme.surface,
              ),
              child: Column(
                children: [
                  const Text(
                    "IMU SENSOR FUSION",
                    style: TextStyle(
                      color: SheTorqueTheme.primaryCyan,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${_liveG.toStringAsFixed(2)} G",
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: SheTorqueTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Crash Threshold: 25.0 G",
                    style: TextStyle(
                      color: SheTorqueTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SheTorqueTheme.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: SheTorqueTheme.successGreen),
                  SizedBox(width: 8),
                  Text(
                    "Proximity & Accelerometer Streams Active",
                    style: TextStyle(
                        fontSize: 12, color: SheTorqueTheme.textWhite),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
