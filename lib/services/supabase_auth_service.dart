import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rider_profile.dart';
import '../models/bike_info.dart';
import 'auth_service.dart';

/// Concrete implementation of [AuthService] using Supabase Auth & Database.
///
/// Implements offline-safe caching using [SharedPreferences] for emergency
/// contacts and PIN hashes to guarantee zero-latency, network-independent SOS.
class SupabaseAuthService implements AuthService {
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  static SupabaseAuthService get instance => _instance;
  SupabaseAuthService._internal();

  // Offline cache keys
  static const String kCachedEmergencyContact = 'sh_cached_emergency_contact';
  static const String kCachedEmergencyName = 'sh_cached_emergency_name';
  static const String kCachedSafetyPinHash = 'sh_cached_safety_pin_hash';
  static const String kCachedRiderProfile = 'sh_cached_rider_profile';
  static const String kCachedBikeInfo = 'sh_cached_bike_info';

  // Demo user credentials
  static const String demoEmail = 'ananya.rider@shetorque.io';
  static const String demoPassword = 'password123';

  // Salt for safety PIN hashing
  static const String _pinSalt = 'shetorque_pin_salt_2026_';

  SupabaseClient? _clientOverride;

  @visibleForTesting
  set clientOverride(SupabaseClient? client) => _clientOverride = client;

  SupabaseClient get _client {
    if (_clientOverride != null) return _clientOverride!;
    return Supabase.instance.client;
  }

  /// Hashes a 4-digit safety PIN using a salted SHA-256 algorithm.
  static String hashSafetyPin(String pin) {
    final bytes = utf8.encode('$_pinSalt$pin');
    return sha256.convert(bytes).toString();
  }

  @override
  Future<AuthResult> signUp(
    String email,
    String password, {
    String? fullName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult(false, 'Please enter a valid email address.');
    }
    if (password.length < 6) {
      return AuthResult(false, 'Password must be at least 6 characters.');
    }

    try {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: fullName != null && fullName.isNotEmpty
            ? {'full_name': fullName}
            : null,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult(false, 'Signup failed. Please try again.');
      }

      return AuthResult(true, 'Account created successfully.', userId: user.id);
    } catch (e) {
      return AuthResult(false, _friendlyErrorMessage(e));
    }
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult(false, 'Please enter a valid email address.');
    }
    if (password.isEmpty) {
      return AuthResult(false, 'Please enter your password.');
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult(false, 'Authentication failed. Please try again.');
      }

      // Synchronize and cache profile and vehicle in the background for offline readiness
      await _syncAndCacheUserData(user.id, cleanEmail);

      return AuthResult(true, 'Logged in successfully.', userId: user.id);
    } catch (e) {
      return AuthResult(false, _friendlyErrorMessage(e));
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final session = _client.auth.currentSession;
      return session != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> currentUser() async {
    try {
      return _client.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> currentUserId() async {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RiderProfile> getRiderProfile() async {
    final uid = await currentUserId();
    final prefs = await SharedPreferences.getInstance();

    if (uid != null) {
      try {
        final data = await _client
            .from('profiles')
            .select()
            .eq('id', uid)
            .maybeSingle();

        if (data != null) {
          final profile = RiderProfile(
            name: (data['full_name'] as String?)?.trim().isNotEmpty == true
                ? data['full_name'] as String
                : 'Ananya Sharma',
            email: _client.auth.currentUser?.email ?? 'ananya.rider@shetorque.io',
            phone: data['phone'] as String? ?? '+91 98765 43210',
            emergencyContactName:
                data['emergency_contact_name'] as String? ?? '',
            emergencyContactPhone:
                data['emergency_contact_phone'] as String? ?? '',
            bloodGroup: 'O+',
            address: 'Bengaluru, KA',
          );

          // Update offline caches
          await _cacheProfileLocally(prefs, profile, data['safety_pin_hash'] as String?);
          return profile;
        }
      } catch (e) {
        debugPrint('Supabase getRiderProfile error, falling back to cache: $e');
      }
    }

    // Fallback to local offline cache
    final cachedJson = prefs.getString(kCachedRiderProfile);
    if (cachedJson != null) {
      try {
        return RiderProfile.fromJson(
            jsonDecode(cachedJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    return RiderProfile();
  }

  @override
  Future<void> saveRiderProfile(RiderProfile profile) async {
    final uid = await currentUserId();
    final prefs = await SharedPreferences.getInstance();

    // 1. Immediately cache locally for offline safety
    await _cacheProfileLocally(prefs, profile, null);

    // 2. Persist to Supabase if logged in
    if (uid != null) {
      try {
        await _client.from('profiles').upsert({
          'id': uid,
          'full_name': profile.name,
          'phone': profile.phone,
          'emergency_contact_name': profile.emergencyContactName,
          'emergency_contact_phone': profile.emergencyContactPhone,
        });
      } catch (e) {
        debugPrint('Supabase saveRiderProfile error: $e');
        rethrow;
      }
    }
  }

  @override
  Future<BikeInfo> getVehicleProfile() async {
    final uid = await currentUserId();
    final prefs = await SharedPreferences.getInstance();

    if (uid != null) {
      try {
        final data = await _client
            .from('bikes')
            .select()
            .eq('user_id', uid)
            .maybeSingle();

        if (data != null) {
          final odoNum = data['odometer_km'];
          final bike = BikeInfo(
            brand: data['make'] as String? ?? 'Royal Enfield',
            model: data['model'] as String? ?? 'Hunter 350 Dapper',
            regNumber: data['reg_number'] as String? ?? 'KA 05 EQ 8824',
            year: '2024',
            fuelType: 'Petrol (E20)',
            odometer: odoNum != null ? '$odoNum km' : '4,820 km',
            nextService: 'In 180 km',
          );

          await prefs.setString(kCachedBikeInfo, jsonEncode(bike.toJson()));
          return bike;
        }
      } catch (e) {
        debugPrint('Supabase getVehicleProfile error: $e');
      }
    }

    final cachedJson = prefs.getString(kCachedBikeInfo);
    if (cachedJson != null) {
      try {
        return BikeInfo.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    return BikeInfo();
  }

  @override
  Future<void> saveVehicleProfile(BikeInfo profile) async {
    final uid = await currentUserId();
    final prefs = await SharedPreferences.getInstance();

    // Cache locally
    await prefs.setString(kCachedBikeInfo, jsonEncode(profile.toJson()));

    if (uid != null) {
      final odoParsed = _parseOdometer(profile.odometer);
      try {
        final existing = await _client
            .from('bikes')
            .select('id')
            .eq('user_id', uid)
            .maybeSingle();

        if (existing != null) {
          await _client.from('bikes').update({
            'make': profile.brand,
            'model': profile.model,
            'reg_number': profile.regNumber,
            'odometer_km': odoParsed,
          }).eq('user_id', uid);
        } else {
          await _client.from('bikes').insert({
            'user_id': uid,
            'make': profile.brand,
            'model': profile.model,
            'reg_number': profile.regNumber,
            'fuel_capacity_l': 13.0,
            'avg_mileage_kmpl': 35.0,
            'odometer_km': odoParsed,
            'last_service_km': 4500,
          });
        }
      } catch (e) {
        debugPrint('Supabase saveVehicleProfile error: $e');
        rethrow;
      }
    }
  }

  @override
  Future<void> saveSafetyPin(String pin) async {
    final uid = await currentUserId();
    final hash = hashSafetyPin(pin.trim());
    final prefs = await SharedPreferences.getInstance();

    // Cache PIN hash locally
    await prefs.setString(kCachedSafetyPinHash, hash);

    if (uid != null) {
      try {
        await _client
            .from('profiles')
            .update({'safety_pin_hash': hash})
            .eq('id', uid);
      } catch (e) {
        debugPrint('Supabase saveSafetyPin error: $e');
        rethrow;
      }
    }
  }

  @override
  Future<bool> verifySafetyPin(String enteredPin) async {
    final enteredHash = hashSafetyPin(enteredPin.trim());
    final prefs = await SharedPreferences.getInstance();
    String? storedHash = prefs.getString(kCachedSafetyPinHash);

    if (storedHash == null) {
      final uid = await currentUserId();
      if (uid != null) {
        try {
          final row = await _client
              .from('profiles')
              .select('safety_pin_hash')
              .eq('id', uid)
              .maybeSingle();
          storedHash = row?['safety_pin_hash'] as String?;
          if (storedHash != null) {
            await prefs.setString(kCachedSafetyPinHash, storedHash);
          }
        } catch (_) {}
      }
    }

    if (storedHash == null || storedHash.isEmpty) {
      // Default: allow 4-digit entry if PIN not initialized yet
      return enteredPin.trim().length == 4;
    }

    return enteredHash == storedHash;
  }

  @override
  Future<String?> getCachedEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    final contact = prefs.getString(kCachedEmergencyContact)?.trim();
    if (contact != null && contact.isNotEmpty) return contact;
    return null;
  }

  Future<void> _cacheProfileLocally(
    SharedPreferences prefs,
    RiderProfile profile,
    String? pinHash,
  ) async {
    if (profile.emergencyContactPhone.trim().isNotEmpty) {
      await prefs.setString(
          kCachedEmergencyContact, profile.emergencyContactPhone.trim());
    }
    if (profile.emergencyContactName.trim().isNotEmpty) {
      await prefs.setString(
          kCachedEmergencyName, profile.emergencyContactName.trim());
    }
    if (pinHash != null && pinHash.isNotEmpty) {
      await prefs.setString(kCachedSafetyPinHash, pinHash);
    }
    await prefs.setString(kCachedRiderProfile, jsonEncode(profile.toJson()));
  }

  Future<void> _syncAndCacheUserData(String uid, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileData = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (profileData != null) {
        final profile = RiderProfile(
          name: profileData['full_name'] as String? ?? 'Ananya Sharma',
          email: email,
          phone: profileData['phone'] as String? ?? '+91 98765 43210',
          emergencyContactName:
              profileData['emergency_contact_name'] as String? ?? '',
          emergencyContactPhone:
              profileData['emergency_contact_phone'] as String? ?? '',
          bloodGroup: 'O+',
          address: 'Bengaluru, KA',
        );
        await _cacheProfileLocally(
          prefs,
          profile,
          profileData['safety_pin_hash'] as String?,
        );
      }

      final bikeData = await _client
          .from('bikes')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (bikeData != null) {
        final odoNum = bikeData['odometer_km'];
        final bike = BikeInfo(
          brand: bikeData['make'] as String? ?? 'Royal Enfield',
          model: bikeData['model'] as String? ?? 'Hunter 350 Dapper',
          regNumber: bikeData['reg_number'] as String? ?? 'KA 05 EQ 8824',
          odometer: odoNum != null ? '$odoNum km' : '4,820 km',
        );
        await prefs.setString(kCachedBikeInfo, jsonEncode(bike.toJson()));
      }
    } catch (e) {
      debugPrint('Error syncing user data on login: $e');
    }
  }

  int _parseOdometer(String odoStr) {
    final digits = odoStr.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 4820;
  }

  String _friendlyErrorMessage(dynamic error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials')) {
        return 'Incorrect email or password.';
      }
      if (msg.contains('already registered') ||
          msg.contains('user already registered')) {
        return 'An account with this email is already registered. Please log in.';
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return 'No network connection. Please check your internet and try again.';
      }
      if (msg.contains('password') && msg.contains('least')) {
        return 'Password must be at least 6 characters.';
      }
      return error.message;
    }

    if (error is SocketException ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('ClientException')) {
      return 'No network connection. Please check your internet and try again.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
