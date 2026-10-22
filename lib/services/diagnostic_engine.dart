import '../models/ecu_data.dart';
import '../models/vehicle_health.dart';

/// Deterministic diagnostic evaluation engine that analyzes ECU telemetry
/// and produces explainable vehicle health states and recommendations.
///
/// Designed to be extensible so future statistical or ML anomaly detection
/// models can be plugged in seamlessly without modifying consumers.
class DiagnosticEngine {
  const DiagnosticEngine();

  /// Evaluates telemetry and outputs a complete [VehicleHealth] report.
  VehicleHealth evaluate(EcuData data) {
    int score = 100;
    final activeWarnings = <String>[];
    final criticalIssues = <String>[];
    final recommendations = <DiagnosticRecommendation>[];
    final now = DateTime.now();

    // ------------------------------------------------------------------------
    // 1. Thermal Analysis (Engine Head / Coolant Temperature)
    // ------------------------------------------------------------------------
    if (data.engineTempCelsius >= EcuThresholds.overheatTemp) {
      score -= 35;
      criticalIssues.add('Severe Engine Overheating');
      recommendations.add(
        DiagnosticRecommendation(
          id: 'REC_TEMP_CRITICAL',
          title: 'Immediate Engine Stop Recommended',
          reason:
              'Engine head temperature is ${data.engineTempCelsius.toStringAsFixed(1)}°C, exceeding maximum thermal threshold (≥ ${EcuThresholds.overheatTemp}°C). Prolonged operation risks cylinder warping or seizure.',
          action:
              'Safely pull over to the shoulder, cut the ignition immediately, and do not restart until the temperature drops below 85°C.',
          severity: RecommendationSeverity.critical,
          timestamp: now,
        ),
      );
    } else if (data.engineTempCelsius >= EcuThresholds.highTemp) {
      score -= 15;
      activeWarnings.add('Elevated Engine Temperature');
      recommendations.add(
        DiagnosticRecommendation(
          id: 'REC_TEMP_HIGH',
          title: 'Cooling Efficiency Check',
          reason:
              'Engine temperature is elevated at ${data.engineTempCelsius.toStringAsFixed(1)}°C (normal operating range is 75°C - 95°C).',
          action:
              'Avoid aggressive acceleration, downshift gently, and check coolant reservoir level at your next stop.',
          severity: RecommendationSeverity.medium,
          timestamp: now,
        ),
      );
    }

    // ------------------------------------------------------------------------
    // 2. Electrical System Analysis (Stator & Battery Terminal Voltage)
    // ------------------------------------------------------------------------
    if (data.batteryVoltage <= EcuThresholds.criticalVoltage) {
      score -= 30;
      criticalIssues.add('Critical Battery Voltage Drop');
      recommendations.add(
        DiagnosticRecommendation(
          id: 'REC_VOLT_CRITICAL',
          title: 'Alternator / Battery Fault Detected',
          reason:
              'Terminal voltage is critically low at ${data.batteryVoltage.toStringAsFixed(2)}V (minimum operating threshold is ${EcuThresholds.criticalVoltage}V). Ignition and fuel injection may cut out.',
          action:
              'Turn off auxiliary fog lamps and USB chargers immediately. Head to the nearest service bay before turning the bike off.',
          severity: RecommendationSeverity.critical,
          timestamp: now,
        ),
      );
    } else if (data.batteryVoltage <= EcuThresholds.lowVoltage) {
      score -= 15;
      activeWarnings.add('Low Battery Voltage');
      recommendations.add(
        DiagnosticRecommendation(
          id: 'REC_VOLT_LOW',
          title: 'Battery Discharge Warning',
          reason:
              'Terminal voltage is ${data.batteryVoltage.toStringAsFixed(2)}V, below the healthy resting threshold (${EcuThresholds.lowVoltage}V).',
          action:
              'Maintain steady cruising RPM to allow stator charging, and test battery health with a multimeter.',
          severity: RecommendationSeverity.medium,
          timestamp: now,
        ),
      );
    } else if (data.batteryVoltage >= EcuThresholds.overchargeVoltage) {
      score -= 20;
      activeWarnings.add('Voltage Regulator Overcharge');
      recommendations.add(
        DiagnosticRecommendation(
          id: 'REC_VOLT_HIGH',
          title: 'Regulator / Rectifier Overcharging',
          reason:
              'Terminal voltage is spike-charging at ${data.batteryVoltage.toStringAsFixed(2)}V (safe limit ≤ ${EcuThresholds.overchargeVoltage}V), risking battery boiling and ECU damage.',
          action:
              'Inspect voltage regulator-rectifier (RR unit) wiring and grounding at the next maintenance stop.',
          severity: RecommendationSeverity.high,
          timestamp: now,
        ),
      );
    }

    // ------------------------------------------------------------------------
    // 3. Fuel Reserve & Range Analysis
    // ------------------------------------------------------------------------
    if (data.fuelLevelPercent <= EcuThresholds.criticalFuel) {
      score -= 20;
      criticalIssues.add('Fuel Reserve Exhausted');
      recommendations.add(
        DiagnosticRecommendation(
          id: 'REC_FUEL_CRITICAL',
          title: 'Immediate Refueling Required',
          reason:
              'Fuel level is at ${data.fuelLevelPercent.toStringAsFixed(1)}% (critical reserve ≤ ${EcuThresholds.criticalFuel}%). Fuel pump may suck air and overheat.',
          action:
              'Navigate to the closest refueling station immediately. Avoid high-RPM pulls.',
          severity: RecommendationSeverity.high,
          timestamp: now,
        ),
      );
    } else if (data.fuelLevelPercent <= EcuThresholds.lowFuel) {
      score -= 10;
      activeWarnings.add('Low Fuel Warning');
      recommendations.add(
        DiagnosticRecommendation(
          id: 'REC_FUEL_LOW',
          title: 'Reserve Fuel Reached',
          reason:
              'Fuel level has dipped to ${data.fuelLevelPercent.toStringAsFixed(1)}% (reserve threshold is ${EcuThresholds.lowFuel}%). Estimated remaining range: ~25-35 km.',
          action:
              'Plan a refueling stop along your safe route in the next 20 kilometers.',
          severity: RecommendationSeverity.low,
          timestamp: now,
        ),
      );
    }

    // ------------------------------------------------------------------------
    // 4. Combine Warnings from EcuData
    // ------------------------------------------------------------------------
    for (final w in data.warnings) {
      if (!activeWarnings.contains(w) && !criticalIssues.contains(w)) {
        if (w.startsWith('CRITICAL')) {
          criticalIssues.add(w);
        } else {
          activeWarnings.add(w);
        }
      }
    }

    // Clamp score to strictly valid range [0, 100]
    final clampedScore = score.clamp(0, 100);

    // Determine Status
    final VehicleHealthStatus status;
    if (criticalIssues.isNotEmpty || clampedScore < 50) {
      status = VehicleHealthStatus.critical;
    } else if (activeWarnings.isNotEmpty || clampedScore < 75) {
      status = VehicleHealthStatus.warning;
    } else if (clampedScore < 90) {
      status = VehicleHealthStatus.good;
    } else {
      status = VehicleHealthStatus.optimal;
    }

    return VehicleHealth(
      overallScore: clampedScore,
      status: status,
      activeWarnings: activeWarnings,
      criticalIssues: criticalIssues,
      recommendations: recommendations,
      timestamp: now,
    );
  }
}
