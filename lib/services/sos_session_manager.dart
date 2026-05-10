import 'package:shared_preferences/shared_preferences.dart';

class SosSessionManager {
  static const String kStealthSosActive = 'stealth_sos_active';
  static const String kStealthSosStartTime = 'stealth_sos_start_time';
  static const String kRiderName = 'rider_name';
  static const String kSafetyPin = 'safety_pin';
  static const String kOnboardingComplete = 'onboarding_complete';

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

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingComplete, true);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kOnboardingComplete) ?? false;
  }

  static Future<void> startSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStealthSosActive, true);
    await prefs.setString(kStealthSosStartTime, DateTime.now().toIso8601String());
  }

  static Future<void> endSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStealthSosActive, false);
    await prefs.remove(kStealthSosStartTime);
  }

  static Future<bool> isSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kStealthSosActive) ?? false;
  }
}
