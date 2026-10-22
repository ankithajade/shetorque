import 'dart:async';
import 'dart:math';

import '../models/ecu_data.dart';
import 'vehicle_telemetry_service.dart';

/// Software Mock ECU Engine for SheTorque's Vehicle Diagnostics and Digital Garage.
///
/// Implements [VehicleTelemetryService] by streaming realistic, continuously-updating
/// telemetry (fuel %, engine temp °C, battery voltage V, engine RPM, vehicle speed km/h,
/// and SAE J2012 DTC codes) without requiring physical OBD-II hardware.
///
/// Preserves the simulation physics and threshold logic from ref/bhavana-mock-ecu
/// while enabling a shared singleton architecture to prevent duplicate timers.
class MockEcuService implements VehicleTelemetryService {
  // Singleton pattern to ensure Garage and Diagnostics share the exact same stream
  static final MockEcuService _instance = MockEcuService._internal();
  factory MockEcuService() => _instance;
  static MockEcuService get instance => _instance;

  MockEcuService.custom({
    this.tickInterval = const Duration(seconds: 1),
    double initialFuel = 78.0,
    double initialTemp = 32.0,
    double initialVoltage = 12.6,
  })  : _fuel = initialFuel,
        _temp = initialTemp,
        _voltage = initialVoltage;

  MockEcuService._internal()
      : tickInterval = const Duration(seconds: 1),
        _fuel = 78.0,
        _temp = 32.0,
        _voltage = 12.6;

  final Duration tickInterval;
  final Random _rng = Random();
  Timer? _timer;
  final StreamController<EcuData> _controller =
      StreamController<EcuData>.broadcast();

  double _fuel;
  double _temp;
  double _voltage;
  int _rpm = 1250;
  double _speed = 0.0;
  int _ticks = 0;

  /// Number of telemetry ticks processed.
  int get ticks => _ticks;

  /// Optional scenario forcing flags for presentations and technical demonstrations.
  bool forceLowFuel = false;
  bool forceOverheat = false;
  bool forceLowBattery = false;

  @override
  Stream<EcuData> get telemetryStream => _controller.stream;

  @override
  EcuData get currentData => current;

  @override
  bool get isStreaming => _timer != null && _timer!.isActive;

  /// Backward-compatible alias for Bhavana's original API
  Stream<EcuData> get stream => _controller.stream;

  /// Current snapshot of vehicle telemetry
  EcuData get current => EcuData(
        fuelLevelPercent: _fuel,
        engineTempCelsius: _temp,
        batteryVoltage: _voltage,
        rpm: _rpm,
        speedKmH: _speed,
        warnings: EcuThresholds.evaluate(_fuel, _temp, _voltage),
        dtcCodes: EcuThresholds.evaluateDtc(_fuel, _temp, _voltage),
        timestamp: DateTime.now(),
      );

  @override
  void start() {
    if (_timer != null && _timer!.isActive) return;
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => _tick());
    // Emit immediate reading so subscribers receive data instantly
    _controller.add(current);
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    // Do not close the broadcast controller permanently if we want to allow re-initialization,
    // but if necessary provide a fresh controller on demand.
  }

  void _tick() {
    _ticks++;

    // --- Fuel: drains gradually with small variance ---
    final fuelDrain = forceLowFuel ? 0.35 : 0.02;
    _fuel -= fuelDrain + _rng.nextDouble() * 0.03;
    _fuel = _fuel.clamp(0.0, 100.0);

    // --- Engine Temp: warms up from cold start, then hovers around 88-93°C ---
    const double operatingTemp = 90.0;
    if (_temp < operatingTemp) {
      _temp += 1.2 + _rng.nextDouble() * 0.6; // warm-up ramp
    } else {
      _temp += (_rng.nextDouble() - 0.5) * 1.5; // cruise fluctuation
    }
    if (forceOverheat) _temp += 2.5;
    _temp = _temp.clamp(15.0, 130.0);

    // --- Battery Voltage: alternator regulation with gentle drift ---
    final voltageDrift =
        forceLowBattery ? -0.03 : (_rng.nextDouble() - 0.5) * 0.02;
    _voltage += voltageDrift;
    _voltage = _voltage.clamp(9.5, 14.6);

    // --- Dynamic RPM & Speed Simulation: motorcycle riding mechanics ---
    if (_temp < 60.0) {
      // Warm-up idle
      _rpm = (1350 + (_rng.nextDouble() - 0.5) * 80).toInt();
      _speed = 0.0;
    } else {
      // Moderate suburban cruise
      _speed = (48.0 + (_rng.nextDouble() - 0.5) * 6.0).clamp(0.0, 120.0);
      _rpm = (3800 + (_speed * 25) + (_rng.nextDouble() - 0.5) * 150).toInt();
    }

    _controller.add(current);
  }

  /// Resets simulation state back to healthy baseline values.
  void reset({double fuel = 78.0, double temp = 32.0, double voltage = 12.6}) {
    _fuel = fuel;
    _temp = temp;
    _voltage = voltage;
    _rpm = 1250;
    _speed = 0.0;
    forceLowFuel = false;
    forceOverheat = false;
    forceLowBattery = false;
    _controller.add(current);
  }
}
