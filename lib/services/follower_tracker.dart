import '../models/following_alert.dart';
import '../models/vehicle_detection.dart';

/// Per-vehicle tracking state managed by [FollowerTracker].
class _TrackState {
  final DateTime firstSeen;
  DateTime lastSeen;
  bool alertEmitted = false;

  _TrackState({
    required this.firstSeen,
    required this.lastSeen,
  });
}

/// Pure-logic following-vehicle tracker. Has zero simulation inside; driven by
/// an injectable clock so unit tests can control time deterministically.
///
/// Rules:
///   1. A vehicle that reappears within [gapToleranceSeconds] after a dropout
///      is considered *continuously present* (gap does not reset persistence).
///   2. When continuous presence exceeds [thresholdSeconds], exactly one
///      [FollowingAlert] is emitted for that episode.
///   3. A trusted-mesh whitelist suppresses alerts in Group Ride mode.
///   4. A vehicle that disappears for longer than [gapToleranceSeconds] has
///      its episode reset – a new alert can be emitted on next reappearance.
class FollowerTracker {
  /// Seconds a vehicle must be continuously present to trigger an alert.
  final int thresholdSeconds;

  /// Seconds a vehicle may be absent and still be considered the same episode.
  final int gapToleranceSeconds;

  /// Set of whitelisted trackIds (Group Ride trusted-mesh).
  final Set<String> trustedMesh;

  /// Injectable clock function – defaults to wall time but replaced in tests.
  final DateTime Function() clock;

  FollowerTracker({
    this.thresholdSeconds = 20,
    this.gapToleranceSeconds = 3,
    Set<String>? trustedMesh,
    DateTime Function()? clock,
  })  : trustedMesh = trustedMesh ?? {},
        clock = clock ?? (() => DateTime.now());

  final Map<String, _TrackState> _tracks = {};

  /// Process one frame of detections. Returns any new [FollowingAlert]s.
  List<FollowingAlert> process(List<VehicleDetection> frame) {
    final now = clock();
    final seenIds = frame.map((d) => d.trackId).toSet();

    // Update last-seen timestamp for vehicles in this frame.
    for (final detection in frame) {
      final id = detection.trackId;
      if (_tracks.containsKey(id)) {
        _tracks[id]!.lastSeen = now;
      } else {
        _tracks[id] = _TrackState(firstSeen: now, lastSeen: now);
      }
    }

    // Expire tracks absent longer than gap tolerance.
    _tracks.removeWhere((id, state) {
      if (seenIds.contains(id)) return false;
      final absentSeconds = now.difference(state.lastSeen).inSeconds;
      return absentSeconds > gapToleranceSeconds;
    });

    // Collect alerts.
    final alerts = <FollowingAlert>[];
    for (final entry in _tracks.entries) {
      final id = entry.key;
      final state = entry.value;

      // Skip vehicles not in this frame (still within gap tolerance).
      if (!seenIds.contains(id)) continue;

      // Skip whitelisted IDs.
      if (trustedMesh.contains(id)) continue;

      // Skip if alert already emitted for this episode.
      if (state.alertEmitted) continue;

      final presentSeconds = now.difference(state.firstSeen).inSeconds;
      if (presentSeconds >= thresholdSeconds) {
        state.alertEmitted = true;
        alerts.add(FollowingAlert(
          trackId: id,
          followedSeconds: presentSeconds,
        ));
      }
    }

    return alerts;
  }

  /// Snapshot of current track states for UI display.
  ///
  /// Returns a map of trackId → seconds followed (clamped to present time).
  Map<String, int> get currentTrackedSeconds {
    final now = clock();
    return {
      for (final e in _tracks.entries)
        e.key: now.difference(e.value.firstSeen).inSeconds,
    };
  }

  /// Remove a vehicle from tracking (e.g., on whitelist add).
  void removeTrack(String trackId) => _tracks.remove(trackId);

  /// Wipe all tracking state (e.g., on scenario change).
  void reset() => _tracks.clear();
}
