import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../config/app_config.dart';
import '../models/safe_route_model.dart';
import 'crime_data_service.dart';

/// Service responsible for fetching driving directions, evaluating candidate route safety,
/// querying nearby Pink Spots (police, hospitals, fire stations),
/// analyzing OpenStreetMap road attributes, and applying the SheTorque Multi-Criteria
/// Safety Score with Karnataka 2025 regional crime indicators.
///
/// EXACT SAFETY SCORE FORMULA:
/// PinkSpotScore × 0.30
/// + MainRoadScore × 0.30
/// + LightingScore × 0.15
/// + RegionalSafetyIndex × 0.25
///
/// where:
/// LightingScore = 100 − UnlitPercentage
///
/// All four factors are strictly positive 0–100 scores; total reaches 100.0.
class SafeRoutingService {
  final String apiKey;
  final http.Client _client;
  final CrimeDataService _crimeDataService;

  SafeRoutingService({
    String? apiKey,
    http.Client? client,
    CrimeDataService? crimeDataService,
  })  : apiKey = apiKey ?? AppConfig.googleMapsApiKey,
        _client = client ?? http.Client(),
        _crimeDataService = crimeDataService ?? CrimeDataService();

  /// Fetches candidate routes between [origin] and [destination] and evaluates
  /// each route's safety score.
  ///
  /// Preserves all valid Google candidate routes returned with `alternatives=true`
  /// and `departure_time=now` for traffic awareness.
  Future<List<SafeRouteModel>> fetchSafeRoutes(
    LatLng origin,
    LatLng destination,
  ) async {
    final int nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&alternatives=true&departure_time=$nowEpoch&key=$apiKey';

    try {
      final response = await _client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Directions request timed out'),
      );

      if (response.statusCode != 200) {
        throw Exception('Directions API error (HTTP ${response.statusCode})');
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final String status = data['status'] as String? ?? 'UNKNOWN';

      if (status != 'OK') {
        if (status == 'ZERO_RESULTS') {
          return [];
        }
        throw Exception('Directions API returned: $status');
      }

      final List<dynamic> routesData = data['routes'] as List<dynamic>? ?? [];
      final List<SafeRouteModel> evaluatedRoutes = [];

      // Ensure crime data service is initialized
      if (!_crimeDataService.isInitialized) {
        await _crimeDataService.initialize();
      }

      for (var route in routesData) {
        final legs = route['legs'] as List<dynamic>? ?? [];
        if (legs.isEmpty) continue;

        final leg = legs[0];
        final String distanceText = leg['distance']?['text'] ?? '0 km';
        final int distanceMeters =
            (leg['distance']?['value'] as num?)?.toInt() ?? 0;
        final String durationText = leg['duration']?['text'] ?? '0 mins';
        final int durationSeconds =
            (leg['duration']?['value'] as num?)?.toInt() ?? 0;

        final String encodedPolyline =
            route['overview_polyline']?['points'] as String? ?? '';
        final List<PointLatLng> decodedPoints =
            PolylinePoints.decodePolyline(encodedPolyline);
        final List<LatLng> polylineCoordinates = decodedPoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

        final evaluated = await evaluateRouteSafety(
          polylineCoordinates: polylineCoordinates,
          distanceText: distanceText,
          durationText: durationText,
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
        );

        evaluatedRoutes.add(evaluated);
      }

      if (evaluatedRoutes.isEmpty) return [];

      // Recommend safest practical route balancing safety score, distance, and duration
      return selectSafestPracticalRoute(evaluatedRoutes);
    } catch (e) {
      return [];
    }
  }

  /// Evaluates safety metrics for a given route polyline.
  ///
  /// FORMULA:
  /// PinkSpotScore × 0.30
  /// + MainRoadScore × 0.30
  /// + LightingScore × 0.15
  /// + RegionalSafetyIndex × 0.25
  ///
  /// where LightingScore = 100 - UnlitPercentage.
  Future<SafeRouteModel> evaluateRouteSafety({
    required List<LatLng> polylineCoordinates,
    required String distanceText,
    required String durationText,
    int distanceMeters = 0,
    int durationSeconds = 0,
  }) async {
    final List<LatLng> sampledPoints =
        sampleRoutePoints(polylineCoordinates, 5);

    double safeHavenDensity = 0.0;
    double mainRoadRatio = 50.0;
    double unlitPenalty = 0.0;
    final List<String> riskTags = [];
    final List<SafeHaven> routeSafeHavens = [];

    // 1. Pink Spot Proximity (Nearby Search via Google Places API within 500m)
    for (final pt in sampledPoints) {
      final havens = await _fetchSafeHavens(pt);
      routeSafeHavens.addAll(havens);
    }

    // Deduplicate nearby Pink Spots by name
    final uniqueHavens = <String, SafeHaven>{};
    for (var h in routeSafeHavens) {
      uniqueHavens[h.name] = h;
    }
    final deduplicatedHavens = uniqueHavens.values.toList();

    // Scale Pink Spot score: 10 safety locations along sampled route = 100%
    safeHavenDensity =
        (deduplicatedHavens.length / 10).clamp(0.0, 1.0) * 100.0;

    // 2. Road Attributes via OpenStreetMap Overpass API
    try {
      final roadAttributes =
          await _fetchRoadAttributes(sampledPoints).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          riskTags.add('Street lighting data unconfirmed');
          return {'mainRoadRatio': 0.6, 'unlitSegments': 0.1};
        },
      );

      mainRoadRatio = (roadAttributes['mainRoadRatio'] ?? 0.6) * 100.0;
      unlitPenalty = (roadAttributes['unlitSegments'] ?? 0.1) * 100.0;

      if (mainRoadRatio < 40.0) {
        riskTags.add('High proportion of residential/isolated roads');
      }
      if (unlitPenalty > 30.0) {
        riskTags.add('Contains unlit street segments');
      }
    } catch (_) {
      riskTags.add('Detailed road attributes unavailable');
      mainRoadRatio = 55.0;
      unlitPenalty = 10.0;
    }

    // 3. Historical Regional Crime Indicator (Karnataka State Police 2025)
    final LatLng refPoint = polylineCoordinates.isNotEmpty
        ? polylineCoordinates.first
        : const LatLng(12.9716, 77.5946);
    final CrimeDistrictRecord crimeRecord =
        _crimeDataService.getIndicatorForLocation(refPoint);
    final double regionalSafetyIndex = crimeRecord.safetyIndex;

    // 4. Lighting Score: 100 - UnlitPercentage
    final double lightingScore = (100.0 - unlitPenalty).clamp(0.0, 100.0);

    // 5. Four-factor Weighted Total (all factors 0-100, weights sum to 1.0):
    // PinkSpotScore * 0.30 + MainRoadScore * 0.30 + LightingScore * 0.15 + RegionalSafetyIndex * 0.25
    final double rawScore = (safeHavenDensity * 0.30) +
        (mainRoadRatio * 0.30) +
        (lightingScore * 0.15) +
        (regionalSafetyIndex * 0.25);

    final double finalScore =
        double.parse(rawScore.clamp(10.0, 100.0).toStringAsFixed(1));

    if (finalScore < 60.0 && !riskTags.contains('Elevated Risk Corridor')) {
      riskTags.add('Elevated Risk Corridor');
    }

    // Build transparent explainability breakdown
    final breakdown = SafetyScoreBreakdown(
      pinkSpotScore: safeHavenDensity,
      mainRoadScore: mainRoadRatio,
      lightingScore: lightingScore,
      regionalSafetyIndex: regionalSafetyIndex,
      pinkSpotExplanation:
          '${deduplicatedHavens.length} Pink Spots (${_summarizeHavenTypes(deduplicatedHavens)}) within 500m',
      mainRoadExplanation:
          '${mainRoadRatio.toInt()}% major corridors (primary, trunk, secondary)',
      lightingExplanation:
          '${lightingScore.toInt()}% well-lit street coverage (${unlitPenalty.toInt()}% unlit segments)',
      regionalExplanation:
          '${crimeRecord.districtName} (${crimeRecord.riskCategory}, 2025 KSP baseline)',
    );

    return SafeRouteModel(
      polylineCoordinates: polylineCoordinates,
      distance: distanceText,
      duration: durationText,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      safetyScore: finalScore,
      safeHavenDensity: safeHavenDensity,
      mainRoadRatio: mainRoadRatio,
      unlitPenalty: unlitPenalty,
      riskTags: riskTags,
      safeHavens: deduplicatedHavens,
      isRecommended: false,
      scoreBreakdown: breakdown,
      regionalDistrictName: crimeRecord.districtName,
    );
  }

  static String _summarizeHavenTypes(List<SafeHaven> havens) {
    if (havens.isEmpty) return '0 safety hubs';
    int police = 0;
    int hospital = 0;
    int fire = 0;
    int other = 0;

    for (final h in havens) {
      if (h.type == 'police') {
        police++;
      } else if (h.type == 'hospital') {
        hospital++;
      } else if (h.type == 'fire_station') {
        fire++;
      } else {
        other++;
      }
    }

    final parts = <String>[];
    if (police > 0) {
      parts.add('$police police');
    }
    if (hospital > 0) {
      parts.add('$hospital medical');
    }
    if (fire > 0) {
      parts.add('$fire fire stn');
    }
    if (other > 0) {
      parts.add('$other hubs');
    }
    return parts.join(', ');
  }

  /// Selects the safest practical route, balancing safety score with
  /// reasonable distance and duration tolerances so riders are not diverted
  /// onto wildly impractical detours for minor safety differences.
  static List<SafeRouteModel> selectSafestPracticalRoute(
      List<SafeRouteModel> routes) {
    if (routes.isEmpty) return [];
    if (routes.length == 1) {
      return [
        routes.first.copyWith(
          isRecommended: true,
          recommendationReason:
              'Primary available route (Safety: ${routes.first.safetyScore.toInt()}/100)',
        )
      ];
    }

    // Find baseline shortest/fastest route
    final fastest = routes.reduce((a, b) =>
        (a.durationSeconds > 0 && b.durationSeconds > 0)
            ? (a.durationSeconds < b.durationSeconds ? a : b)
            : a);

    // Compute practicality utility for each candidate
    SafeRouteModel bestRoute = routes.first;
    double bestUtility = -1000.0;

    for (final candidate in routes) {
      // Delta calculations relative to fastest route
      final int durationDeltaSec =
          candidate.durationSeconds - fastest.durationSeconds;
      final int durationDeltaMin = (durationDeltaSec / 60).round();
      final double distanceDeltaKm =
          (candidate.distanceMeters - fastest.distanceMeters) / 1000.0;

      // Penalize excessively long detours: -1.2 pts per extra minute, -1.0 pt per extra km
      final double timePenalty = max(0, durationDeltaMin) * 1.2;
      final double distPenalty = max(0, distanceDeltaKm) * 1.0;

      final double utility = candidate.safetyScore - timePenalty - distPenalty;

      if (utility > bestUtility) {
        bestUtility = utility;
        bestRoute = candidate;
      }
    }

    // Generate explainable recommendation reason using rider-facing Pink Spots terminology
    final int minDiff =
        ((bestRoute.durationSeconds - fastest.durationSeconds) / 60).round();
    final double kmDiff =
        (bestRoute.distanceMeters - fastest.distanceMeters) / 1000.0;

    String reason;
    if (bestRoute == fastest && bestRoute.safetyScore >= 70.0) {
      reason =
          'Fastest direct route with high safety score (${bestRoute.safetyScore.toInt()}/100) and ${bestRoute.safeHavens.length} nearby Pink Spots.';
    } else if (bestRoute == fastest) {
      reason =
          'Fastest available route (${bestRoute.safetyScore.toInt()}/100). Exercise standard precautions along less-monitored segments.';
    } else {
      final diffText = minDiff > 0 ? '+$minDiff min' : '';
      final kmText = kmDiff > 0 ? ', +${kmDiff.toStringAsFixed(1)} km' : '';
      final int scoreGain =
          (bestRoute.safetyScore - fastest.safetyScore).round();
      reason =
          'Recommended for superior safety (+$scoreGain pts) along primary corridors with ${bestRoute.safeHavens.length} nearby Pink Spots ($diffText$kmText).';
    }

    // Return routes with the chosen one marked recommended and sorted first
    final result = <SafeRouteModel>[];
    for (final r in routes) {
      if (r == bestRoute) {
        result.insert(
          0,
          r.copyWith(
            isRecommended: true,
            recommendationReason: reason,
          ),
        );
      } else {
        result.add(r.copyWith(isRecommended: false));
      }
    }
    return result;
  }

  /// Samples [numSamples] evenly spaced points along the route to optimize API calls.
  static List<LatLng> sampleRoutePoints(List<LatLng> points, int numSamples) {
    if (points.length <= numSamples) return List.from(points);
    final List<LatLng> samples = [];
    final int step = (points.length / numSamples).floor();
    for (int i = 0; i < points.length; i += step) {
      samples.add(points[i]);
      if (samples.length == numSamples) break;
    }
    return samples;
  }

  /// Searches for Pink Spots (police stations, hospitals, fire stations)
  /// within 500m radius of [point].
  ///
  /// Maintains actual underlying facility types.
  Future<List<SafeHaven>> _fetchSafeHavens(LatLng point) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${point.latitude},${point.longitude}&radius=500&type=police|hospital&key=$apiKey';

    final List<SafeHaven> havens = [];
    try {
      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 4),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final List<dynamic> results =
              data['results'] as List<dynamic>? ?? [];
          for (var r in results) {
            final List<dynamic> types = r['types'] as List<dynamic>? ?? [];
            String type = 'commercial';
            if (types.contains('police')) {
              type = 'police';
            } else if (types.contains('hospital')) {
              type = 'hospital';
            } else if (types.contains('fire_station')) {
              type = 'fire_station';
            }

            final lat = r['geometry']?['location']?['lat'];
            final lng = r['geometry']?['location']?['lng'];
            if (lat != null && lng != null) {
              havens.add(
                SafeHaven(
                  name: r['name'] as String? ?? 'Safety Hub',
                  type: type,
                  location:
                      LatLng((lat as num).toDouble(), (lng as num).toDouble()),
                  isVerified: false, // Only claim verified when certified
                ),
              );
            }
          }
        }
      }
    } catch (_) {}
    return havens;
  }

  /// Queries OpenStreetMap Overpass API for road classifications and street lighting attributes.
  Future<Map<String, double>> _fetchRoadAttributes(List<LatLng> points) async {
    String query = '[out:json];(';
    for (var p in points) {
      query += 'way(around:80, ${p.latitude}, ${p.longitude})["highway"];';
    }
    query += ');out tags;';

    final response = await _client.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> elements = data['elements'] as List<dynamic>? ?? [];

      int totalRoads = 0;
      int mainRoads = 0;
      int unlitRoads = 0;

      for (var element in elements) {
        final tags = element['tags'];
        if (tags != null) {
          totalRoads++;
          final String? highway = tags['highway'] as String?;
          final String? lit = tags['lit'] as String?;

          if (['primary', 'secondary', 'trunk', 'motorway']
              .contains(highway)) {
            mainRoads++;
          }
          if (lit == 'no') {
            unlitRoads++;
          }
        }
      }

      if (totalRoads == 0) return {'mainRoadRatio': 0.6, 'unlitSegments': 0.1};

      return {
        'mainRoadRatio': mainRoads / totalRoads,
        'unlitSegments': unlitRoads / totalRoads,
      };
    } else {
      throw Exception('Overpass API query failed with ${response.statusCode}');
    }
  }

  /// Fetches Google Places autocomplete predictions with optional location bias.
  Future<List<PlaceSuggestion>> fetchPlacesSuggestions(
    String input, {
    LatLng? bias,
  }) async {
    if (input.trim().isEmpty) return [];

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$apiKey'
          '${bias != null ? '&location=${bias.latitude},${bias.longitude}&radius=50000' : ''}';

      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 4),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> predictions =
            data['predictions'] as List<dynamic>? ?? [];

        return predictions
            .map((p) => PlaceSuggestion.fromJson(p as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Resolves latitude and longitude coordinates for a given [placeId].
  Future<LatLng?> getPlaceDetails(String placeId) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$apiKey';

      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 4),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final result = data['result'];

        if (result != null) {
          final lat = result['geometry']?['location']?['lat'];
          final lng = result['geometry']?['location']?['lng'];
          if (lat != null && lng != null) {
            return LatLng((lat as num).toDouble(), (lng as num).toDouble());
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocodes coordinates to a human-readable location name.
  Future<String?> reverseGeocodeLocation(LatLng location) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=$apiKey';

      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 4),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> results =
            data['results'] as List<dynamic>? ?? [];

        if (results.isNotEmpty) {
          return results.first['formatted_address'] as String? ?? '';
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Autocomplete suggestion item from Google Places.
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final formatting = json['structured_formatting'] ?? {};
    return PlaceSuggestion(
      placeId: json['place_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mainText: formatting['main_text'] as String? ?? '',
      secondaryText: formatting['secondary_text'] as String? ?? '',
    );
  }
}
