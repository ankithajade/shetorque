import '../models/ecu_data.dart';

/// Abstract contract for motorcycle telemetry data providers.
///
/// Implementations may provide simulated software data ([MockEcuService])
/// or physical hardware streams via Bluetooth Low Energy OBD-II dongles
/// (such as a future `Elm327BleService`), allowing the UI to remain
/// completely agnostic of the telemetry source.
abstract class VehicleTelemetryService {
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
