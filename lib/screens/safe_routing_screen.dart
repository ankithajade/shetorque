import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/safe_route_model.dart';
import '../services/safe_routing_service.dart';
import 'dart:async';

class SafeRoutingScreen extends StatefulWidget {
  final LatLng? origin;
  final LatLng? destination;

  const SafeRoutingScreen({Key? key, this.origin, this.destination}) : super(key: key);

  @override
  _SafeRoutingScreenState createState() => _SafeRoutingScreenState();
}

class _SafeRoutingScreenState extends State<SafeRoutingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final SafeRoutingService _routingService = SafeRoutingService();

  List<SafeRouteModel> _routes = [];
  SafeRouteModel? _selectedRoute;
  bool _isLoading = false;
  String _alertMessage = '';

  // Default coordinates (e.g., San Francisco for testing) if none provided
  late LatLng _currentOrigin;
  late LatLng _currentDestination;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _currentOrigin = widget.origin ?? const LatLng(37.7749, -122.4194);
    _currentDestination = widget.destination ?? const LatLng(37.8044, -122.2712); // Oakland
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    setState(() {
      _isLoading = true;
      _alertMessage = '';
    });

    final routes = await _routingService.fetchSafeRoutes(_currentOrigin, _currentDestination);

    setState(() {
      _routes = routes;
      if (_routes.isNotEmpty) {
        _selectedRoute = _routes.firstWhere((r) => r.isRecommended, orElse: () => _routes.first);
        _updateMapData();
      }
      _isLoading = false;
    });
    _moveCameraToFit();
  }

  void _updateMapData() {
    _polylines.clear();
    _markers.clear();

    // Add origin/destination markers
    _markers.add(Marker(markerId: const MarkerId('origin'), position: _currentOrigin, infoWindow: const InfoWindow(title: 'Origin')));
    _markers.add(Marker(markerId: const MarkerId('destination'), position: _currentDestination, infoWindow: const InfoWindow(title: 'Destination')));

    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      final isSelected = route == _selectedRoute;
      final isRecommended = route.isRecommended;

      Color polylineColor = Colors.grey;
      int zIndex = 0;
      
      if (isSelected && isRecommended) {
        polylineColor = Colors.green;
        zIndex = 2;
      } else if (isSelected && !isRecommended) {
        polylineColor = Colors.orange;
        zIndex = 2;
      } else if (isRecommended) {
        polylineColor = Colors.green.withOpacity(0.5);
        zIndex = 1;
      } else {
        polylineColor = Colors.red.withOpacity(0.5);
      }

      _polylines.add(
        Polyline(
          polylineId: PolylineId('route_$i'),
          points: route.polylineCoordinates,
          color: polylineColor,
          width: isSelected ? 6 : 4,
          zIndex: zIndex,
          onTap: () {
            _selectRoute(route);
          },
        ),
      );

      // Show safe havens only for the selected route to reduce map clutter
      if (isSelected) {
        for (int j = 0; j < route.safeHavens.length; j++) {
          final haven = route.safeHavens[j];
          _markers.add(
            Marker(
              markerId: MarkerId('haven_${i}_$j'),
              position: haven.location,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                haven.type == 'police' ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(title: haven.name, snippet: haven.type.toUpperCase()),
            ),
          );
        }
      }
    }
  }

  void _selectRoute(SafeRouteModel route) {
    setState(() {
      _selectedRoute = route;
      if (!route.isRecommended) {
        _alertMessage = 'Warning: You have selected a higher-risk route.';
      } else {
        _alertMessage = '';
      }
      _updateMapData();
    });
  }

  Future<void> _moveCameraToFit() async {
    if (_routes.isEmpty) return;
    
    double minLat = _currentOrigin.latitude;
    double maxLat = _currentOrigin.latitude;
    double minLng = _currentOrigin.longitude;
    double maxLng = _currentOrigin.longitude;

    for (var r in _routes) {
      for (var p in r.polylineCoordinates) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
    }

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      50.0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Routing'),
        backgroundColor: Colors.indigo,
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _currentOrigin,
              zoom: 12,
            ),
            polylines: _polylines,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          if (_alertMessage.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _alertMessage,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (_routes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomSheet(),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Available Routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _routes.length,
              itemBuilder: (context, index) {
                return _buildRouteCard(_routes[index]);
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedRoute?.isRecommended == true ? Colors.green : Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Logic to start navigation could be triggered here
              },
              child: Text(
                _selectedRoute?.isRecommended == true ? 'Start Safe Ride' : 'Start High-Risk Ride',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRouteCard(SafeRouteModel route) {
    bool isSelected = route == _selectedRoute;
    bool isRecommended = route.isRecommended;

    return GestureDetector(
      onTap: () => _selectRoute(route),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? (isRecommended ? Colors.green.shade50 : Colors.orange.shade50) : Colors.white,
          border: Border.all(
            color: isSelected ? (isRecommended ? Colors.green : Colors.orange) : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(route.duration, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRecommended ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${route.safetyScore}% Safe',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(route.distance, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: route.riskTags.length,
                itemBuilder: (context, idx) {
                  return Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          route.riskTags[idx],
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
