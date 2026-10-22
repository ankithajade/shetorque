import 'dart:async';
import 'dart:math';
import 'package:flutter/painting.dart';

import '../models/vehicle_detection.dart';
import 'detection_source.dart';

/// Scripted simulation scenarios at ~10 fps with realistic jitter and dropouts.
///
/// Three scenarios:
///   0 – Normal traffic: vehicles appear, overtake, and leave.
///   1 – Following vehicle: one persistent ID stays behind throughout with
///       occasional 1-2 s dropouts to exercise gap-tolerance logic.
///   2 – Group ride: three vehicles travel together, all group members.
///
/// The smartphone camera is the intended real sensor; this class is a pure
/// simulation stand-in. All UI must label this feed "SIMULATED FEED".
class SimulatedDetectionSource implements DetectionSource {
  int scenarioIndex;

  SimulatedDetectionSource({this.scenarioIndex = 0});

  final _rng = Random();
  StreamController<List<VehicleDetection>>? _controller;
  Timer? _timer;

  // -- Following-vehicle scenario internal state --
  int _followTick = 0;
  int _dropoutRemaining = 0;

  // -- Normal traffic internal state --
  final List<_TrafficVehicle> _trafficVehicles = [];
  int _trafficTick = 0;

  @override
  Stream<List<VehicleDetection>> get detections {
    _controller ??= StreamController<List<VehicleDetection>>.broadcast();
    return _controller!.stream;
  }

  @override
  void start() {
    _controller ??= StreamController<List<VehicleDetection>>.broadcast();
    _timer?.cancel();
    _followTick = 0;
    _dropoutRemaining = 0;
    _trafficTick = 0;
    _trafficVehicles.clear();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _tick);
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
  }

  void _tick(Timer t) {
    if (_controller == null || !(_controller!.hasListener)) return;
    List<VehicleDetection> frame;
    switch (scenarioIndex) {
      case 1:
        frame = _followingScenarioFrame();
        break;
      case 2:
        frame = _groupRideFrame();
        break;
      default:
        frame = _normalTrafficFrame();
    }
    if (_controller?.isClosed == false) {
      _controller!.add(frame);
    }
  }

  // ─── Scenario 0: Normal Traffic ──────────────────────────────────────────
  List<VehicleDetection> _normalTrafficFrame() {
    _trafficTick++;

    // Spawn a new vehicle every ~3 s
    if (_trafficTick % 30 == 0) {
      _trafficVehicles.add(_TrafficVehicle(
        id: 'NT-${_trafficTick ~/ 30}',
        label: _rng.nextBool() ? 'motorcycle' : 'car',
        startX: 0.4 + _rng.nextDouble() * 0.2,
        speed: 0.004 + _rng.nextDouble() * 0.006,
      ));
    }

    // Remove vehicles that have moved off screen
    _trafficVehicles.removeWhere((v) => v.y < -0.15);

    final detections = <VehicleDetection>[];
    for (final v in _trafficVehicles) {
      v.y -= v.speed;
      if (v.y < 0.05 || v.y > 1.0) continue;
      detections.add(VehicleDetection(
        trackId: v.id,
        bbox: _jitterRect(
          Rect.fromLTWH(v.startX - 0.06, v.y, 0.12, 0.10),
        ),
        confidence: _jitterConf(0.82),
        label: v.label,
      ));
    }
    return detections;
  }

  // ─── Scenario 1: Following Vehicle ───────────────────────────────────────
  List<VehicleDetection> _followingScenarioFrame() {
    _followTick++;
    final detections = <VehicleDetection>[];

    // --- Persistent follower with dropout ---
    if (_dropoutRemaining > 0) {
      _dropoutRemaining--;
    } else {
      // Schedule a random 1–2 s dropout every ~15 s
      if (_followTick % 150 == 0) {
        _dropoutRemaining = 10 + _rng.nextInt(10); // 1.0–2.0 s at 10 fps
      } else {
        detections.add(VehicleDetection(
          trackId: 'FOLLOWER-1',
          bbox: _jitterRect(
            const Rect.fromLTWH(0.38, 0.72, 0.24, 0.20),
          ),
          confidence: _jitterConf(0.91),
          label: 'motorcycle',
        ));
      }
    }

    // --- Occasional passing vehicle ---
    if (_followTick % 45 < 15) {
      final progress = (_followTick % 45) / 15.0;
      detections.add(VehicleDetection(
        trackId: 'PASSING-${_followTick ~/ 45}',
        bbox: _jitterRect(
          Rect.fromLTWH(0.62, 0.5 + progress * 0.4, 0.10, 0.08),
        ),
        confidence: _jitterConf(0.77),
        label: 'car',
      ));
    }

    return detections;
  }

  // ─── Scenario 2: Group Ride ───────────────────────────────────────────────
  List<VehicleDetection> _groupRideFrame() {
    _followTick++;
    return [
      VehicleDetection(
        trackId: 'GROUP-A',
        bbox: _jitterRect(const Rect.fromLTWH(0.25, 0.65, 0.18, 0.15)),
        confidence: _jitterConf(0.88),
        label: 'motorcycle',
      ),
      VehicleDetection(
        trackId: 'GROUP-B',
        bbox: _jitterRect(const Rect.fromLTWH(0.45, 0.70, 0.18, 0.15)),
        confidence: _jitterConf(0.85),
        label: 'motorcycle',
      ),
      VehicleDetection(
        trackId: 'GROUP-C',
        bbox: _jitterRect(const Rect.fromLTWH(0.62, 0.65, 0.18, 0.15)),
        confidence: _jitterConf(0.83),
        label: 'motorcycle',
      ),
    ];
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Rect _jitterRect(Rect r) {
    const j = 0.008;
    return Rect.fromLTWH(
      r.left + (_rng.nextDouble() * 2 - 1) * j,
      r.top + (_rng.nextDouble() * 2 - 1) * j,
      r.width + (_rng.nextDouble() * 2 - 1) * j * 0.5,
      r.height + (_rng.nextDouble() * 2 - 1) * j * 0.5,
    );
  }

  double _jitterConf(double base) =>
      (base + (_rng.nextDouble() * 2 - 1) * 0.04).clamp(0.0, 1.0);
}

class _TrafficVehicle {
  final String id;
  final String label;
  final double startX;
  final double speed;
  double y;

  _TrafficVehicle({
    required this.id,
    required this.label,
    required this.startX,
    required this.speed,
  }) : y = 1.15;
}
