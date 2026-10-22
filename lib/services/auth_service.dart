import '../models/rider_profile.dart';
import '../models/bike_info.dart';

/// Result of an authentication operation.
class AuthResult {
  final bool success;
  final String message;
  final String? userId;

  AuthResult(this.success, this.message, {this.userId});
}

/// Abstract contract for authentication and user profile operations.
abstract class AuthService {
  Future<AuthResult> signUp(String email, String password, {String? fullName});
  Future<AuthResult> login(String email, String password);
  Future<void> logout();
  Future<bool> isLoggedIn();
  Future<String?> currentUser();
  Future<String?> currentUserId();
  Future<RiderProfile> getRiderProfile();
  Future<void> saveRiderProfile(RiderProfile profile);
  Future<BikeInfo> getVehicleProfile();
  Future<void> saveVehicleProfile(BikeInfo profile);
  Future<void> saveSafetyPin(String pin);
  Future<bool> verifySafetyPin(String enteredPin);
  Future<String?> getCachedEmergencyContact();
}
