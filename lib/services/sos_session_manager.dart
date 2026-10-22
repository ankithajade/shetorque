import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central manager for the stealth SOS session lifecycle.
///
/// Exposes a [sessionActiveNotifier] so any widget tree can immediately react
/// to session start/end without polling SharedPreferences.
class SosSessionManager {
  static const String kStealthSosActive = 'stealth_sos_active';
  static const String kStealthSosStartTime = 'stealth_sos_start_time';
  static const String kRiderName = 'rider_name';
  static const String kSafetyPin = 'safety_pin';
  static const String kOnboardingComplete = 'onboarding_complete';
  static const String kActiveSosEventId = 'active_sos_event_id';

  /// Live single source of truth for shield visibility.
  ///
  /// Updated synchronously by [startSession] and [endSession] so widgets that
  /// listen to this notifier see the state change immediately — no need for
  /// the consumer to re-call [isSessionActive] asynchronously.
  static final ValueNotifier<bool> sessionActiveNotifier =
      ValueNotifier<bool>(false);

  // ---------------------------------------------------------------------------
  // Rider / PIN cache
  // ---------------------------------------------------------------------------

  static Future<void> setRiderName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kRiderName, name);
  }

  static Future<String?> getRiderName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kRiderName);
  }

  static Future<void> setSafetyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSafetyPin, pin);
  }

  static Future<String?> getSafetyPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kSafetyPin);
  }

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingComplete, true);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kOnboardingComplete) ?? false;
  }

  // ---------------------------------------------------------------------------
  // Active SOS event ID (Supabase row reference for cloud resolve)
  // ---------------------------------------------------------------------------

  static Future<void> setActiveSosEventId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(kActiveSosEventId);
    } else {
      await prefs.setString(kActiveSosEventId, id);
    }
  }

  static Future<String?> getActiveSosEventId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kActiveSosEventId);
  }

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  static Future<void> startSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStealthSosActive, true);
    await prefs.setString(kStealthSosStartTime, DateTime.now().toIso8601String());
    // Synchronous notification — widgets hear this immediately.
    sessionActiveNotifier.value = true;
  }

  static Future<void> endSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStealthSosActive, false);
    await prefs.remove(kStealthSosStartTime);
    await prefs.remove(kActiveSosEventId);
    // Synchronous notification.
    sessionActiveNotifier.value = false;
  }

  static Future<bool> isSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kStealthSosActive) ?? false;
  }

  /// Call once at app startup to hydrate [sessionActiveNotifier] from persisted
  /// SharedPreferences state (handles killed-and-relaunched app case).
  static Future<void> hydrateNotifier() async {
    final active = await isSessionActive();
    sessionActiveNotifier.value = active;
  }
}
