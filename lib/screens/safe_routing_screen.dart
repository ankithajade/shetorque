import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/safe_route_model.dart';
import '../services/safe_routing_service.dart';
import 'dart:async';

class SafeRoutingScreen extends StatefulWidget {
  final LatLng? initialDestination;

  const SafeRoutingScreen({Key? key, this.initialDestination}) : super(key: key);

  @override
  _SafeRoutingScreenState createState() => _SafeRoutingScreenState();
}

class _SafeRoutingScreenState extends State<SafeRoutingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final SafeRoutingService _routingService = SafeRoutingService();
  final TextEditingController _destinationController = TextEditingController();

  // Location and routing state
  LatLng? _currentUserLocation;
  LatLng? _selectedDestination;
  String? _selectedDestinationName;
  List<SafeRouteModel> _routes = [];
  SafeRouteModel? _selectedRoute;
  
  // UI and navigation state
  bool _isLoading = false;
  bool _isNavigating = false;
  String _alertMessage = '';
  bool _showDestinationSuggestions = false;
  List<dynamic> _destinationSuggestions = [];

  // Live location streaming
  StreamSubscription<Position>? _locationStreamSubscription;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    if (widget.initialDestination != null) {
      _selectedDestination = widget.initialDestination;
    }
  }

  // Initialize user's live location with permission handling
  Future<void> _initializeLocation() async {
    try {
      // Request location permission
      final PermissionStatus status = await Permission.location.request();

      if (status.isDenied) {
        setState(() {
          _alertMessage = 'Location permission is required for safe routing.';
        });
        return;
      } else if (status.isPermanentlyDenied) {
        openAppSettings();
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _alertMessage = 'Please enable location services.';
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
      });

      // Center map on user location
      if (!_controller.isCompleted) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _centerMapOnUserLocation();

      // If destination already set, fetch routes
      if (_selectedDestination != null) {
        _fetchRoutes();
      }
    } catch (e) {
      print('Error initializing location: $e');
      setState(() {
        _alertMessage = 'Failed to get your location. Using default location.';
        _currentUserLocation = const LatLng(37.7749, -122.4194); // SF fallback
      });
    }
  }

  // Center map camera on user's current location
  Future<void> _centerMapOnUserLocation() async {
    if (_currentUserLocation == null) return;

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentUserLocation!,
          zoom: 15,
        ),
      ),
    );
  }

  // Handle destination search input and show autocomplete suggestions
  Future<void> _handleDestinationSearch(String input) async {
    if (input.isEmpty) {
      setState(() {
        _showDestinationSuggestions = false;
        _destinationSuggestions = [];
      });
      return;
    }

    try {
      final suggestions = await _routingService.fetchPlacesSuggestions(
        input,
        bias: _currentUserLocation,
      );

      setState(() {
        _destinationSuggestions = suggestions;
        _showDestinationSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  // Select destination from suggestions
  Future<void> _selectDestinationFromSuggestion(dynamic suggestion) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final placeId = suggestion.placeId;
      final LatLng? destinationLocation =
          await _routingService.getPlaceDetails(placeId);

      if (destinationLocation != null) {
        setState(() {
          _selectedDestination = destinationLocation;
          _selectedDestinationName = suggestion.description;
          _destinationController.text = suggestion.mainText;
          _showDestinationSuggestions = false;
          _isLoading = false;
        });

        // Fetch routes for this destination
        _fetchRoutes();
      } else {
        setState(() {
          _alertMessage = 'Could not get destination coordinates.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error selecting destination: $e');
      setState(() {
        _alertMessage = 'Error selecting destination.';
        _isLoading = false;
      });
    }
  }

  // Handle map tap to select destination
  Future<void> _handleMapTap(LatLng tappedLocation) async {
    setState(() {
      _selectedDestination = tappedLocation;
      _showDestinationSuggestions = false;
    });

    // Try to get location name via reverse geocoding
    final locationName =
        await _routingService.reverseGeocodeLocation(tappedLocation);
    setState(() {
      _selectedDestinationName = locationName;
      _destinationController.text = locationName ?? 'Custom Location';
    });

    _fetchRoutes();
  }

  // Fetch safe routes for current origin and selected destination
  Future<void> _fetchRoutes() async {
    if (_currentUserLocation == null || _selectedDestination == null) {
      setState(() {
        _alertMessage = 'Please set both origin and destination.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _alertMessage = '';
    });

    try {
      final routes = await _routingService.fetchSafeRoutes(
        _currentUserLocation!,
        _selectedDestination!,
      );

      setState(() {
        _routes = routes;
        if (_routes.isNotEmpty) {
          _selectedRoute =
              _routes.firstWhere((r) => r.isRecommended, orElse: () => _routes.first);
          _updateMapData();
        } else {
          _alertMessage = 'No routes found.';
        }
        _isLoading = false;
      });

      if (_routes.isNotEmpty) {
        _moveCameraToFit();
      }
    } catch (e) {
      print('Error fetching routes: $e');
      setState(() {
        _alertMessage = 'Error fetching routes: $e';
        _isLoading = false;
      });
    }
  }

  void _updateMapData() {
    _polylines.clear();
    _markers.clear();

    // Add user location marker (blue dot for "My Location")
    if (_currentUserLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('myLocation'),
          position: _currentUserLocation!,
          infoWindow: const InfoWindow(title: 'My Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add destination marker
    if (_selectedDestination != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _selectedDestination!,
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _selectedDestinationName,
          ),
        ),
      );
    }

    // Add route polylines with color coding
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
        polylineColor = Colors.green.withValues(alpha: 0.5);
        zIndex = 1;
      } else {
        polylineColor = Colors.red.withValues(alpha: 0.5);
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

      // Show safe havens only for selected route
      if (isSelected) {
        for (int j = 0; j < route.safeHavens.length; j++) {
          final haven = route.safeHavens[j];
          _markers.add(
            Marker(
              markerId: MarkerId('haven_${i}_$j'),
              position: haven.location,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                haven.type == 'police'
                    ? BitmapDescriptor.hueBlue
                    : BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(
                title: haven.name,
                snippet: haven.type.toUpperCase(),
              ),
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

  // Start live navigation mode
  void _startNavigation() {
    if (_selectedRoute == null) {
      setState(() {
        _alertMessage = 'Please select a route first.';
      });
      return;
    }

    setState(() {
      _isNavigating = true;
      _alertMessage = '';
    });

    // Start live location stream
    _locationStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(
      (Position position) {
        // Update current location marker and camera during navigation
        setState(() {
          _currentUserLocation = LatLng(position.latitude, position.longitude);
        });

        // Center map on current location with heading
        _updateMapDuringNavigation(position);
      },
      onError: (e) {
        print('Location stream error: $e');
      },
    );
  }

  // Update map during navigation to follow user
  Future<void> _updateMapDuringNavigation(Position position) async {
    if (!_controller.isCompleted || !_isNavigating) return;

    final GoogleMapController controller = await _controller.future;

    // Update user location marker
    _markers.removeWhere(
      (marker) => marker.markerId.value == 'myLocation',
    );
    _markers.add(
      Marker(
        markerId: const MarkerId('myLocation'),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: const InfoWindow(title: 'My Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    // Animate camera to follow user with bearing if available
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 17,
          bearing: position.heading >= 0 ? position.heading : 0,
          tilt: 45, // Tilt for better navigation view
        ),
      ),
    );

    setState(() {});
  }

  // Stop navigation
  void _stopNavigation() {
    _locationStreamSubscription?.cancel();
    setState(() {
      _isNavigating = false;
      _centerMapOnUserLocation();
    });
  }

  Future<void> _moveCameraToFit() async {
    if (_routes.isEmpty || _currentUserLocation == null || _selectedDestination == null) {
      return;
    }

    double minLat = _currentUserLocation!.latitude;
    double maxLat = _currentUserLocation!.latitude;
    double minLng = _currentUserLocation!.longitude;
    double maxLng = _currentUserLocation!.longitude;

    // Include destination
    minLat = minLat > _selectedDestination!.latitude
        ? _selectedDestination!.latitude
        : minLat;
    maxLat = maxLat < _selectedDestination!.latitude
        ? _selectedDestination!.latitude
        : maxLat;
    minLng = minLng > _selectedDestination!.longitude
        ? _selectedDestination!.longitude
        : minLng;
    maxLng = maxLng < _selectedDestination!.longitude
        ? _selectedDestination!.longitude
        : maxLng;

    // Include all route points
    for (var r in _routes) {
      for (var p in r.polylineCoordinates) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
    }

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Navigation'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _currentUserLocation ?? const LatLng(37.7749, -122.4194),
              zoom: 15,
            ),
            polylines: _polylines,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: _isNavigating ? null : _handleMapTap,
          ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                backgroundColor: Colors.white,
              ),
            ),

          // Alert message banner
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
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _alertMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // My Location button
          Positioned(
            bottom: 200,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'myLocation',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _centerMapOnUserLocation,
              child: const Icon(Icons.my_location, color: Colors.indigo),
            ),
          ),

          // Destination search bar (only if not navigating)
          if (!_isNavigating)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Destination search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6)
                      ],
                    ),
                    child: TextField(
                      controller: _destinationController,
                      onChanged: _handleDestinationSearch,
                      onTap: () {
                        if (_showDestinationSuggestions) {
                          setState(() {});
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search destination...',
                        prefixIcon: const Icon(Icons.location_on, color: Colors.indigo),
                        suffixIcon: _destinationController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _destinationController.clear();
                                  setState(() {
                                    _showDestinationSuggestions = false;
                                    _selectedDestination = null;
                                    _routes.clear();
                                    _polylines.clear();
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),

                  // Suggestions dropdown
                  if (_showDestinationSuggestions && _destinationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6)
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _destinationSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _destinationSuggestions[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined,
                                color: Colors.grey),
                            title: Text(suggestion.mainText ?? 'Unknown'),
                            subtitle: Text(
                              suggestion.secondaryText ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () =>
                                _selectDestinationFromSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Bottom sheet with routes (only if not navigating)
          if (!_isNavigating && _routes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomSheet(),
            ),

          // Navigation controls (only if navigating)
          if (_isNavigating)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.navigation, color: Colors.indigo),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Navigation Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _selectedRoute?.duration ?? 'N/A',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _stopNavigation,
                        child: const Text(
                          'End Navigation',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)
        ],
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
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Routes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_selectedDestinationName != null)
                Expanded(
                  child: Text(
                    _selectedDestinationName!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
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
                backgroundColor:
                    _selectedRoute?.isRecommended == true ? Colors.green : Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _startNavigation,
              child: Text(
                _selectedRoute?.isRecommended == true
                    ? 'Start Safe Navigation'
                    : 'Start High-Risk Navigation',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
          color: isSelected
              ? (isRecommended ? Colors.green.shade50 : Colors.orange.shade50)
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? (isRecommended ? Colors.green : Colors.orange)
                : Colors.grey.shade300,
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
                Text(route.duration,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRecommended ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${route.safetyScore}% Safe',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
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
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          route.riskTags[idx],
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade900),
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

  @override
  void dispose() {
    _locationStreamSubscription?.cancel();
    _destinationController.dispose();
    super.dispose();
  }
}
