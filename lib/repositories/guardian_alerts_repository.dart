import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/guardian_alert_model.dart';

/// Repository managing suspicious follower and guardian warnings in the Supabase `guardian_alerts` table.
class GuardianAlertsRepository {
  final SupabaseClient _client;

  GuardianAlertsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Best-effort async logging of a guardian / suspicious follower alert.
  Future<void> createAlert({
    String? vehicleId,
    required int followedSeconds,
    String mode = 'single',
    String source = 'app',
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final insertData = <String, dynamic>{
        'user_id': user.id,
        'followed_seconds': followedSeconds,
        'mode': mode,
        'source': source,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (vehicleId != null) insertData['vehicle_id'] = vehicleId;

      await _client.from('guardian_alerts').insert(insertData);
    } catch (e) {
      debugPrint('GuardianAlertsRepository.createAlert (best-effort) error: $e');
    }
  }

  /// Fetches logged guardian alerts for the authenticated user.
  Future<List<GuardianAlertModel>> getAlerts() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final data = await _client
          .from('guardian_alerts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (data as List)
          .map((row) => GuardianAlertModel.fromJson(row))
          .toList();
    } catch (e) {
      debugPrint('GuardianAlertsRepository.getAlerts error: $e');
      rethrow;
    }
  }
}
