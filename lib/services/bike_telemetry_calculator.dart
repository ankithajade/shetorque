/// Severity level for fuel consumption alerts.
enum FuelAlertLevel {
  none,
  advisory, // 50% consumed
  critical, // 75% consumed
}

/// Pure math calculation engine for motorcycle telemetry estimations and maintenance thresholds.
///
/// Designed with zero external dependencies to enable comprehensive deterministic unit testing.
class BikeTelemetryCalculator {
  /// Default periodic service interval for two-wheelers (3,000 km standard baseline).
  static const double defaultServiceIntervalKm = 3000.0;

  /// Calculates estimated remaining riding range in kilometers.
  ///
  /// Formula: `(fuelLevelPercent / 100.0) * fuelCapacityL * avgMileageKmpl`
  static double calculateRemainingRangeKm({
    required double fuelCapacityL,
    required double avgMileageKmpl,
    required double fuelLevelPercent,
  }) {
    if (fuelCapacityL <= 0 || avgMileageKmpl <= 0) return 0.0;
    final clampedPercent = fuelLevelPercent.clamp(0.0, 100.0);
    final remainingLiters = (clampedPercent / 100.0) * fuelCapacityL;
    return remainingLiters * avgMileageKmpl;
  }

  /// Calculates fuel consumption percentage (0.0 to 100.0).
  ///
  /// For example, when fuel level is 30% remaining, consumed is 70%.
  static double calculateFuelConsumedPercent(double fuelLevelPercent) {
    final clamped = fuelLevelPercent.clamp(0.0, 100.0);
    return 100.0 - clamped;
  }

  /// Evaluates fuel alert category based on consumed thresholds:
  /// - [FuelAlertLevel.critical] when consumed >= 75.0% (<= 25% fuel remaining)
  /// - [FuelAlertLevel.advisory] when consumed >= 50.0% (<= 50% fuel remaining)
  /// - [FuelAlertLevel.none] when consumed < 50.0% (> 50% fuel remaining)
  static FuelAlertLevel getFuelAlertLevel(double fuelLevelPercent) {
    final consumed = calculateFuelConsumedPercent(fuelLevelPercent);
    if (consumed >= 75.0) return FuelAlertLevel.critical;
    if (consumed >= 50.0) return FuelAlertLevel.advisory;
    return FuelAlertLevel.none;
  }

  /// Generates human-readable explanatory message for active fuel alerts.
  static String? getFuelAlertMessage({
    required double fuelCapacityL,
    required double avgMileageKmpl,
    required double fuelLevelPercent,
  }) {
    final level = getFuelAlertLevel(fuelLevelPercent);
    if (level == FuelAlertLevel.none) return null;

    final rangeKm = calculateRemainingRangeKm(
      fuelCapacityL: fuelCapacityL,
      avgMileageKmpl: avgMileageKmpl,
      fuelLevelPercent: fuelLevelPercent,
    );
    final consumed = calculateFuelConsumedPercent(fuelLevelPercent);

    if (level == FuelAlertLevel.critical) {
      return "CRITICAL FUEL ALERT: ${consumed.toStringAsFixed(0)}% fuel consumed (~${rangeKm.toStringAsFixed(0)} km range remaining). Refuel immediately.";
    } else {
      return "FUEL ADVISORY: ${consumed.toStringAsFixed(0)}% fuel consumed (~${rangeKm.toStringAsFixed(0)} km range remaining).";
    }
  }

  /// Calculates kilometers remaining until next scheduled service.
  ///
  /// Service due at: `lastServiceKm + serviceIntervalKm`
  /// Due in: `(lastServiceKm + serviceIntervalKm) - currentOdometerKm`
  /// If result <= 0, service is overdue.
  static double calculateServiceDueInKm({
    required double currentOdometerKm,
    required double lastServiceKm,
    double serviceIntervalKm = defaultServiceIntervalKm,
  }) {
    final nextServiceAt = lastServiceKm + serviceIntervalKm;
    return nextServiceAt - currentOdometerKm;
  }

  /// Evaluates whether maintenance is overdue.
  static bool isServiceOverdue({
    required double currentOdometerKm,
    required double lastServiceKm,
    double serviceIntervalKm = defaultServiceIntervalKm,
  }) {
    return calculateServiceDueInKm(
          currentOdometerKm: currentOdometerKm,
          lastServiceKm: lastServiceKm,
          serviceIntervalKm: serviceIntervalKm,
        ) <=
        0;
  }

  /// Generates human-readable service status text.
  static String getServiceStatusText({
    required double currentOdometerKm,
    required double lastServiceKm,
    double serviceIntervalKm = defaultServiceIntervalKm,
  }) {
    final dueInKm = calculateServiceDueInKm(
      currentOdometerKm: currentOdometerKm,
      lastServiceKm: lastServiceKm,
      serviceIntervalKm: serviceIntervalKm,
    );

    if (dueInKm <= 0) {
      final overdueKm = dueInKm.abs().toStringAsFixed(0);
      return "Service overdue by $overdueKm km!";
    } else {
      return "Service due in ${dueInKm.toStringAsFixed(0)} km";
    }
  }
}
