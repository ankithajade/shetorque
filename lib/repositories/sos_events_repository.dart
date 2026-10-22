import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sos_event_model.dart';

/// Repository managing crash and stealth SOS emergency events in the Supabase `sos_events` table.
///
/// All write operations are best-effort and NEVER block or delay SMS alerts.
class SosEventsRepository {
  final SupabaseClient _client;

  SosEventsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Best-effort async logging of an emergency SOS event.
  /// Wrapped in try/catch to ensure zero impact on emergency execution.
  Future<String?> logSosEvent({
    required String type,
    required double lat,
    required double lng,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final data = await _client.from('sos_events').insert({
        'user_id': user.id,
        'type': type,
        'lat': lat,
        'lng': lng,
        'resolved': false,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      return data['id'] as String?;
    } catch (e) {
      debugPrint('SosEventsRepository.logSosEvent (best-effort) error: $e');
      return null;
    }
  }

  /// Marks an ongoing SOS event as safely resolved.
  Future<void> resolveSosEvent(String eventId) async {
    try {
      await _client.from('sos_events').update({
        'resolved': true,
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', eventId);
    } catch (e) {
      debugPrint('SosEventsRepository.resolveSosEvent error: $e');
    }
  }

  /// Fetches historical emergency SOS events for the user.
  Future<List<SosEventModel>> getSosHistory() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final data = await _client
          .from('sos_events')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (data as List).map((row) => SosEventModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint('SosEventsRepository.getSosHistory error: $e');
      rethrow;
    }
  }
}
