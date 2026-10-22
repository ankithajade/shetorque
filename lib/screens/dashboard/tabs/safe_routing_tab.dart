import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../theme/she_torque_theme.dart';
import '../../../models/safe_route_model.dart';
import '../../../services/safe_routing_service.dart';

/// Full interactive Safe Routing tab featuring Google Maps, Places search,
/// OpenStreetMap road risk heuristics, multi-route safety scoring,
/// Pink Spots network visualization, Karnataka 2025 regional crime indicator,
/// and camera-following navigation.
class SafeRoutingTab extends StatefulWidget {
  final LatLng? initialDestination;

  const SafeRoutingTab({super.key, this.initialDestination});

  @override
  State<SafeRoutingTab> createState() => _SafeRoutingTabState();
}

class _SafeRoutingTabState extends State<SafeRoutingTab> {
  final Completer<GoogleMapController> _controller = Completer();
  final SafeRoutingService _routingService = SafeRoutingService();
  final TextEditingController _destinationController = TextEditingController();

  // Location and route state
  LatLng? _currentUserLocation;
  LatLng? _selectedDestination;
  String? _selectedDestinationName;
  List<SafeRouteModel> _routes = [];
  SafeRouteModel? _selectedRoute;

  // Search and UI state
  bool _isLoading = false;
  bool _isNavigating = false;
  bool _showScoreBreakdown = false;
  String? _alertMessage;
  bool _showSuggestions = false;
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounceTimer;

  // Live navigation streaming
  StreamSubscription<Position>? _navStreamSubscription;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Default fallback center (Bengaluru, Karnataka) if GPS unavailable initially
  static const LatLng _defaultLocation = LatLng(12.9716, 77.5946);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    if (widget.initialDestination != null) {
      _selectedDestination = widget.initialDestination;
    }
  }

  // ==========================================================================
  // Location & Permissions Handling
  // ==========================================================================
  Future<void> _initializeLocation() async {
    try {
      final PermissionStatus status = await Permission.location.request();

      if (status.isDenied) {
        if (mounted) {
          setState(() {
            _alertMessage = 'Location permission is required for safe routing.';
            _currentUserLocation = _defaultLocation;
          });
        }
        return;
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _alertMessage =
                'Location permission is permanently denied. Please enable in Settings.';
            _currentUserLocation = _defaultLocation;
          });
        }
        return;
      }

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _alertMessage = 'Please enable device GPS / location services.';
            _currentUserLocation = _defaultLocation;
          });
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (mounted) {
        setState(() {
          _currentUserLocation = LatLng(position.latitude, position.longitude);
        });
        _updateMapOverlays();
        _centerMapOnUserLocation();

        if (widget.initialDestination != null) {
          _fetchRoutes();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentUserLocation = _defaultLocation;
          _alertMessage = 'Using Bengaluru default location (GPS unavailable).';
        });
        _updateMapOverlays();
      }
    }
  }

  Future<void> _centerMapOnUserLocation() async {
    if (_currentUserLocation == null) return;
    try {
      final controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentUserLocation!,
            zoom: 15.0,
          ),
        ),
      );
    } catch (_) {}
  }

  // ==========================================================================
  // Places Autocomplete Search
  // ==========================================================================
  void _onSearchQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await _routingService.fetchPlacesSuggestions(
        query,
        bias: _currentUserLocation,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _destinationController.text = suggestion.description;
      _showSuggestions = false;
      _selectedDestinationName = suggestion.mainText;
      _isLoading = true;
    });

    final details = await _routingService.getPlaceDetails(suggestion.placeId);
    if (details != null && mounted) {
      setState(() {
        _selectedDestination = details;
      });
      _fetchRoutes();
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _alertMessage = 'Failed to locate selected destination.';
      });
    }
  }

  // ==========================================================================
  // Map Tap Handler (Destination Pinning)
  // ==========================================================================
  Future<void> _handleMapTap(LatLng tappedLocation) async {
    if (_isNavigating) return;

    setState(() {
      _selectedDestination = tappedLocation;
      _selectedDestinationName =
          'Lat: ${tappedLocation.latitude.toStringAsFixed(3)}, Lng: ${tappedLocation.longitude.toStringAsFixed(3)}';
      _destinationController.text = _selectedDestinationName!;
      _showSuggestions = false;
    });

    final String? address =
        await _routingService.reverseGeocodeLocation(tappedLocation);
    if (address != null && mounted) {
      setState(() {
        _selectedDestinationName = address;
        _destinationController.text = address;
      });
    }

    _fetchRoutes();
  }

  // ==========================================================================
  // Route Fetching & Safety Evaluation
  // ==========================================================================
  Future<void> _fetchRoutes() async {
    if (_currentUserLocation == null || _selectedDestination == null) {
      setState(() {
        _alertMessage = 'Please specify both origin and destination.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _alertMessage = null;
      _routes.clear();
      _polylines.clear();
      _markers.clear();
      _showScoreBreakdown = false;
    });

    try {
      final routes = await _routingService.fetchSafeRoutes(
        _currentUserLocation!,
        _selectedDestination!,
      );

      if (!mounted) return;

      if (routes.isNotEmpty) {
        setState(() {
          _routes = routes;
          _selectedRoute = routes.firstWhere(
            (r) => r.isRecommended,
            orElse: () => routes.first,
          );
          _isLoading = false;
        });
        _updateMapOverlays();
        _fitBoundsToRoutes();
      } else {
        setState(() {
          _isLoading = false;
          _alertMessage = 'No safe routes found for the selected destination.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _alertMessage = 'Route generation error: ${e.toString()}';
        });
      }
    }
  }

  // ==========================================================================
  // Map Markers & Polylines
  // ==========================================================================
  void _updateMapOverlays() {
    final polylines = <Polyline>{};
    final markers = <Marker>{};

    // User origin marker
    if (_currentUserLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_origin'),
          position: _currentUserLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: const InfoWindow(title: 'Your Location (Origin)'),
        ),
      );
    }

    // Destination marker
    if (_selectedDestination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _selectedDestination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _selectedDestinationName,
          ),
        ),
      );
    }

    // Polylines for each candidate route
    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      final bool isSelected = route == _selectedRoute;
      final bool isRec = route.isRecommended;

      final Color color;
      final int zIndex;

      if (isSelected && isRec) {
        color = SheTorqueTheme.primaryCyan; // Safe Recommended Route
        zIndex = 3;
      } else if (isSelected && !isRec) {
        color = SheTorqueTheme.warningAmber; // Alternate selected route
        zIndex = 3;
      } else if (isRec) {
        color = SheTorqueTheme.primaryCyan.withValues(alpha: 0.5);
        zIndex = 2;
      } else {
        color = Colors.grey.withValues(alpha: 0.5);
        zIndex = 1;
      }

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_$i'),
          points: route.polylineCoordinates,
          color: color,
          width: isSelected ? 6 : 4,
          zIndex: zIndex,
          onTap: () => _selectRoute(route),
          consumeTapEvents: true,
        ),
      );

      // Render Pink Spot markers for the currently selected route
      if (isSelected) {
        for (int h = 0; h < route.safeHavens.length; h++) {
          final haven = route.safeHavens[h];
          markers.add(
            Marker(
              markerId: MarkerId('pink_spot_${i}_$h'),
              position: haven.location,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                haven.type == 'police'
                    ? BitmapDescriptor.hueAzure
                    : (haven.type == 'hospital'
                        ? BitmapDescriptor.hueRed
                        : (haven.type == 'fire_station'
                            ? BitmapDescriptor.hueOrange
                            : BitmapDescriptor.hueRose)),
              ),
              infoWindow: InfoWindow(
                title: haven.name,
                snippet: haven.isVerified
                    ? 'Verified Pink Spot (${haven.displayType})'
                    : 'Pink Spot (${haven.displayType})',
              ),
            ),
          );
        }
      }
    }

    setState(() {
      _polylines = polylines;
      _markers = markers;
    });
  }

  void _selectRoute(SafeRouteModel route) {
    setState(() {
      _selectedRoute = route;
    });
    _updateMapOverlays();
  }

  Future<void> _fitBoundsToRoutes() async {
    if (_routes.isEmpty || _currentUserLocation == null || _selectedDestination == null) {
      return;
    }

    double minLat = _currentUserLocation!.latitude;
    double maxLat = _currentUserLocation!.latitude;
    double minLng = _currentUserLocation!.longitude;
    double maxLng = _currentUserLocation!.longitude;

    for (final r in _routes) {
      for (final pt in r.polylineCoordinates) {
        if (pt.latitude < minLat) minLat = pt.latitude;
        if (pt.latitude > maxLat) maxLat = pt.latitude;
        if (pt.longitude < minLng) minLng = pt.longitude;
        if (pt.longitude > maxLng) maxLng = pt.longitude;
      }
    }

    try {
      final controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          70.0,
        ),
      );
    } catch (_) {}
  }

  // ==========================================================================
  // Turn-by-Turn Navigation Simulation
  // ==========================================================================
  void _startNavigation() {
    if (_selectedRoute == null) return;

    setState(() {
      _isNavigating = true;
    });

    _navStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position pos) async {
      final LatLng livePos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentUserLocation = livePos;
      });

      try {
        final controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: livePos,
              zoom: 17.5,
              tilt: 45.0,
              bearing: pos.heading,
            ),
          ),
        );
      } catch (_) {}
    });
  }

  void _stopNavigation() {
    _navStreamSubscription?.cancel();
    _navStreamSubscription = null;
    setState(() {
      _isNavigating = false;
    });
    _fitBoundsToRoutes();
  }

  // ==========================================================================
  // Main UI Build
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SheTorqueTheme.background,
      body: Stack(
        children: [
          // Google Map Background
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 13.0,
            ),
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onTap: _handleMapTap,
          ),

          // Search & Destination Input Bar (Hidden during active navigation)
          if (!_isNavigating)
            SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SheTorqueTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: SheTorqueTheme.primaryCyan, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _destinationController,
                            style: const TextStyle(
                              color: SheTorqueTheme.textWhite,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search destination or tap map...',
                              hintStyle: TextStyle(
                                  color: SheTorqueTheme.textMuted, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: _onSearchQueryChanged,
                          ),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  SheTorqueTheme.primaryCyan),
                            ),
                          )
                        else if (_destinationController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: SheTorqueTheme.textMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              _destinationController.clear();
                              setState(() {
                                _selectedDestination = null;
                                _selectedDestinationName = null;
                                _routes.clear();
                                _polylines.clear();
                                _markers.clear();
                                _showSuggestions = false;
                                _showScoreBreakdown = false;
                              });
                            },
                          ),
                      ],
                    ),
                  ),

                  // Alert Banner (if any)
                  if (_alertMessage != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: SheTorqueTheme.dangerRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                SheTorqueTheme.dangerRed.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: SheTorqueTheme.dangerRed),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _alertMessage!,
                              style: const TextStyle(
                                  color: SheTorqueTheme.dangerRed, fontSize: 12),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _alertMessage = null),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: SheTorqueTheme.dangerRed),
                          ),
                        ],
                      ),
                    ),

                  // Autocomplete Suggestions List
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: SheTorqueTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SheTorqueTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _suggestions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: SheTorqueTheme.border, height: 1),
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined,
                                color: SheTorqueTheme.primaryCyan, size: 20),
                            title: Text(
                              suggestion.mainText,
                              style: const TextStyle(
                                color: SheTorqueTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              suggestion.secondaryText,
                              style: const TextStyle(
                                  color: SheTorqueTheme.textMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Center on GPS button
          Positioned(
            right: 16,
            bottom: _routes.isNotEmpty && !_isNavigating ? 260 : 20,
            child: FloatingActionButton(
              heroTag: 'recenter_gps',
              mini: true,
              backgroundColor: SheTorqueTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: SheTorqueTheme.border),
              ),
              onPressed: _centerMapOnUserLocation,
              child: const Icon(Icons.my_location_rounded,
                  color: SheTorqueTheme.primaryCyan, size: 20),
            ),
          ),

          // Bottom Sheet: Candidate Routes Comparison
          if (!_isNavigating && _routes.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildRouteComparisonSheet(),
            ),

          // Active Navigation HUD
          if (_isNavigating)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildNavigationHUD(),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Route Comparison & Bottom Sheet
  // ==========================================================================
  Widget _buildRouteComparisonSheet() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: SheTorqueTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SheTorqueTheme.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Candidate Safe Routes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
                Text(
                  '${_routes.length} routes evaluated',
                  style: const TextStyle(
                      fontSize: 12, color: SheTorqueTheme.primaryCyan),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Route Cards Horizontal Carousel
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _routes.length,
                itemBuilder: (context, index) {
                  return _buildRouteCard(_routes[index]);
                },
              ),
            ),

            // Pink Spots Network designation note
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 13, color: SheTorqueTheme.secondaryPink),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Pink Spots — nearby rider-friendly safety locations (${_selectedRoute?.safeHavens.length ?? 0} found along corridor)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: SheTorqueTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedRoute != null &&
                _selectedRoute!.recommendationReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 16, color: SheTorqueTheme.primaryCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedRoute!.recommendationReason,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: SheTorqueTheme.textWhite,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // "Why this score?" Breakdown Toggle
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showScoreBreakdown = !_showScoreBreakdown),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _showScoreBreakdown
                        ? SheTorqueTheme.primaryCyan
                        : SheTorqueTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined,
                            size: 16, color: SheTorqueTheme.primaryCyan),
                        const SizedBox(width: 8),
                        Text(
                          'Why this score? (${_selectedRoute?.safetyScore.toInt() ?? 0}/100)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: SheTorqueTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _showScoreBreakdown
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: SheTorqueTheme.primaryCyan,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            if (_showScoreBreakdown && _selectedRoute != null)
              _buildScoreBreakdownPanel(_selectedRoute!),

            const SizedBox(height: 12),

            // Start Navigation Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: Text(
                  _selectedRoute?.isRecommended == true
                      ? 'Start Safe Navigation'
                      : 'Start Navigation (Alternate Route)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedRoute?.isRecommended == true
                      ? SheTorqueTheme.primaryCyan
                      : SheTorqueTheme.warningAmber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _startNavigation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(SafeRouteModel route) {
    final bool isSelected = route == _selectedRoute;
    final bool isRec = route.isRecommended;

    final Color badgeColor = isRec
        ? SheTorqueTheme.primaryCyan
        : (route.safetyScore >= 65
            ? SheTorqueTheme.warningAmber
            : SheTorqueTheme.dangerRed);

    return InkWell(
      onTap: () => _selectRoute(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? SheTorqueTheme.surfaceLight
              : SheTorqueTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isRec ? SheTorqueTheme.primaryCyan : SheTorqueTheme.warningAmber)
                : SheTorqueTheme.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  route.duration,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: badgeColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '${route.safetyScore.toInt()}% Safe',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  route.distance,
                  style: const TextStyle(
                      fontSize: 12, color: SheTorqueTheme.textMuted),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${route.safeHavens.length} Pink Spots',
                  style: const TextStyle(
                      fontSize: 11.5, color: SheTorqueTheme.textMuted),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  isRec ? Icons.verified_rounded : Icons.alt_route_rounded,
                  size: 14,
                  color: isRec ? SheTorqueTheme.primaryCyan : SheTorqueTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isRec ? 'RECOMMENDED ROUTE' : 'Alternate Route',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isRec
                          ? SheTorqueTheme.primaryCyan
                          : SheTorqueTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Explainable "Why this score?" breakdown card displaying all four positive factors
  /// and the Karnataka 2025 Regional Crime Indicator limitations.
  Widget _buildScoreBreakdownPanel(SafeRouteModel route) {
    final breakdown = route.scoreBreakdown ??
        SafetyScoreBreakdown(
          pinkSpotScore: route.safeHavenDensity,
          mainRoadScore: route.mainRoadRatio,
          lightingScore: (100.0 - route.unlitPenalty).clamp(0.0, 100.0),
          regionalSafetyIndex: 52.0,
          pinkSpotExplanation: '${route.safeHavens.length} Pink Spots nearby',
          mainRoadExplanation: '${route.mainRoadRatio.toInt()}% major corridors',
          lightingExplanation:
              '${(100 - route.unlitPenalty).toInt()}% lit streets',
          regionalExplanation:
              '${route.regionalDistrictName} (2025 KSP baseline)',
        );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SheTorqueTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SheTorqueTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formula Banner
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.25),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXACT FORMULA (Max Score: 100)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.primaryCyan,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'PinkSpot (30%) + MainRoad (30%) + Lighting (15%) + RegionalCrime (25%)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
                Text(
                  'where LightingScore = 100 − UnlitPercentage',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: SheTorqueTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 1. Pink Spots Factor
          _buildFactorRow(
            title: 'Pink Spots Network (30% weight)',
            score: breakdown.pinkSpotScore,
            contribution: breakdown.pinkSpotContribution,
            color: SheTorqueTheme.secondaryPink,
            icon: Icons.shield_rounded,
            details: breakdown.pinkSpotExplanation,
          ),
          const SizedBox(height: 8),

          // 2. Main Road Factor
          _buildFactorRow(
            title: 'Major Road Ratio (30% weight)',
            score: breakdown.mainRoadScore,
            contribution: breakdown.mainRoadContribution,
            color: SheTorqueTheme.primaryCyan,
            icon: Icons.alt_route_rounded,
            details: breakdown.mainRoadExplanation,
          ),
          const SizedBox(height: 8),

          // 3. Lighting Factor
          _buildFactorRow(
            title: 'Street Lighting Score (15% weight)',
            score: breakdown.lightingScore,
            contribution: breakdown.lightingContribution,
            color: SheTorqueTheme.warningAmber,
            icon: Icons.lightbulb_rounded,
            details: breakdown.lightingExplanation,
          ),
          const SizedBox(height: 8),

          // 4. Regional Crime Factor
          _buildFactorRow(
            title: 'Historical Regional Crime (25% weight)',
            score: breakdown.regionalSafetyIndex,
            contribution: breakdown.regionalContribution,
            color: const Color(0xFF9D4EDD),
            icon: Icons.policy_rounded,
            details: breakdown.regionalExplanation,
          ),
          const SizedBox(height: 10),

          // Crime Dataset Transparency & Methodology Notice
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: SheTorqueTheme.textMuted),
                    SizedBox(width: 4),
                    Text(
                      'Historical Regional Crime Indicator — Dataset Notice',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '• Source: Karnataka State Police via OpenCity.in\n'
                  '• Dataset Year: 2025 (District & Commissionerate units)\n'
                  '• Granularity: Administrative district/commissionerate level only\n'
                  '• Last Updated: February 2025\n'
                  '• Notice: Historical baseline indicator, NOT live crime data or road-level GPS prediction. All routes within Bengaluru share the same commissionerate baseline indicator (37,181 IPC cases, 2025); corridor safety differentiation is determined by micro-level Pink Spot density, road classifications, and street lighting.',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: SheTorqueTheme.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorRow({
    required String title,
    required double score,
    required double contribution,
    required Color color,
    required IconData icon,
    required String details,
  }) {
    final double pct = (score / 100.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
              ],
            ),
            Text(
              '${score.toInt()}/100 (+${contribution.toStringAsFixed(1)} pts)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: SheTorqueTheme.surfaceLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          details,
          style: const TextStyle(
            fontSize: 10,
            color: SheTorqueTheme.textMuted,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Active Navigation HUD
  // ==========================================================================
  Widget _buildNavigationHUD() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SheTorqueTheme.primaryCyan),
        boxShadow: [
          BoxShadow(
            color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.15),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: SheTorqueTheme.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.navigation_rounded,
                    color: SheTorqueTheme.primaryCyan, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safe Navigation Active',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_selectedRoute?.duration ?? '—'} • ${_selectedRoute?.distance ?? '—'} remaining',
                      style: const TextStyle(
                          fontSize: 12.5, color: SheTorqueTheme.primaryCyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: SheTorqueTheme.dangerRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _stopNavigation,
              child: const Text(
                'End Navigation',
                style: TextStyle(
                  color: SheTorqueTheme.dangerRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _navStreamSubscription?.cancel();
    _debounceTimer?.cancel();
    _destinationController.dispose();
    super.dispose();
  }
}
