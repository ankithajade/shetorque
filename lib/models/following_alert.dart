/// Alert emitted by [FollowerTracker] when a vehicle has been continuously
/// present beyond the configured persistence threshold.
class FollowingAlert {
  /// Tracking ID of the following vehicle.
  final String trackId;

  /// Total seconds the vehicle has been continuously present.
  final int followedSeconds;

  const FollowingAlert({
    required this.trackId,
    required this.followedSeconds,
  });

  @override
  String toString() =>
      'FollowingAlert(trackId: $trackId, followedSeconds: $followedSeconds)';
}
