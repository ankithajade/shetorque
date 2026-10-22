import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a safety location along a route (police stations, hospitals, fire stations, 24/7 hubs).
///
/// SheTorque Terminology Note:
/// - Rider-facing terminology: "Pink Spot" ("Pink Spots — nearby rider-friendly safety locations")
/// - Internal data model maintains underlying location type ('police', 'hospital', 'fire_station', etc.)
/// - Only claim "verified" where underlying data actually verifies it.
class SafeHaven {
  final String name;
  final String type; // 'police', 'hospital', 'fire_station', or 'commercial'
  final LatLng location;
  final bool isVerified; // True only when verified by SheTorque community or authority audit

  const SafeHaven({
    required this.name,
    required this.type,
    required this.location,
    this.isVerified = false,
  });

  String get displayType {
    switch (type) {
      case 'police':
        return 'Police Station';
      case 'hospital':
        return 'Hospital';
      case 'fire_station':
        return 'Fire Station';
      case 'commercial':
      default:
        return '24/7 Safety Hub';
    }
  }

  /// Rider-facing safety network designation
  String get riderLabel => 'Pink Spot ($displayType)';

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'isVerified': isVerified,
      };

  factory SafeHaven.fromJson(Map<String, dynamic> json) => SafeHaven(
        name: json['name'] as String? ?? 'Pink Spot',
        type: json['type'] as String? ?? 'commercial',
        location: LatLng(
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
        ),
        isVerified: json['isVerified'] as bool? ?? false,
      );
}

/// Explainable breakdown of the SheTorque Multi-Criteria Safety Score.
///
/// EXACT FORMULA:
/// PinkSpotScore × 0.30
/// + MainRoadScore × 0.30
/// + LightingScore × 0.15
/// + RegionalSafetyIndex × 0.25
///
/// where:
/// LightingScore = 100 − UnlitPercentage
///
/// All four factors are strictly positive 0–100 scores, and the weighted
/// total reaches 100.0.
class SafetyScoreBreakdown {
  final double pinkSpotScore; // 0.0 - 100.0 (Weight: 30%)
  final double mainRoadScore; // 0.0 - 100.0 (Weight: 30%)
  final double lightingScore; // 0.0 - 100.0 (Weight: 15%, 100 - UnlitPercentage)
  final double regionalSafetyIndex; // 0.0 - 100.0 (Weight: 25%)

  // Factor explanation notes for transparency UI
  final String pinkSpotExplanation;
  final String mainRoadExplanation;
  final String lightingExplanation;
  final String regionalExplanation;

  // Weight constants
  static const double pinkSpotWeight = 0.30;
  static const double mainRoadWeight = 0.30;
  static const double lightingWeight = 0.15;
  static const double regionalSafetyWeight = 0.25;

  const SafetyScoreBreakdown({
    required this.pinkSpotScore,
    required this.mainRoadScore,
    required this.lightingScore,
    required this.regionalSafetyIndex,
    this.pinkSpotExplanation = '',
    this.mainRoadExplanation = '',
    this.lightingExplanation = '',
    this.regionalExplanation = '',
  });

  double get pinkSpotContribution => pinkSpotScore * pinkSpotWeight;
  double get mainRoadContribution => mainRoadScore * mainRoadWeight;
  double get lightingContribution => lightingScore * lightingWeight;
  double get regionalContribution => regionalSafetyIndex * regionalSafetyWeight;

  double get totalScore => double.parse(
        (pinkSpotContribution +
                mainRoadContribution +
                lightingContribution +
                regionalContribution)
            .clamp(10.0, 100.0)
            .toStringAsFixed(1),
      );
}

/// Represents a candidate route evaluated by the Safe Routing engine.
class SafeRouteModel {
  final List<LatLng> polylineCoordinates;
  final String distance; // e.g. '14.2 km'
  final String duration; // e.g. '28 mins'
  final int distanceMeters;
  final int durationSeconds;
  final double safetyScore; // 0.0 - 100.0
  final double safeHavenDensity; // 0 - 100 (Pink Spot density)
  final double mainRoadRatio; // 0 - 100
  final double unlitPenalty; // 0 - 100 (Unlit percentage)
  final List<String> riskTags;
  final List<SafeHaven> safeHavens;
  final bool isRecommended;
  final String recommendationReason;
  final SafetyScoreBreakdown? scoreBreakdown;
  final String regionalDistrictName;

  const SafeRouteModel({
    required this.polylineCoordinates,
    required this.distance,
    required this.duration,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    required this.safetyScore,
    this.safeHavenDensity = 0.0,
    this.mainRoadRatio = 50.0,
    this.unlitPenalty = 0.0,
    required this.riskTags,
    required this.safeHavens,
    this.isRecommended = false,
    this.recommendationReason = '',
    this.scoreBreakdown,
    this.regionalDistrictName = 'Bengaluru City',
  });

  SafeRouteModel copyWith({
    List<LatLng>? polylineCoordinates,
    String? distance,
    String? duration,
    int? distanceMeters,
    int? durationSeconds,
    double? safetyScore,
    double? safeHavenDensity,
    double? mainRoadRatio,
    double? unlitPenalty,
    List<String>? riskTags,
    List<SafeHaven>? safeHavens,
    bool? isRecommended,
    String? recommendationReason,
    SafetyScoreBreakdown? scoreBreakdown,
    String? regionalDistrictName,
  }) {
    return SafeRouteModel(
      polylineCoordinates: polylineCoordinates ?? this.polylineCoordinates,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      safetyScore: safetyScore ?? this.safetyScore,
      safeHavenDensity: safeHavenDensity ?? this.safeHavenDensity,
      mainRoadRatio: mainRoadRatio ?? this.mainRoadRatio,
      unlitPenalty: unlitPenalty ?? this.unlitPenalty,
      riskTags: riskTags ?? this.riskTags,
      safeHavens: safeHavens ?? this.safeHavens,
      isRecommended: isRecommended ?? this.isRecommended,
      recommendationReason:
          recommendationReason ?? this.recommendationReason,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
      regionalDistrictName:
          regionalDistrictName ?? this.regionalDistrictName,
    );
  }
}
