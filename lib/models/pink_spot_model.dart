/// Model representing a safe haven / pink spot pinned on the map.
class PinkSpotModel {
  final String id;
  final String userId;
  final String name;
  final String category; // 'police' | 'hospital' | 'fuel' | 'safe_zone' | 'mechanic'
  final double lat;
  final double lng;
  final String? notes;

  PinkSpotModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.notes,
  });

  factory PinkSpotModel.fromJson(Map<String, dynamic> json) {
    return PinkSpotModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Pink Spot',
      category: json['category'] as String? ?? 'safe_zone',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
    );
  }

  String get displayCategory {
    switch (category) {
      case 'police':
        return 'Police Station';
      case 'hospital':
        return 'Hospital';
      case 'fuel_station':
      case 'fuel':
        return 'Fuel Station';
      case 'safe_zone':
        return 'Safe Zone';
      case 'mechanic':
        return '24/7 Mechanic';
      default:
        return category.replaceAll('_', ' ').toUpperCase();
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'category': category,
        'lat': lat,
        'lng': lng,
        if (notes != null) 'notes': notes,
      };
}
