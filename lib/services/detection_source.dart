import '../models/vehicle_detection.dart';

/// Abstract contract for vehicle-detection data sources.
///
/// Implementations:
/// - [SimulatedDetectionSource]  – scripted scenarios at ~10 fps (demo/test).
/// - [Elm327CameraSource]        – future rear-mounted camera + ML pipeline.
abstract class DetectionSource {
  /// Stream of detection frames. Each frame is a list of all vehicles visible
  /// in that instant, possibly empty.
  Stream<List<VehicleDetection>> get detections;

  /// Begin producing frames.
  void start();

  /// Stop producing frames and release resources.
  void stop();
}
