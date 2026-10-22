/// Model representing an emergency SOS event (crash or stealth).
class SosEventModel {
  final String id;
  final String userId;
  final String type; // 'crash' | 'silent'
  final double lat;
  final double lng;
  final bool resolved;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  SosEventModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.lat,
    required this.lng,
    required this.resolved,
    required this.createdAt,
    this.resolvedAt,
  });

  factory SosEventModel.fromJson(Map<String, dynamic> json) {
    return SosEventModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'crash',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      resolved: json['resolved'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'lat': lat,
        'lng': lng,
        'resolved': resolved,
        'created_at': createdAt.toIso8601String(),
        if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
      };
}
