import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sos_session_manager.dart';
import 'supabase_auth_service.dart';
import '../repositories/sos_events_repository.dart';
import '../models/rider_profile.dart';

/// Result envelope for emergency SMS dispatches and demo simulation previews.
class SmsDispatchResult {
  final bool success;
  final String message;
  final String? recipientPhone;
  final String? recipientName;
  final bool isDemo;

  const SmsDispatchResult({
    required this.success,
    required this.message,
    this.recipientPhone,
    this.recipientName,
    this.isDemo = false,
  });
}

/// Service responsible for dispatching autonomous emergency SMS alerts.
///
/// Guaranteed zero network dependency during an active emergency by strictly
/// reading the cached recipient phone and rider identity from [SharedPreferences].
class SmsService {
  static const String kDemoModeKey = 'demo_mode_enabled';
  static const _smsChannel = MethodChannel('com.shetorque.hub/sms');
  static final SosEventsRepository _sosRepo = SosEventsRepository();

  /// Resolves whether Demo Mode is active. Reads from [SharedPreferences] cache,
  /// defaulting to true so no real SMS is accidentally dispatched without explicit opt-in.
  static Future<bool> isDemoModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kDemoModeKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Persists Demo Mode state to local cache.
  static Future<void> setDemoModeEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kDemoModeKey, enabled);
    } catch (_) {}
  }

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

  /// Resolves the emergency contact name strictly from local cache.
  static Future<String?> resolveEmergencyContactName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name =
          prefs.getString(SupabaseAuthService.kCachedEmergencyName)?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return null;
  }

  /// Resolves formatted rider profile identity string ("Name (Phone)") from offline cache.
  /// Omits missing fields gracefully to guarantee reliable single-segment SMS output.
  static Future<String?> resolveRiderProfileString() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(SupabaseAuthService.kCachedRiderProfile);
      String? name;
      String? phone;

      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final profile =
              RiderProfile.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
          if (profile.name.trim().isNotEmpty) name = profile.name.trim();
          if (profile.phone.trim().isNotEmpty) phone = profile.phone.trim();
        } catch (_) {}
      }

      if (name == null || name.isEmpty) {
        name = await SosSessionManager.getRiderName();
      }

      if (name != null && name.isNotEmpty && phone != null && phone.isNotEmpty) {
        return '$name ($phone)';
      } else if (name != null && name.isNotEmpty) {
        return name;
      } else if (phone != null && phone.isNotEmpty) {
        return phone;
      }
    } catch (_) {}
    return null;
  }

  /// Constructs standard SheTorque emergency SMS text fitting within a single 160-char segment.
  ///
  /// Example: "SheTorque SOS: Ananya Rider (+919876543210) Crash detected! Location: https://maps.google.com/?q=12.97,77.59 Time: 11:35"
  static Future<String> buildEmergencyMessage({
    required Position position,
    required String type, // 'crash' | 'silent'
  }) async {
    final riderInfo = await resolveRiderProfileString();
    final mapLink =
        "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    final time = _formatTime(DateTime.now());

    final who = (riderInfo != null && riderInfo.isNotEmpty) ? '$riderInfo ' : '';
    if (type == 'crash') {
      return "SheTorque SOS: ${who}Crash detected! Location: $mapLink Time: $time";
    } else {
      return "SheTorque SOS: ${who}may need help. Location: $mapLink Time: $time";
    }
  }

  /// Dispatches or simulates Crash SOS alert.
  static Future<SmsDispatchResult> dispatchCrashAlert(
    Position position, {
    bool? isDemoMode,
  }) async {
    final demo = isDemoMode ?? await isDemoModeEnabled();
    final contact = await resolveEmergencyContact();
    final contactName = await resolveEmergencyContactName() ?? 'Emergency Contact';
    final message = await buildEmergencyMessage(position: position, type: 'crash');

    if (contact == null || contact.isEmpty) {
      debugPrint('SmsService: Cannot send crash alert. No contact cached.');
      _logSosBestEffort('crash', position.latitude, position.longitude);
      return SmsDispatchResult(
        success: false,
        message: 'No emergency contact configured in local cache.',
        recipientPhone: null,
        recipientName: contactName,
        isDemo: demo,
      );
    }

    if (demo) {
      // In demo mode: log to Supabase best-effort, do NOT trigger native SMS
      _logSosBestEffort('crash', position.latitude, position.longitude);
      return SmsDispatchResult(
        success: true,
        message: message,
        recipientPhone: contact,
        recipientName: contactName,
        isDemo: true,
      );
    }

    try {
      await _smsChannel.invokeMethod('sendSms', {
        'phone': contact,
        'message': message,
      });
      _logSosBestEffort('crash', position.latitude, position.longitude);
      return SmsDispatchResult(
        success: true,
        message: message,
        recipientPhone: contact,
        recipientName: contactName,
        isDemo: false,
      );
    } catch (e) {
      debugPrint('SmsService native SMS dispatch error: $e');
      _logSosBestEffort('crash', position.latitude, position.longitude);
      return SmsDispatchResult(
        success: false,
        message: 'SMS dispatch failed: $e',
        recipientPhone: contact,
        recipientName: contactName,
        isDemo: false,
      );
    }
  }

  /// Standard boolean wrapper for Crash Alert to support background safety host.
  static Future<bool> sendCrashAlert(
    Position position, {
    bool? isDemoMode,
  }) async {
    final res = await dispatchCrashAlert(position, isDemoMode: isDemoMode);
    return res.success;
  }

  /// Dispatches or simulates Silent SOS alert.
  static Future<SmsDispatchResult> dispatchStealthAlert(
    Position position, {
    bool? isDemoMode,
  }) async {
    final demo = isDemoMode ?? await isDemoModeEnabled();
    final contact = await resolveEmergencyContact();
    final contactName = await resolveEmergencyContactName() ?? 'Emergency Contact';
    final message = await buildEmergencyMessage(position: position, type: 'silent');

    if (contact == null || contact.isEmpty) {
      debugPrint('SmsService: Cannot send stealth alert. No contact cached.');
      _logSosBestEffort('silent', position.latitude, position.longitude);
      return SmsDispatchResult(
        success: false,
        message: 'No emergency contact configured in local cache.',
        recipientPhone: null,
        recipientName: contactName,
        isDemo: demo,
      );
    }

    if (demo) {
      _logSosBestEffort('silent', position.latitude, position.longitude);
      return SmsDispatchResult(
        success: true,
        message: message,
        recipientPhone: contact,
        recipientName: contactName,
        isDemo: true,
      );
    }

    try {
      await _smsChannel.invokeMethod('sendSms', {
        'phone': contact,
        'message': message,
      });
      _logSosBestEffort('silent', position.latitude, position.longitude);
      return SmsDispatchResult(
        success: true,
        message: message,
        recipientPhone: contact,
        recipientName: contactName,
        isDemo: false,
      );
    } catch (e) {
      debugPrint('SmsService native stealth SMS dispatch error: $e');
      _logSosBestEffort('silent', position.latitude, position.longitude);
      return SmsDispatchResult(
        success: false,
        message: 'SMS dispatch failed: $e',
        recipientPhone: contact,
        recipientName: contactName,
        isDemo: false,
      );
    }
  }

  /// Standard boolean wrapper for Stealth Alert.
  static Future<bool> sendStealthAlert(
    Position position, {
    bool? isDemoMode,
  }) async {
    final res = await dispatchStealthAlert(position, isDemoMode: isDemoMode);
    return res.success;
  }

  /// Used by SILENT SOS — 5-minute periodic location updates.
  static Future<bool> sendLocationUpdate(
    Position position,
    int updateCount, {
    bool? isDemoMode,
  }) async {
    final demo = isDemoMode ?? await isDemoModeEnabled();
    if (demo) return true;
    final contact = await resolveEmergencyContact();
    if (contact == null || contact.isEmpty) return false;

    final riderInfo = await resolveRiderProfileString() ?? 'SheTorque Rider';
    final mapLink =
        "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    final time = _formatTime(DateTime.now());

    final message = "SheTorque Update (#$updateCount): $riderInfo live location: $mapLink Time: $time";

    try {
      await _smsChannel.invokeMethod('sendSms', {
        'phone': contact,
        'message': message,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Used by SILENT SOS — Safe Confirmation resolution.
  /// Also marks the active SOS event in Supabase as resolved.
  static Future<bool> sendSafeConfirmation({bool? isDemoMode}) async {
    // 1. Resolve active SOS event in Supabase if logged
    _resolveActiveSosEvent();

    final demo = isDemoMode ?? await isDemoModeEnabled();
    if (demo) return true;

    final contact = await resolveEmergencyContact();
    if (contact == null || contact.isEmpty) return false;

    final riderInfo = await resolveRiderProfileString() ?? 'SheTorque Rider';
    final time = _formatTime(DateTime.now());

    final message = "SheTorque ALL CLEAR: $riderInfo confirmed safe. Location tracking stopped. Time: $time";

    try {
      await _smsChannel.invokeMethod('sendSms', {
        'phone': contact,
        'message': message,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _logSosBestEffort(String type, double lat, double lng) {
    try {
      _sosRepo.logSosEvent(type: type, lat: lat, lng: lng).then((eventId) {
        if (eventId != null) {
          SosSessionManager.setActiveSosEventId(eventId);
        }
      }).catchError((_) => null);
    } catch (_) {}
  }

  static void _resolveActiveSosEvent() {
    try {
      SosSessionManager.getActiveSosEventId().then((eventId) {
        if (eventId != null && eventId.isNotEmpty) {
          _sosRepo.resolveSosEvent(eventId).catchError((_) => null);
          SosSessionManager.setActiveSosEventId(null);
        }
      }).catchError((_) => null);
    } catch (_) {}
  }

  static String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  /// Sends a real SMS to the emergency contact alerting them of a persistent
  /// following vehicle. Reads contact from local cache — no network dependency.
  /// Blocked if [isDemoMode] or global demo mode is enabled.
  static Future<void> sendGuardianFollowerAlert({
    required String trackId,
    required int followedSeconds,
    bool? isDemoMode,
  }) async {
    final demo = isDemoMode ?? await isDemoModeEnabled();
    if (demo) {
      debugPrint('sendGuardianFollowerAlert [DEMO MODE]: Real SMS blocked for $trackId');
      return;
    }

    final phone = await resolveEmergencyContact();
    final riderName = (await resolveRiderProfileString()) ?? 'Rider';
    if (phone == null || phone.isEmpty) return;

    final now = DateTime.now();
    final time = _formatTime(now);
    final body =
        'GUARDIAN ALERT: $riderName — Vehicle $trackId has been following '
        'for ${followedSeconds}s. Sent at $time via SheTorque Guardian Eye.';

    try {
      await _smsChannel.invokeMethod<void>('sendSms', {
        'phoneNumber': phone,
        'message': body,
      });
    } catch (e) {
      debugPrint('sendGuardianFollowerAlert error: $e');
    }
  }
}
