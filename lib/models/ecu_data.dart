/// A single snapshot of motorcycle ECU telemetry data.
class EcuData {
  final double fuelLevelPercent; // 0 - 100%
  final double engineTempCelsius; // Typical idle->cruise range: ~70 - 105°C
  final double batteryVoltage; // Typical healthy range: ~12.0 - 14.4V
  final int rpm; // Engine revolutions per minute (~1,200 - 9,000)
  final double speedKmH; // Vehicle speed in km/h
  final List<String> warnings; // Active diagnostic threshold warnings
  final List<String> dtcCodes; // Diagnostic Trouble Codes (SAE J2012 format)
  final DateTime timestamp;

  const EcuData({
    required this.fuelLevelPercent,
    required this.engineTempCelsius,
    required this.batteryVoltage,
    this.rpm = 0,
    this.speedKmH = 0.0,
    required this.warnings,
    this.dtcCodes = const [],
    required this.timestamp,
  });

  EcuData copyWith({
    double? fuelLevelPercent,
    double? engineTempCelsius,
    double? batteryVoltage,
    int? rpm,
    double? speedKmH,
    List<String>? warnings,
    List<String>? dtcCodes,
    DateTime? timestamp,
  }) {
    final fuel = fuelLevelPercent ?? this.fuelLevelPercent;
    final temp = engineTempCelsius ?? this.engineTempCelsius;
    final voltage = batteryVoltage ?? this.batteryVoltage;

    return EcuData(
      fuelLevelPercent: fuel,
      engineTempCelsius: temp,
      batteryVoltage: voltage,
      rpm: rpm ?? this.rpm,
      speedKmH: speedKmH ?? this.speedKmH,
      warnings: warnings ?? EcuThresholds.evaluate(fuel, temp, voltage),
      dtcCodes: dtcCodes ?? EcuThresholds.evaluateDtc(fuel, temp, voltage),
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'EcuData(fuel: ${fuelLevelPercent.toStringAsFixed(1)}%, '
      'temp: ${engineTempCelsius.toStringAsFixed(1)}°C, '
      'voltage: ${batteryVoltage.toStringAsFixed(2)}V, '
      'rpm: $rpm, '
      'speed: ${speedKmH.toStringAsFixed(1)} km/h, '
      'warnings: $warnings, '
      'dtc: $dtcCodes)';
}

/// Thresholds defining normal operating envelopes and triggering diagnostic warning flags.
/// Sourced and preserved from ref/bhavana-mock-ecu.
class EcuThresholds {
  static const double lowFuel = 15.0;
  static const double criticalFuel = 5.0;
  static const double highTemp = 105.0;
  static const double overheatTemp = 115.0;
  static const double lowVoltage = 11.8;
  static const double criticalVoltage = 11.2;
  static const double overchargeVoltage = 14.8;

  /// Evaluates human-readable warning strings for the dashboard.
  static List<String> evaluate(double fuel, double temp, double voltage) {
    final warnings = <String>[];
    if (fuel <= criticalFuel) {
      warnings.add('CRITICAL: Fuel almost empty');
    } else if (fuel <= lowFuel) {
      warnings.add('Low fuel level');
    }

    if (temp >= overheatTemp) {
      warnings.add('CRITICAL: Engine overheating');
    } else if (temp >= highTemp) {
      warnings.add('Engine temperature high');
    }

    if (voltage <= criticalVoltage) {
      warnings.add('CRITICAL: Battery voltage critical');
    } else if (voltage <= lowVoltage) {
      warnings.add('Battery voltage low');
    } else if (voltage >= overchargeVoltage) {
      warnings.add('CRITICAL: Battery overcharging');
    }

    return warnings;
  }

  /// Evaluates standardized SAE J2012 Diagnostic Trouble Codes (DTCs).
  /// Generates real industry codes mapped to threshold violations.
  static List<String> evaluateDtc(double fuel, double temp, double voltage) {
    final dtcs = <String>[];
    if (temp >= overheatTemp) {
      dtcs.add('P0217 - Engine Coolant Overtemperature Condition');
    } else if (temp >= highTemp) {
      dtcs.add('P0118 - Engine Coolant Temperature Circuit High Input');
    }

    if (voltage <= criticalVoltage) {
      dtcs.add('P0562 - System Voltage Low');
    } else if (voltage >= overchargeVoltage) {
      dtcs.add('P0563 - System Voltage High');
    }

    if (fuel <= criticalFuel) {
      dtcs.add('P0463 - Fuel Level Sensor A Circuit High (Reserve Depleted)');
    }

    return dtcs;
  }
}
