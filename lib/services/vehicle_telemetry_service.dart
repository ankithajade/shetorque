import '../models/ecu_data.dart';

/// Abstract contract for motorcycle telemetry data providers.
///
/// Implementations may provide simulated software data ([MockEcuService])
/// or physical hardware streams via Bluetooth Low Energy OBD-II dongles
/// ([Elm327BluetoothSource]), allowing the UI to remain completely agnostic
/// of the underlying telemetry source.
abstract class TelemetrySource {
  /// Continuous stream of real-time ECU telemetry readings.
  Stream<EcuData> get telemetryStream;

  /// The most recent telemetry snapshot received.
  EcuData get currentData;

  /// Indicates whether the telemetry engine is actively polling/streaming.
  bool get isStreaming;

  /// Starts the telemetry streaming service.
  void start();

  /// Pauses or temporarily halts streaming.
  void stop();

  /// Releases resources, cancels timers, and closes broadcast controllers.
  void dispose();
}

/// Backward compatibility alias for [TelemetrySource].
typedef VehicleTelemetryService = TelemetrySource;

/// Future hardware implementation stub for physical ELM327 Bluetooth OBD-II adapters.
///
/// Throws [UnimplementedError] across all operations. Documented as a placeholder
/// for future Bluetooth SPP / RFCOMM hardware integration, preserving architectural
/// separation from the UI.
class Elm327BluetoothSource implements TelemetrySource {
  const Elm327BluetoothSource();

  @override
  Stream<EcuData> get telemetryStream =>
      throw UnimplementedError('ELM327 Bluetooth adapter stream is not yet implemented.');

  @override
  EcuData get currentData =>
      throw UnimplementedError('ELM327 Bluetooth adapter telemetry is not yet implemented.');

  @override
  bool get isStreaming => false;

  @override
  void start() =>
      throw UnimplementedError('ELM327 Bluetooth adapter connection is not yet implemented.');

  @override
  void stop() =>
      throw UnimplementedError('ELM327 Bluetooth adapter disconnection is not yet implemented.');

  @override
  void dispose() {}
}
