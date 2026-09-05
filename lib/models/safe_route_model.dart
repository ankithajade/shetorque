import 'package:google_maps_flutter/google_maps_flutter.dart';

class SafeHaven {
  final String name;
  final String type; // e.g., 'police', 'hospital', 'commercial'
  final LatLng location;

  SafeHaven({
    required this.name,
    required this.type,
    required this.location,
  });
}

class SafeRouteModel {
  final List<LatLng> polylineCoordinates;
  final String distance;
  final String duration;
  final double safetyScore;
  final List<String> riskTags;
  final List<SafeHaven> safeHavens;
  final bool isRecommended;

  SafeRouteModel({
    required this.polylineCoordinates,
    required this.distance,
    required this.duration,
    required this.safetyScore,
    required this.riskTags,
    required this.safeHavens,
    this.isRecommended = false,
  });
}
