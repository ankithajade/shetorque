import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pink_spot_model.dart';

/// Repository managing community-verified safe havens in the Supabase `pink_spots` table.
///
/// Readable by everyone, insertable by the authenticated owner.
class PinkSpotsRepository {
  final SupabaseClient _client;

  PinkSpotsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetches all public Pink Spots across the network.
  Future<List<PinkSpotModel>> getPinkSpots() async {
    try {
      final data = await _client.from('pink_spots').select().order('name');
      return (data as List).map((row) => PinkSpotModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint('PinkSpotsRepository.getPinkSpots error: $e');
      rethrow;
    }
  }

  /// Inserts a newly nominated Pink Spot.
  Future<PinkSpotModel?> addPinkSpot({
    required String name,
    required String category,
    required double lat,
    required double lng,
    String? notes,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final data = await _client.from('pink_spots').insert({
        'user_id': user.id,
        'name': name,
        'category': category,
        'lat': lat,
        'lng': lng,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      }).select().single();

      return PinkSpotModel.fromJson(data);
    } catch (e) {
      debugPrint('PinkSpotsRepository.addPinkSpot error: $e');
      rethrow;
    }
  }
}
