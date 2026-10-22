/// Model representing a tracked motorcycle ride.
class RideModel {
  final String id;
  final String userId;
  final String title;
  final String origin;
  final String destination;
  final double distanceKm;
  final int durationMin;
  final double safetyScore;
  final DateTime startedAt;

  RideModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationMin,
    required this.safetyScore,
    required this.startedAt,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Ride',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMin: (json['duration_min'] as num?)?.toInt() ?? 0,
      safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 100.0,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'origin': origin,
        'destination': destination,
        'distance_km': distanceKm,
        'duration_min': durationMin,
        'safety_score': safetyScore,
        'started_at': startedAt.toIso8601String(),
      };
}
