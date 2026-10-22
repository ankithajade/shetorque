import 'package:flutter/material.dart';
import '../../../theme/she_torque_theme.dart';
import '../../../models/rider_profile.dart';
import '../../../models/ecu_data.dart';
import '../../../models/vehicle_health.dart';
import '../../../services/mock_ecu_service.dart';

/// Diagnostics tab displaying real-time OBD-II telemetry parameters,
/// standardized DTC error codes, calculated vehicle health scores,
/// and explainable diagnostic recommendations.
class DiagnosticsTab extends StatefulWidget {
  final RiderProfile rider;
  final EcuData ecuData;
  final VehicleHealth vehicleHealth;

  const DiagnosticsTab({
    super.key,
    required this.rider,
    required this.ecuData,
    required this.vehicleHealth,
  });

  @override
  State<DiagnosticsTab> createState() => _DiagnosticsTabState();
}

class _DiagnosticsTabState extends State<DiagnosticsTab> {
  bool _showSimControls = false;

  Color _getScoreColor(int score) {
    if (score >= 90) return SheTorqueTheme.successGreen;
    if (score >= 75) return SheTorqueTheme.primaryCyan;
    if (score >= 50) return SheTorqueTheme.warningAmber;
    return SheTorqueTheme.dangerRed;
  }

  Widget _buildDiagnosticDetailRow(String label, String value,
      {bool isWarning = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWarning
              ? SheTorqueTheme.dangerRed.withValues(alpha: 0.5)
              : SheTorqueTheme.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: SheTorqueTheme.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: isWarning
                  ? SheTorqueTheme.warningAmber
                  : SheTorqueTheme.textWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(DiagnosticRecommendation rec) {
    final Color color;
    switch (rec.severity) {
      case RecommendationSeverity.critical:
        color = SheTorqueTheme.dangerRed;
        break;
      case RecommendationSeverity.high:
        color = const Color(0xFFFF5252);
        break;
      case RecommendationSeverity.medium:
        color = SheTorqueTheme.warningAmber;
        break;
      case RecommendationSeverity.low:
        color = SheTorqueTheme.primaryCyan;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rec.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rec.severity.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rec.reason,
            style: const TextStyle(
              fontSize: 12.5,
              color: SheTorqueTheme.textWhite,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.build_circle_outlined,
                    color: SheTorqueTheme.primaryCyan, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec.action,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SheTorqueTheme.textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ecu = widget.ecuData;
    final health = widget.vehicleHealth;
    final scoreColor = _getScoreColor(health.overallScore);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OBD-II Diagnostics',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Live Telemetry & Diagnostic Health Engine',
                  style:
                      TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                _showSimControls
                    ? Icons.tune_rounded
                    : Icons.tune_outlined,
                color: _showSimControls
                    ? SheTorqueTheme.primaryCyan
                    : SheTorqueTheme.textMuted,
              ),
              tooltip: 'Simulation Controls',
              onPressed: () {
                setState(() => _showSimControls = !_showSimControls);
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Simulation Fault Trigger Controls (Collapsible for test/demo)
        if (_showSimControls) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.science_rounded,
                        color: SheTorqueTheme.primaryCyan, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'ECU Simulation Control Panel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.primaryCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: Text(MockEcuService.instance.forceOverheat
                          ? 'Cool Down'
                          : 'Simulate Overheat'),
                      backgroundColor: MockEcuService.instance.forceOverheat
                          ? SheTorqueTheme.dangerRed.withValues(alpha: 0.3)
                          : SheTorqueTheme.surface,
                      labelStyle: const TextStyle(fontSize: 11.5, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          MockEcuService.instance.forceOverheat =
                              !MockEcuService.instance.forceOverheat;
                        });
                      },
                    ),
                    ActionChip(
                      label: Text(MockEcuService.instance.forceLowBattery
                          ? 'Charge Battery'
                          : 'Simulate Low Volt'),
                      backgroundColor: MockEcuService.instance.forceLowBattery
                          ? SheTorqueTheme.dangerRed.withValues(alpha: 0.3)
                          : SheTorqueTheme.surface,
                      labelStyle: const TextStyle(fontSize: 11.5, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          MockEcuService.instance.forceLowBattery =
                              !MockEcuService.instance.forceLowBattery;
                        });
                      },
                    ),
                    ActionChip(
                      label: Text(MockEcuService.instance.forceLowFuel
                          ? 'Refuel'
                          : 'Simulate Low Fuel'),
                      backgroundColor: MockEcuService.instance.forceLowFuel
                          ? SheTorqueTheme.dangerRed.withValues(alpha: 0.3)
                          : SheTorqueTheme.surface,
                      labelStyle: const TextStyle(fontSize: 11.5, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          MockEcuService.instance.forceLowFuel =
                              !MockEcuService.instance.forceLowFuel;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Reset Baseline'),
                      backgroundColor: SheTorqueTheme.primaryCyan.withValues(alpha: 0.2),
                      labelStyle: const TextStyle(
                          fontSize: 11.5, color: SheTorqueTheme.primaryCyan),
                      onPressed: () {
                        setState(() {
                          MockEcuService.instance.reset();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Overall Vehicle Health Score Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: SheTorqueTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: scoreColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withValues(alpha: 0.15),
                  border: Border.all(color: scoreColor, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    '${health.overallScore}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      health.statusLabel,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      health.criticalIssues.isNotEmpty
                          ? '${health.criticalIssues.length} critical fault(s) detected'
                          : (health.activeWarnings.isNotEmpty
                              ? '${health.activeWarnings.length} warning flag(s) active'
                              : 'All telemetry parameters within optimal operating limits'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SheTorqueTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Live Parameter Breakdown
        const Text(
          'Live Telemetry Parameters',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: SheTorqueTheme.textWhite,
          ),
        ),
        const SizedBox(height: 12),

        _buildDiagnosticDetailRow(
          'Fuel Tank Level',
          '${ecu.fuelLevelPercent.toStringAsFixed(1)}% [${(ecu.fuelLevelPercent * 0.135).toStringAsFixed(1)}L / 13.5L]',
          isWarning: ecu.fuelLevelPercent <= EcuThresholds.lowFuel,
        ),
        _buildDiagnosticDetailRow(
          'Engine Coolant / Head Temp',
          '${ecu.engineTempCelsius.toStringAsFixed(1)}°C',
          isWarning: ecu.engineTempCelsius >= EcuThresholds.highTemp,
        ),
        _buildDiagnosticDetailRow(
          'Electrical Stator & Battery',
          '${ecu.batteryVoltage.toStringAsFixed(2)}V',
          isWarning: ecu.batteryVoltage <= EcuThresholds.lowVoltage,
        ),
        _buildDiagnosticDetailRow(
          'Engine RPM (PID 0x0C)',
          '${ecu.rpm} RPM',
        ),
        _buildDiagnosticDetailRow(
          'Vehicle Ground Speed (PID 0x0D)',
          '${ecu.speedKmH.toStringAsFixed(1)} km/h',
        ),
        _buildDiagnosticDetailRow(
          'Diagnostic Trouble Codes (DTC)',
          ecu.dtcCodes.isEmpty
              ? 'None (0 DTCs detected)'
              : ecu.dtcCodes.join(', '),
          isWarning: ecu.dtcCodes.isNotEmpty,
        ),
        _buildDiagnosticDetailRow(
          'IMU Crash Accelerometer',
          'Streaming via sensors_plus',
        ),
        _buildDiagnosticDetailRow(
          'Crash Threshold Constant',
          '25.0 G (Trigger Limit)',
        ),
        _buildDiagnosticDetailRow(
          'Native SMS Emergency Route',
          '${widget.rider.emergencyContactPhone} (Active)',
        ),

        const SizedBox(height: 24),

        // Explainable Recommendations Section
        const Text(
          'Diagnostic Intelligence & Recommendations',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: SheTorqueTheme.textWhite,
          ),
        ),
        const SizedBox(height: 12),

        if (health.recommendations.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SheTorqueTheme.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: SheTorqueTheme.successGreen, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No diagnostic faults found. Your motorcycle is in optimal riding condition.',
                    style: TextStyle(
                        color: SheTorqueTheme.textWhite, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          ...health.recommendations
              .map((rec) => _buildRecommendationCard(rec)),

        const SizedBox(height: 24),
      ],
    );
  }
}
