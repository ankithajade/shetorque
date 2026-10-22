/// Classification of overall motorcycle mechanical condition.
enum VehicleHealthStatus {
  optimal, // 90 - 100
  good, // 75 - 89
  warning, // 50 - 74
  critical, // < 50
}

/// Severity level for individual diagnostic recommendations.
enum RecommendationSeverity {
  low,
  medium,
  high,
  critical,
}

/// An explainable recommendation indicating why a suggestion was triggered,
/// backed by real telemetry threshold violations.
class DiagnosticRecommendation {
  final String id;
  final String title;
  final String reason; // Explainability: Why this recommendation was triggered
  final String action; // Actionable advice for the rider
  final RecommendationSeverity severity;
  final DateTime timestamp;

  const DiagnosticRecommendation({
    required this.id,
    required this.title,
    required this.reason,
    required this.action,
    required this.severity,
    required this.timestamp,
  });

  @override
  String toString() =>
      'DiagnosticRecommendation($id, title: $title, reason: $reason, severity: $severity)';
}

/// Domain model encapsulating overall vehicle health metrics and explainable diagnostics.
///
/// Score Derivation:
/// Base Score: 100
/// - Engine Temperature Penalties:
///   - Temp >= 115°C (overheat): -35 points
///   - Temp >= 105°C (high): -15 points
/// - Electrical / Battery Penalties:
///   - Voltage <= 11.2V (critical): -30 points
///   - Voltage <= 11.8V (low): -15 points
///   - Voltage >= 14.8V (overcharge): -20 points
/// - Fuel Reserve Penalties:
///   - Fuel <= 5% (critical empty): -20 points
///   - Fuel <= 15% (reserve): -10 points
/// Clamped strictly to range [0, 100].
class VehicleHealth {
  final int overallScore; // 0 - 100
  final VehicleHealthStatus status;
  final List<String> activeWarnings;
  final List<String> criticalIssues;
  final List<DiagnosticRecommendation> recommendations;
  final DateTime timestamp;

  const VehicleHealth({
    required this.overallScore,
    required this.status,
    required this.activeWarnings,
    required this.criticalIssues,
    required this.recommendations,
    required this.timestamp,
  });

  /// Factory providing a healthy baseline.
  factory VehicleHealth.nominal() {
    return VehicleHealth(
      overallScore: 98,
      status: VehicleHealthStatus.optimal,
      activeWarnings: const [],
      criticalIssues: const [],
      recommendations: const [],
      timestamp: DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case VehicleHealthStatus.optimal:
        return 'Optimal Condition';
      case VehicleHealthStatus.good:
        return 'Good Condition';
      case VehicleHealthStatus.warning:
        return 'Attention Required';
      case VehicleHealthStatus.critical:
        return 'Critical Fault';
    }
  }
}
