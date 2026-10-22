import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

class OcclusionDetector {
  StreamSubscription<int>? _proximitySubscription;
  Timer? _coverageTimer;
  bool _isArmed = false;
  bool _isNear = false;

  bool get isNear => _isNear;
  
  VoidCallback? onOcclusionConfirmed;
  VoidCallback? onCancelGestureDetected;
  ValueChanged<bool>? onProximityStateChanged;

  void startMonitoring() {
    _proximitySubscription?.cancel();
    _resetTimer();
    
    _proximitySubscription = ProximitySensor.events.listen(
      (int event) {
        _onProximityReading(event);
      },
      onError: (error) {
        debugPrint("Error from proximity sensor: $error");
      }
    );
  }

  void stopMonitoring() {
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
    _coverageTimer?.cancel();
    _coverageTimer = null;
    _isArmed = false;
  }

  void setArmed(bool armed) {
    _isArmed = armed;
    _resetTimer(); 
  }

  void _onProximityReading(int proximity) {
    final bool isCovered = (proximity > 0);
    if (_isNear != isCovered) {
      _isNear = isCovered;
      onProximityStateChanged?.call(isCovered);
    }

    if (isCovered) {
      _coverageTimer ??= Timer(Duration(seconds: _isArmed ? 1 : 3), () {
        if (_isArmed) {
          onCancelGestureDetected?.call();
        } else {
          onOcclusionConfirmed?.call();
        }
        _resetTimer();
      });
    } else {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _coverageTimer?.cancel();
    _coverageTimer = null;
  }
}
