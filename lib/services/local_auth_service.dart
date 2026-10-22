import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rider_profile.dart';
import '../models/bike_info.dart';

/// Result of an authentication operation.
class AuthResult {
  final bool success;
  final String message;
  AuthResult(this.success, this.message);
}

/// Handles local signup, login, and profile persistence using SharedPreferences.
///
/// Implements standard credential verification (SHA-256 hash check) with no
/// bypass. A pre-seeded demo user (`ananya.rider@shetorque.io`) is available
/// for testing and goes through the identical verification flow.
class LocalAuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();
  factory LocalAuthService() => _instance;
  LocalAuthService._internal();

  static const _kUsersKey = 'sh_users'; // email -> sha256(password)
  static const _kCurrentUserKey = 'sh_current_user';
  static const _kVehiclePrefix = 'sh_vehicle_'; // + email
  static const _kRiderPrefix = 'sh_rider_'; // + email
  static const _kPreseededKey = 'sh_demo_preseeded';

  // Demo user credentials for testing
  static const String demoEmail = 'ananya.rider@shetorque.io';
  static const String demoPassword = 'password123';

  String _hash(String password) {
    final bytes = utf8.encode('shetorque_$password');
    return sha256.convert(bytes).toString();
  }

  /// Ensures a demo rider account is seeded in SharedPreferences so normal
  /// credential validation succeeds for the demo account out-of-the-box.
  Future<void> ensureDemoAccountSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool(_kPreseededKey) ?? false;
    if (!seeded) {
      final users = await _loadUsers();
      if (!users.containsKey(demoEmail)) {
        users[demoEmail] = _hash(demoPassword);
        await _saveUsers(users);

        // Pre-seed default profile and vehicle for the demo account
        final demoProfile = RiderProfile();
        final demoBike = BikeInfo();
        await prefs.setString(
            '$_kRiderPrefix$demoEmail', jsonEncode(demoProfile.toJson()));
        await prefs.setString(
            '$_kVehiclePrefix$demoEmail', jsonEncode(demoBike.toJson()));
      }
      await prefs.setBool(_kPreseededKey, true);
    }
  }

  Future<Map<String, String>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveUsers(Map<String, String> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsersKey, jsonEncode(users));
  }

  Future<AuthResult> signUp(String email, String password) async {
    await ensureDemoAccountSeeded();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult(false, 'Please enter a valid email address.');
    }
    if (password.length < 6) {
      return AuthResult(false, 'Password must be at least 6 characters.');
    }
    final users = await _loadUsers();
    if (users.containsKey(cleanEmail)) {
      return AuthResult(false, 'An account with this email already exists.');
    }
    users[cleanEmail] = _hash(password);
    await _saveUsers(users);
    await _setCurrentUser(cleanEmail);
    return AuthResult(true, 'Account created successfully.');
  }

  Future<AuthResult> login(String email, String password) async {
    await ensureDemoAccountSeeded();
    final cleanEmail = email.trim().toLowerCase();
    final users = await _loadUsers();
    final storedHash = users[cleanEmail];
    if (storedHash == null || storedHash != _hash(password)) {
      return AuthResult(false, 'Invalid email or password.');
    }
    await _setCurrentUser(cleanEmail);
    return AuthResult(true, 'Logged in successfully.');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentUserKey);
  }

  Future<void> _setCurrentUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUserKey, email);
  }

  Future<String?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrentUserKey);
  }

  Future<bool> isLoggedIn() async {
    await ensureDemoAccountSeeded();
    final user = await currentUser();
    return user != null && user.isNotEmpty;
  }

  // --- Vehicle profile ---

  Future<void> saveVehicleProfile(BikeInfo profile) async {
    final email = await currentUser();
    if (email == null) throw StateError('No user logged in');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_kVehiclePrefix$email', jsonEncode(profile.toJson()));
  }

  Future<BikeInfo> getVehicleProfile() async {
    final email = await currentUser();
    if (email != null) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kVehiclePrefix$email');
      if (raw != null) {
        try {
          return BikeInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
    }
    return BikeInfo();
  }

  // --- Rider profile ---

  Future<void> saveRiderProfile(RiderProfile profile) async {
    final email = await currentUser();
    if (email == null) throw StateError('No user logged in');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_kRiderPrefix$email', jsonEncode(profile.toJson()));
  }

  Future<RiderProfile> getRiderProfile() async {
    final email = await currentUser();
    if (email != null) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kRiderPrefix$email');
      if (raw != null) {
        try {
          return RiderProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
    }
    return RiderProfile();
  }
}
