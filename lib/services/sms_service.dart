import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sos_session_manager.dart';
import 'supabase_auth_service.dart';
import '../repositories/sos_events_repository.dart';

/// Service responsible for dispatching autonomous emergency SMS alerts.
///
/// Guaranteed zero network dependency during an active emergency by strictly
/// reading the cached recipient phone from [SharedPreferences].
class SmsService {
  static const _smsChannel = MethodChannel('com.shetorque.hub/sms');
  static final SosEventsRepository _sosRepo = SosEventsRepository();

  /// Resolves the emergency contact phone number strictly from local SharedPreferences cache.
  /// NEVER makes any network calls. Returns null if no contact is configured.
  static Future<String?> resolveEmergencyContact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contact =
          prefs.getString(SupabaseAuthService.kCachedEmergencyContact)?.trim();
      if (contact != null && contact.isNotEmpty) return contact;
    } catch (e) {
      debugPrint('Error reading cached emergency contact: $e');
    }
    return null;
  }

  // Used by CRASH SOS
  static Future<bool> sendCrashAlert(Position position) async {
    final contact = await resolveEmergencyContact();
    if (contact == null || contact.isEmpty) {
      debugPrint(
          'SmsService: Cannot send crash alert. No emergency contact configured in local cache.');
      // Best-effort database log even if SMS cannot be sent
      _logSosBestEffort('crash', position.latitude, position.longitude);
      return false;
    }

    String mapLink =
        "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
    String message =
        "EMERGENCY: SheTorque Hub detected a crash! Rider is unresponsive. Location: $mapLink";

    // 1. Dispatch SMS immediately via native Android channel (critical priority)
    await _smsChannel.invokeMethod('sendSms', {
      'phone': contact,
      'message': message,
    });

    // 2. Best-effort logging to Supabase in background (never blocks SMS)
    _logSosBestEffort('crash', position.latitude, position.longitude);
    return true;
  }

  // Used by SILENT SOS — SMS #1
  static Future<bool> sendStealthAlert(Position position) async {
    final contact = await resolveEmergencyContact();
    if (contact == null || contact.isEmpty) {
      debugPrint(
          'SmsService: Cannot send stealth alert. No emergency contact configured in local cache.');
      _logSosBestEffort('silent', position.latitude, position.longitude);
      return false;
    }

    String name = await SosSessionManager.getRiderName() ?? "the rider";
    String mapLink =
        "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String time = _formatTime(DateTime.now());
    String date = _formatDate(DateTime.now());

    String message = "[SheTorque] SILENT ALERT\n"
        "$name may need help.\n\n"
        "Location: $mapLink\n"
        "Time: $time, $date\n\n"
        "DO NOT CALL. Send an SMS or contact authorities.\n"
        "Location will update every 5 minutes.";

    await _smsChannel.invokeMethod('sendSms', {
      'phone': contact,
      'message': message,
    });

    _logSosBestEffort('silent', position.latitude, position.longitude);
    return true;
  }

  // Used by SILENT SOS — update SMS
  static Future<bool> sendLocationUpdate(
      Position position, int updateCount) async {
    final contact = await resolveEmergencyContact();
    if (contact == null || contact.isEmpty) return false;

    String name = await SosSessionManager.getRiderName() ?? "the rider";
    String mapLink =
        "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String time = _formatTime(DateTime.now());

    String message = "[SheTorque] LOCATION UPDATE (#$updateCount)\n"
        "$name — updated location:\n\n"
        "$mapLink\n"
        "Time: $time\n\n"
        "Alert still active.";

    await _smsChannel.invokeMethod('sendSms', {
      'phone': contact,
      'message': message,
    });
    return true;
  }

  // Used by SILENT SOS — resolution
  static Future<bool> sendSafeConfirmation() async {
    final contact = await resolveEmergencyContact();
    if (contact == null || contact.isEmpty) return false;

    String name = await SosSessionManager.getRiderName() ?? "the rider";
    String time = _formatTime(DateTime.now());

    String message = "[SheTorque] ALL CLEAR\n"
        "$name has confirmed she is safe.\n\n"
        "Time: $time\n"
        "Location tracking stopped.";

    await _smsChannel.invokeMethod('sendSms', {
      'phone': contact,
      'message': message,
    });
    return true;
  }

  static void _logSosBestEffort(String type, double lat, double lng) {
    try {
      _sosRepo
          .logSosEvent(type: type, lat: lat, lng: lng)
          .catchError((_) => null);
    } catch (_) {}
  }

  static String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  static String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }
}
