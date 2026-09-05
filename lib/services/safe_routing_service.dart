import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/safe_route_model.dart';

class SafeRoutingService {
  final String _googleApiKey = "AIzaSyCUHBYx2WJdKyn28chAG60d38oHkRPo7OE";

  Future<List<SafeRouteModel>> fetchSafeRoutes(LatLng origin, LatLng destination) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&alternatives=true&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK') {
          List<dynamic> routesData = data['routes'];
          List<SafeRouteModel> parsedRoutes = [];

          for (var route in routesData) {
            final leg = route['legs'][0];
            final String distance = leg['distance']['text'];
            final String duration = leg['duration']['text'];
            final String encodedPolyline = route['overview_polyline']['points'];

            List<PointLatLng> result = PolylinePoints.decodePolyline(encodedPolyline);
            List<LatLng> polylineCoordinates = result.map((e) => LatLng(e.latitude, e.longitude)).toList();

            // Evaluate Safety Score for this route
            SafeRouteModel evaluatedRoute = await _evaluateRouteSafety(
              polylineCoordinates,
              distance,
              duration,
            );

            parsedRoutes.add(evaluatedRoute);
          }

          // Sort routes by safety score descending, mark the top one as recommended
          parsedRoutes.sort((a, b) => b.safetyScore.compareTo(a.safetyScore));

          if (parsedRoutes.isNotEmpty) {
             final best = parsedRoutes.first;
             parsedRoutes[0] = SafeRouteModel(
                polylineCoordinates: best.polylineCoordinates,
                distance: best.distance,
                duration: best.duration,
                safetyScore: best.safetyScore,
                riskTags: best.riskTags,
                safeHavens: best.safeHavens,
                isRecommended: true,
             );
          }

          return parsedRoutes;
        } else {
          throw Exception('Directions API failed: ${data['status']}');
        }
      } else {
        throw Exception('Failed to fetch routes');
      }
    } catch (e) {
      print('Error fetching routes: $e');
      return [];
    }
  }

  Future<SafeRouteModel> _evaluateRouteSafety(
      List<LatLng> polylineCoordinates, String distance, String duration) async {
    
    // To optimize API calls, we sample the route points (e.g., take 5 evenly spaced points)
    List<LatLng> sampledPoints = _sampleRoutePoints(polylineCoordinates, 5);

    double safeHavenDensity = 0.0;
    double mainRoadRatio = 0.5; // Default assumption if Overpass fails
    double unlitPenalty = 0.0;

    List<String> riskTags = [];
    List<SafeHaven> routeSafeHavens = [];

    // 1. Fetch Safe Havens along sampled points (Places API)
    for (var point in sampledPoints) {
      List<SafeHaven> havens = await _fetchSafeHavens(point);
      routeSafeHavens.addAll(havens);
    }
    
    // Remove duplicates based on location slightly differing, simplistic name check for now
    final uniqueHavens = <String, SafeHaven>{};
    for (var h in routeSafeHavens) {
      uniqueHavens[h.name] = h;
    }
    routeSafeHavens = uniqueHavens.values.toList();

    // Scale safe haven density (cap at 10 havens for max score component)
    safeHavenDensity = (routeSafeHavens.length / 10).clamp(0.0, 1.0) * 100.0;

    // 2. Fetch Road Attributes (Overpass API) with Timeout Fallback
    try {
      final overpassResult = await _fetchRoadAttributes(sampledPoints).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          print("Overpass API timed out. Falling back to default road assumptions.");
          riskTags.add("Road details unavailable (Timeout)");
          return {'mainRoadRatio': 0.5, 'unlitSegments': 1.0}; // Neutral fallback
        },
      );

      mainRoadRatio = (overpassResult['mainRoadRatio'] ?? 0.5) * 100.0;
      unlitPenalty = (overpassResult['unlitSegments'] ?? 0.0) * 100.0;

      if (mainRoadRatio < 30.0) {
         riskTags.add("Many Secondary/Residential Roads");
      }
      if (unlitPenalty > 40.0) {
         riskTags.add("Significant Unlit Segments");
      }

    } catch (e) {
      print("Overpass API error: $e");
      riskTags.add("Road details unavailable");
      mainRoadRatio = 50.0;
      unlitPenalty = 0.0;
    }

    // 3. Calculate Safety Score (0-100)
    // Formula: (Safe Haven Density * 0.4) + (Main Road Ratio * 0.4) - (Unlit/Isolated Segments * 0.2)
    double baseScore = (safeHavenDensity * 0.4) + (mainRoadRatio * 0.4) - (unlitPenalty * 0.2);
    
    // Normalize and clamp
    double finalScore = baseScore.clamp(10.0, 100.0);

    if (finalScore < 60) {
       if(!riskTags.contains("High Risk Area")) riskTags.add("High Risk Area");
    }

    return SafeRouteModel(
      polylineCoordinates: polylineCoordinates,
      distance: distance,
      duration: duration,
      safetyScore: double.parse(finalScore.toStringAsFixed(1)),
      riskTags: riskTags,
      safeHavens: routeSafeHavens,
    );
  }

  List<LatLng> _sampleRoutePoints(List<LatLng> points, int numSamples) {
    if (points.length <= numSamples) return points;
    List<LatLng> samples = [];
    int step = (points.length / numSamples).floor();
    for (int i = 0; i < points.length; i += step) {
      samples.add(points[i]);
      if (samples.length == numSamples) break;
    }
    return samples;
  }

  Future<List<SafeHaven>> _fetchSafeHavens(LatLng point) async {
    // Types to check: police, hospital
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${point.latitude},${point.longitude}&radius=300&type=police|hospital&key=$_googleApiKey';
    
    List<SafeHaven> havens = [];
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          List<dynamic> results = data['results'];
          for (var r in results) {
            String type = 'commercial';
            List<dynamic> types = r['types'] ?? [];
            if (types.contains('police')) type = 'police';
            else if (types.contains('hospital')) type = 'hospital';

            havens.add(SafeHaven(
              name: r['name'] ?? 'Safe Haven',
              type: type,
              location: LatLng(
                r['geometry']['location']['lat'],
                r['geometry']['location']['lng'],
              ),
            ));
          }
        }
      }
    } catch (e) {
      print('Places API Error: $e');
    }
    return havens;
  }

  Future<Map<String, double>> _fetchRoadAttributes(List<LatLng> points) async {
    // Construct Overpass QL to query road types around the sampled points
    String query = '[out:json];(';
    for (var p in points) {
      query += 'way(around:50, ${p.latitude}, ${p.longitude})["highway"];';
    }
    query += ');out tags;';

    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<dynamic> elements = data['elements'] ?? [];

      int totalRoads = 0;
      int mainRoads = 0;
      int unlitRoads = 0;

      for (var element in elements) {
        if (element['tags'] != null) {
          totalRoads++;
          String? highway = element['tags']['highway'];
          String? lit = element['tags']['lit'];

          if (['primary', 'secondary', 'trunk', 'motorway'].contains(highway)) {
            mainRoads++;
          }
          if (lit == 'no') {
            unlitRoads++;
          }
        }
      }

      if (totalRoads == 0) return {'mainRoadRatio': 0.5, 'unlitSegments': 0.0};

      return {
        'mainRoadRatio': mainRoads / totalRoads,
        'unlitSegments': unlitRoads / totalRoads,
      };
    } else {
      throw Exception('Overpass API failed');
    }
  }
}
