/// Model representing a suspicious follower / guardian safety alert.
class GuardianAlertModel {
  final String id;
  final String userId;
  final String? vehicleId;
  final int followedSeconds;
  final String mode; // 'single' | 'group'
  final String source;
  final DateTime createdAt;

  GuardianAlertModel({
    required this.id,
    required this.userId,
    this.vehicleId,
    required this.followedSeconds,
    required this.mode,
    required this.source,
    required this.createdAt,
  });

  factory GuardianAlertModel.fromJson(Map<String, dynamic> json) {
    return GuardianAlertModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String?,
      followedSeconds: (json['followed_seconds'] as num?)?.toInt() ?? 0,
      mode: json['mode'] as String? ?? 'single',
      source: json['source'] as String? ?? 'app',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'vehicle_id': vehicleId,
        'followed_seconds': followedSeconds,
        'mode': mode,
        'source': source,
        'created_at': createdAt.toIso8601String(),
      };
}
