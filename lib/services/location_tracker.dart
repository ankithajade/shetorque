import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'sms_service.dart';

class LocationTracker {
  static final LocationTracker _instance = LocationTracker._internal();
  factory LocationTracker() => _instance;
  LocationTracker._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _periodicSmsTimer;
  Timer? _sessionExpiryTimer;
  
  Position? _lastKnownPosition;
  int _updateCount = 0;
  bool _isDispatching = false;
  
  VoidCallback? onSessionExpired;

  void startTracking({VoidCallback? onExpired}) {
    _updateCount = 0;
    _isDispatching = false;
    onSessionExpired = onExpired;
    _positionStream?.cancel();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // metres
      ),
    ).listen((Position position) {
      _lastKnownPosition = position;
      _triggerUpdate();
    });

    _periodicSmsTimer?.cancel();
    _periodicSmsTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_lastKnownPosition != null) {
        _triggerUpdate();
      }
    });

    // 30 minute expiry
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = Timer(const Duration(minutes: 30), () {
      _handleSessionExpiry();
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    
    _periodicSmsTimer?.cancel();
    _periodicSmsTimer = null;
    
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
    
    _lastKnownPosition = null;
  }

  Future<void> _triggerUpdate() async {
    if (_isDispatching || _lastKnownPosition == null) return;
    _isDispatching = true;
    _updateCount++;
    try {
      await SmsService.sendLocationUpdate(_lastKnownPosition!, _updateCount);
    } finally {
      // Cooldown to prevent duplicate dispatch if timers fire similarly
      await Future.delayed(const Duration(seconds: 10));
      _isDispatching = false;
    }
  }

  void _handleSessionExpiry() {
    if (_lastKnownPosition != null) {
      _updateCount++;
      SmsService.sendLocationUpdate(_lastKnownPosition!, _updateCount);
    }
    stopTracking();
    if (onSessionExpired != null) {
      onSessionExpired!();
    }
  }
}
