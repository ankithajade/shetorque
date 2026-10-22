import 'package:flutter/material.dart';
import '../../../theme/she_torque_theme.dart';
import '../../../models/rider_profile.dart';
import '../../../models/bike_info.dart';
import '../../../models/ecu_data.dart';
import '../../../models/vehicle_health.dart';
import '../../../services/bike_telemetry_calculator.dart';
import '../../../widgets/diagnostic_card.dart';

/// Garage tab displaying rider greeting, motorcycle overview, live streamed telemetry cards,
/// emergency SOS card, and quick action shortcuts.
class GarageTab extends StatelessWidget {
  final RiderProfile rider;
  final BikeInfo bike;
  final EcuData ecuData;
  final VehicleHealth vehicleHealth;
  final VoidCallback onSosPressed;
  final void Function(int tabIndex)? onNavigateTab;
  final VoidCallback? onSafetyHubPressed;
  final VoidCallback? onGuardianEyePressed;

  const GarageTab({
    super.key,
    required this.rider,
    required this.bike,
    required this.ecuData,
    required this.vehicleHealth,
    required this.onSosPressed,
    this.onNavigateTab,
    this.onSafetyHubPressed,
    this.onGuardianEyePressed,
  });

  Widget _buildQuickStat({
    required String label,
    required String value,
    bool isAccent = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isAccent
                ? SheTorqueTheme.warningAmber
                : SheTorqueTheme.textWhite,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: SheTorqueTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SheTorqueTheme.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SheTorqueTheme.textWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: SheTorqueTheme.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = rider.name.split(' ').first;
    final hasWarnings = ecuData.warnings.isNotEmpty || ecuData.dtcCodes.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      children: [
        // Rider Greeting
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $firstName 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: SheTorqueTheme.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ECU Streaming (${ecuData.rpm} RPM) • IMU Active',
                      style: const TextStyle(
                          fontSize: 12.5, color: SheTorqueTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: SheTorqueTheme.border),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: SheTorqueTheme.textWhite, size: 22),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Bike Showcase Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F2937), Color(0xFF111827)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                SheTorqueTheme.primaryCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            bike.brand.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: SheTorqueTheme.primaryCyan,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bike.model,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: SheTorqueTheme.textWhite,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                bike.regNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${bike.year}',
                              style: const TextStyle(
                                  color: SheTorqueTheme.textMuted,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SheTorqueTheme.border),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded,
                        size: 40, color: SheTorqueTheme.primaryCyan),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: SheTorqueTheme.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickStat(label: 'Odometer', value: bike.odometer),
                  _buildQuickStat(
                    label: 'Live Speed',
                    value: '${ecuData.speedKmH.toStringAsFixed(0)} km/h',
                    isAccent: ecuData.speedKmH > 0,
                  ),
                  _buildQuickStat(
                    label: 'Health Score',
                    value: '${vehicleHealth.overallScore}%',
                    isAccent: vehicleHealth.overallScore < 75,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Live Warning / DTC Banner (Only shown when threshold alerts are triggered)
        if (hasWarnings) ...[
          InkWell(
            onTap: () => onNavigateTab?.call(3),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SheTorqueTheme.dangerRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: SheTorqueTheme.dangerRed.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: SheTorqueTheme.dangerRed, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ecuData.warnings.isNotEmpty
                              ? ecuData.warnings.first
                              : 'Diagnostic Trouble Detected',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (ecuData.dtcCodes.isNotEmpty)
                          Text(
                            ecuData.dtcCodes.first,
                            style: const TextStyle(
                              fontSize: 12,
                              color: SheTorqueTheme.warningAmber,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white54, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Emergency SOS Card
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onSosPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SheTorqueTheme.dangerRed.withValues(alpha: 0.25),
                  const Color(0xFF3B0B14),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: SheTorqueTheme.dangerRed.withValues(alpha: 0.8),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: SheTorqueTheme.dangerRed.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.dangerRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SheTorqueTheme.dangerRed.withValues(alpha: 0.6),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.sos_rounded, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY CRASH ALERT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Hardware IMU 25G & Proximity Sensor Armed',
                        style: TextStyle(
                            fontSize: 12, color: SheTorqueTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Safety Feature Navigation Cards ──────────────────────────────
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.security_rounded,
                label: 'Safety Hub',
                sublabel: 'Crash & Silent SOS',
                color: SheTorqueTheme.dangerRed,
                onTap: onSafetyHubPressed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.remove_red_eye_rounded,
                label: 'Guardian Eye',
                sublabel: 'Vehicle Tracking',
                color: SheTorqueTheme.warningAmber,
                onTap: onGuardianEyePressed,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // Section: Vehicle Diagnostics (Live Telemetry metrics)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Vehicle Diagnostics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: SheTorqueTheme.textWhite,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SheTorqueTheme.warningAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_rounded,
                      size: 13, color: SheTorqueTheme.warningAmber),
                  SizedBox(width: 4),
                  Text(
                    'SIMULATED ECU',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: SheTorqueTheme.warningAmber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ELM327 connection status row (A3)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: SheTorqueTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SheTorqueTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.bluetooth_disabled_rounded,
                  size: 15, color: SheTorqueTheme.textMuted),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ELM327 adapter: not connected \u2014 using simulator',
                  style: TextStyle(
                      fontSize: 11.5, color: SheTorqueTheme.textMuted),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.warningAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SIMULATED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.warningAmber,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Telemetry Grid (Row 1: Fuel & Engine Temp)
        Row(
          children: [
            // Fuel Level
            Expanded(
              child: DiagnosticCard(
                icon: Icons.local_gas_station_rounded,
                iconColor: ecuData.fuelLevelPercent <= EcuThresholds.lowFuel
                    ? SheTorqueTheme.dangerRed
                    : SheTorqueTheme.primaryCyan,
                title: 'Fuel Level',
                value: '${ecuData.fuelLevelPercent.toStringAsFixed(1)}%',
                subtitle: ecuData.fuelLevelPercent <= EcuThresholds.lowFuel
                    ? 'Reserve Warning'
                    : 'Est. Range ~${(ecuData.fuelLevelPercent * 3.6).toInt()} km',
                progress: ecuData.fuelLevelPercent / 100,
                progressColor: ecuData.fuelLevelPercent <= EcuThresholds.lowFuel
                    ? SheTorqueTheme.dangerRed
                    : SheTorqueTheme.primaryCyan,
              ),
            ),
            const SizedBox(width: 12),
            // Engine Temp
            Expanded(
              child: DiagnosticCard(
                icon: Icons.thermostat_rounded,
                iconColor: ecuData.engineTempCelsius >= EcuThresholds.highTemp
                    ? SheTorqueTheme.dangerRed
                    : SheTorqueTheme.warningAmber,
                title: 'Engine Temp',
                value: '${ecuData.engineTempCelsius.toStringAsFixed(1)}°C',
                subtitle: ecuData.engineTempCelsius >= EcuThresholds.overheatTemp
                    ? 'CRITICAL OVERHEAT'
                    : (ecuData.engineTempCelsius >= EcuThresholds.highTemp
                        ? 'High Operating Temp'
                        : 'Optimal (75-95°C)'),
                progress: (ecuData.engineTempCelsius / 130).clamp(0.0, 1.0),
                progressColor:
                    ecuData.engineTempCelsius >= EcuThresholds.highTemp
                        ? SheTorqueTheme.dangerRed
                        : SheTorqueTheme.warningAmber,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Telemetry Grid (Row 2: Battery Voltage & Engine RPM)
        Row(
          children: [
            // Battery Voltage
            Expanded(
              child: DiagnosticCard(
                icon: Icons.battery_charging_full_rounded,
                iconColor: ecuData.batteryVoltage <= EcuThresholds.lowVoltage
                    ? SheTorqueTheme.dangerRed
                    : SheTorqueTheme.successGreen,
                title: 'Battery Voltage',
                value: '${ecuData.batteryVoltage.toStringAsFixed(2)}V',
                subtitle: ecuData.batteryVoltage <= EcuThresholds.criticalVoltage
                    ? 'Critical Voltage'
                    : (ecuData.batteryVoltage <= EcuThresholds.lowVoltage
                        ? 'Low Discharge'
                        : 'Healthy Alternator'),
                progress:
                    ((ecuData.batteryVoltage - 10) / 4.6).clamp(0.0, 1.0),
                progressColor:
                    ecuData.batteryVoltage <= EcuThresholds.lowVoltage
                        ? SheTorqueTheme.dangerRed
                        : SheTorqueTheme.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            // Engine RPM
            Expanded(
              child: DiagnosticCard(
                icon: Icons.speed_rounded,
                iconColor: SheTorqueTheme.secondaryPink,
                title: 'Engine Speed',
                value: '${ecuData.rpm}',
                subtitle: ecuData.rpm < 1500 ? 'Idle RPM' : 'Cruise Power',
                progress: (ecuData.rpm / 9000).clamp(0.0, 1.0),
                progressColor: SheTorqueTheme.secondaryPink,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Telemetry Intelligence (fuel range, alerts, service) ──
        _buildTelemetryIntelligenceSection(bike),

        const SizedBox(height: 24),

        // Quick Actions
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: SheTorqueTheme.textWhite,
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.map_rounded,
                label: 'Safe Routing',
                color: SheTorqueTheme.primaryCyan,
                onTap: () => onNavigateTab?.call(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.analytics_rounded,
                label: 'Diagnostics',
                color: SheTorqueTheme.secondaryPink,
                onTap: () => onNavigateTab?.call(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.history_rounded,
                label: 'Rides Log',
                color: SheTorqueTheme.accentPurple,
                onTap: () => onNavigateTab?.call(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.people_alt_rounded,
                label: 'HerRide',
                color: SheTorqueTheme.warningAmber,
                onTap: () => onNavigateTab?.call(4),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  /// Builds the BikeTelemetryCalculator-driven intelligence cards.
  Widget _buildTelemetryIntelligenceSection(BikeInfo bikeInfo) {
    final rangeKm = BikeTelemetryCalculator.calculateRemainingRangeKm(
      fuelCapacityL: bikeInfo.fuelCapacityL,
      avgMileageKmpl: bikeInfo.avgMileageKmpl,
      fuelLevelPercent: ecuData.fuelLevelPercent,
    );
    final alertLevel = BikeTelemetryCalculator.getFuelAlertLevel(
      ecuData.fuelLevelPercent,
    );
    final serviceDueKm = BikeTelemetryCalculator.calculateServiceDueInKm(
      currentOdometerKm: bikeInfo.odometerKm,
      lastServiceKm: bikeInfo.lastServiceKm,
    );
    final serviceOverdue = BikeTelemetryCalculator.isServiceOverdue(
      currentOdometerKm: bikeInfo.odometerKm,
      lastServiceKm: bikeInfo.lastServiceKm,
    );
    final serviceText = BikeTelemetryCalculator.getServiceStatusText(
      currentOdometerKm: bikeInfo.odometerKm,
      lastServiceKm: bikeInfo.lastServiceKm,
    );

    final Color alertColor = alertLevel == FuelAlertLevel.critical
        ? SheTorqueTheme.dangerRed
        : alertLevel == FuelAlertLevel.advisory
            ? SheTorqueTheme.warningAmber
            : SheTorqueTheme.successGreen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ride Intelligence',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: SheTorqueTheme.textWhite,
          ),
        ),
        const SizedBox(height: 10),

        // Fuel Range Estimate
        _buildIntelCard(
          icon: Icons.local_gas_station_rounded,
          iconColor: SheTorqueTheme.primaryCyan,
          title: 'Estimated Fuel Range',
          value: '${rangeKm.toStringAsFixed(0)} km',
          subtitle:
              'Based on ${bikeInfo.fuelCapacityL.toStringAsFixed(0)}L tank @ ${bikeInfo.avgMileageKmpl.toStringAsFixed(0)} km/L avg',
        ),
        const SizedBox(height: 10),

        // Fuel Alert (50% / 75% consumed)
        if (alertLevel != FuelAlertLevel.none)
          _buildIntelCard(
            icon: alertLevel == FuelAlertLevel.critical
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            iconColor: alertColor,
            title: alertLevel == FuelAlertLevel.critical
                ? 'CRITICAL FUEL ALERT'
                : 'Fuel Advisory',
            value: alertLevel == FuelAlertLevel.critical
                ? '≥25% tank remaining'
                : '≥50% tank remaining',
            subtitle:
                '${BikeTelemetryCalculator.calculateFuelConsumedPercent(ecuData.fuelLevelPercent).toStringAsFixed(0)}% consumed — consider refuelling soon',
            borderColor: alertColor,
          ),
        if (alertLevel != FuelAlertLevel.none) const SizedBox(height: 10),

        // Service interval card
        _buildIntelCard(
          icon: serviceOverdue
              ? Icons.build_circle_rounded
              : Icons.build_outlined,
          iconColor: serviceOverdue
              ? SheTorqueTheme.dangerRed
              : SheTorqueTheme.primaryCyan,
          title: 'Service Interval (3,000 km)',
          value: serviceOverdue
              ? 'OVERDUE'
              : '${serviceDueKm.toStringAsFixed(0)} km',
          subtitle: serviceText,
          borderColor: serviceOverdue
              ? SheTorqueTheme.dangerRed.withValues(alpha: 0.6)
              : null,
        ),
      ],
    );
  }

  Widget _buildIntelCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? SheTorqueTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 11.5, color: SheTorqueTheme.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: SheTorqueTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
