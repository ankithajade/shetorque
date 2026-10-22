import 'package:flutter/painting.dart';

/// A single vehicle detection event produced by a [DetectionSource].
class VehicleDetection {
  /// Stable tracking ID assigned to the vehicle across frames.
  final String trackId;

  /// Bounding box in normalised coordinates (0.0 – 1.0 per axis).
  final Rect bbox;

  /// Detector confidence in [0.0, 1.0].
  final double confidence;

  /// Human-readable vehicle class label (e.g. "motorcycle", "car").
  final String label;

  const VehicleDetection({
    required this.trackId,
    required this.bbox,
    required this.confidence,
    required this.label,
  });
}
