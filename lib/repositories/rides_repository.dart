import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_model.dart';

/// Repository managing rider journey logs in the Supabase `rides` table.
class RidesRepository {
  final SupabaseClient _client;

  RidesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetches all logged rides for the currently authenticated user.
  Future<List<RideModel>> getRides() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final data = await _client
          .from('rides')
          .select()
          .eq('user_id', user.id)
          .order('started_at', ascending: false);

      return (data as List).map((row) => RideModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint('RidesRepository.getRides error: $e');
      rethrow;
    }
  }

  /// Inserts a newly completed ride log.
  Future<RideModel?> createRide({
    required String title,
    required String origin,
    required String destination,
    required double distanceKm,
    required int durationMin,
    required double safetyScore,
    DateTime? startedAt,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final data = await _client.from('rides').insert({
        'user_id': user.id,
        'title': title,
        'origin': origin,
        'destination': destination,
        'distance_km': distanceKm,
        'duration_min': durationMin,
        'safety_score': safetyScore,
        'started_at': (startedAt ?? DateTime.now()).toIso8601String(),
      }).select().single();

      return RideModel.fromJson(data);
    } catch (e) {
      debugPrint('RidesRepository.createRide error: $e');
      return null;
    }
  }
}
