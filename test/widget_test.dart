import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shetorque_hub/theme/she_torque_theme.dart';
import 'package:shetorque_hub/models/rider_profile.dart';
import 'package:shetorque_hub/models/bike_info.dart';
import 'package:shetorque_hub/models/ecu_data.dart';
import 'package:shetorque_hub/models/vehicle_health.dart';
import 'package:shetorque_hub/models/safe_route_model.dart';
import 'package:shetorque_hub/services/auth_service.dart';
import 'package:shetorque_hub/services/supabase_auth_service.dart';
import 'package:shetorque_hub/models/ride_model.dart';
import 'package:shetorque_hub/models/sos_event_model.dart';
import 'package:shetorque_hub/models/guardian_alert_model.dart';
import 'package:shetorque_hub/models/pink_spot_model.dart';
import 'package:shetorque_hub/services/sms_service.dart';
import 'package:shetorque_hub/services/vehicle_telemetry_service.dart';
import 'package:shetorque_hub/services/mock_ecu_service.dart';
import 'package:shetorque_hub/services/diagnostic_engine.dart';
import 'package:shetorque_hub/services/crime_data_service.dart';
import 'package:shetorque_hub/services/safe_routing_service.dart';
import 'package:shetorque_hub/screens/dashboard/tabs/garage_tab.dart';
import 'package:shetorque_hub/screens/dashboard/tabs/diagnostics_tab.dart';
import 'package:shetorque_hub/config/app_config.dart';
import 'package:shetorque_hub/screens/config_error_screen.dart';
import 'package:shetorque_hub/main.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Theme & Models Tests', () {
    test('SheTorqueTheme exposes expected brand colors', () {
      expect(SheTorqueTheme.primaryCyan, const Color(0xFF00E5FF));
      expect(SheTorqueTheme.secondaryPink, const Color(0xFFFF2A6D));
      expect(SheTorqueTheme.background, const Color(0xFF0D1117));
    });

    test('RiderProfile serializes and deserializes correctly', () {
      final profile = RiderProfile(
        name: 'Sneha Rao',
        email: 'sneha@example.com',
        phone: '+91 99999 88888',
        emergencyContactName: 'Rahul',
        emergencyContactPhone: '+91 77777 66666',
        bloodGroup: 'B+',
        address: 'MG Road, Bengaluru',
      );

      final json = profile.toJson();
      final reconstructed = RiderProfile.fromJson(json);

      expect(reconstructed.name, 'Sneha Rao');
      expect(reconstructed.email, 'sneha@example.com');
      expect(reconstructed.bloodGroup, 'B+');
    });

    test('BikeInfo serializes and deserializes correctly', () {
      final bike = BikeInfo(
        brand: 'KTM',
        model: 'Duke 390',
        regNumber: 'KA 01 AB 1234',
        year: '2025',
        fuelType: 'Petrol (E20)',
        odometer: '1,200 km',
      );

      final json = bike.toJson();
      final reconstructed = BikeInfo.fromJson(json);

      expect(reconstructed.brand, 'KTM');
      expect(reconstructed.model, 'Duke 390');
      expect(reconstructed.regNumber, 'KA 01 AB 1234');
    });
  });

  group('Vehicle Telemetry & Mock ECU Tests', () {
    test('MockEcuService conforms to VehicleTelemetryService abstraction', () {
      final VehicleTelemetryService service = MockEcuService.instance;
      expect(service, isNotNull);
      expect(service.telemetryStream, isA<Stream<EcuData>>());
      expect(service.currentData, isA<EcuData>());
    });

    test('MockEcuService lifecycle and emission verification', () async {
      final testService = MockEcuService.custom(
        tickInterval: const Duration(milliseconds: 50),
        initialFuel: 80.0,
        initialTemp: 40.0,
        initialVoltage: 12.6,
      );

      expect(testService.isStreaming, isFalse);

      final emitted = <EcuData>[];
      final sub = testService.telemetryStream.listen(emitted.add);

      testService.start();
      expect(testService.isStreaming, isTrue);

      // Wait for tick emissions
      await Future.delayed(const Duration(milliseconds: 180));

      expect(emitted.isNotEmpty, isTrue);
      expect(testService.ticks, greaterThanOrEqualTo(1));
      expect(emitted.first.batteryVoltage, closeTo(12.6, 1.0));

      testService.stop();
      expect(testService.isStreaming, isFalse);
      await sub.cancel();
    });

    test('MockEcuService reset restores baseline parameters', () {
      final service = MockEcuService.instance;
      service.forceOverheat = true;
      service.forceLowBattery = true;
      service.reset(fuel: 75.0, temp: 35.0, voltage: 12.8);

      expect(service.forceOverheat, isFalse);
      expect(service.forceLowBattery, isFalse);
      expect(service.current.fuelLevelPercent, 75.0);
      expect(service.current.engineTempCelsius, 35.0);
      expect(service.current.batteryVoltage, 12.8);
    });
  });

  group('Diagnostic Engine & Vehicle Health Calculation Tests', () {
    const engine = DiagnosticEngine();

    test('Nominal telemetry yields 100 score and Optimal status', () {
      final nominalEcu = EcuData(
        fuelLevelPercent: 85.0,
        engineTempCelsius: 88.0,
        batteryVoltage: 12.8,
        rpm: 4200,
        speedKmH: 52.0,
        warnings: const [],
        dtcCodes: const [],
        timestamp: DateTime.now(),
      );

      final health = engine.evaluate(nominalEcu);
      expect(health.overallScore, 100);
      expect(health.status, VehicleHealthStatus.optimal);
      expect(health.criticalIssues, isEmpty);
      expect(health.recommendations, isEmpty);
    });

    test('Engine overheat deducts 35 points, generates DTC and explainable recommendation', () {
      final overheatEcu = EcuData(
        fuelLevelPercent: 60.0,
        engineTempCelsius: 118.5, // >= 115.0 overheat threshold
        batteryVoltage: 12.6,
        rpm: 3800,
        speedKmH: 45.0,
        warnings: EcuThresholds.evaluate(60.0, 118.5, 12.6),
        dtcCodes: EcuThresholds.evaluateDtc(60.0, 118.5, 12.6),
        timestamp: DateTime.now(),
      );

      final health = engine.evaluate(overheatEcu);
      expect(health.overallScore, 65);
      expect(health.status, VehicleHealthStatus.critical);
      expect(health.criticalIssues.length, 2);
      expect(health.criticalIssues.first, contains('Engine Overheat'));
      expect(overheatEcu.dtcCodes.any((c) => c.contains('P0217')), isTrue);
      expect(health.recommendations.first.action, contains('Safely pull over'));
    });

    test('Low battery deducts 15 points and flags warning', () {
      final lowBatteryEcu = EcuData(
        fuelLevelPercent: 50.0,
        engineTempCelsius: 85.0,
        batteryVoltage: 11.4, // <= 11.8 low battery threshold (-15 pts)
        rpm: 3000,
        speedKmH: 40.0,
        warnings: EcuThresholds.evaluate(50.0, 85.0, 11.4),
        dtcCodes: EcuThresholds.evaluateDtc(50.0, 85.0, 11.4),
        timestamp: DateTime.now(),
      );

      final health = engine.evaluate(lowBatteryEcu);
      expect(health.overallScore, 85);
      expect(health.status, VehicleHealthStatus.warning);
      expect(lowBatteryEcu.warnings, contains('Battery voltage low'));
    });

    test('Critical combination (overheat + low battery + reserve fuel) drops score below 40', () {
      final criticalEcu = EcuData(
        fuelLevelPercent: 5.0,
        engineTempCelsius: 120.0,
        batteryVoltage: 11.2,
        rpm: 2500,
        speedKmH: 20.0,
        warnings: EcuThresholds.evaluate(5.0, 120.0, 11.2),
        dtcCodes: EcuThresholds.evaluateDtc(5.0, 120.0, 11.2),
        timestamp: DateTime.now(),
      );

      final health = engine.evaluate(criticalEcu);
      expect(health.overallScore, lessThanOrEqualTo(40));
      expect(health.status, VehicleHealthStatus.critical);
      expect(health.criticalIssues.length, greaterThanOrEqualTo(2));
    });
  });

  group('Garage and Diagnostics Tab Widget Tests', () {
    final mockRider = RiderProfile(
      name: 'Ananya Sharma',
      email: 'ananya@shetorque.io',
      phone: '+91 98765 43210',
      emergencyContactName: 'Pooja',
      emergencyContactPhone: '+91 91234 56789',
      bloodGroup: 'O+',
      address: 'Indiranagar, Bengaluru',
    );

    final mockBike = BikeInfo(
      brand: 'Royal Enfield',
      model: 'Hunter 350',
      regNumber: 'KA 03 ST 2026',
      year: '2024',
      fuelType: 'Petrol',
      odometer: '3,450 km',
    );

    final liveEcu = EcuData(
      fuelLevelPercent: 68.5,
      engineTempCelsius: 91.2,
      batteryVoltage: 12.75,
      rpm: 4350,
      speedKmH: 54.0,
      warnings: const [],
      dtcCodes: const [],
      timestamp: DateTime.now(),
    );

    final health = VehicleHealth(
      overallScore: 100,
      status: VehicleHealthStatus.optimal,
      activeWarnings: const [],
      criticalIssues: const [],
      recommendations: const [],
      timestamp: DateTime.now(),
    );

    testWidgets('GarageTab renders live Mock ECU telemetry metrics', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: SheTorqueTheme.darkTheme,
          home: Scaffold(
            body: GarageTab(
              rider: mockRider,
              bike: mockBike,
              ecuData: liveEcu,
              vehicleHealth: health,
              onSosPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Hello, Ananya 👋'), findsOneWidget);
      expect(find.text('68.5%'), findsOneWidget);
      expect(find.text('91.2°C'), findsOneWidget);
      expect(find.text('12.75V'), findsOneWidget);
      expect(find.text('4350'), findsOneWidget);
      expect(find.text('OBD-II STREAMING'), findsOneWidget);
    });

    testWidgets('DiagnosticsTab displays live parameter breakdown and 100% health', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SheTorqueTheme.darkTheme,
          home: Scaffold(
            body: DiagnosticsTab(
              rider: mockRider,
              ecuData: liveEcu,
              vehicleHealth: health,
            ),
          ),
        ),
      );

      expect(find.text('OBD-II Diagnostics'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Optimal Condition'), findsOneWidget);
      expect(find.text('4350 RPM'), findsOneWidget);
      expect(find.text('54.0 km/h'), findsOneWidget);
      expect(find.text('None (0 DTCs detected)'), findsOneWidget);
    });
  });

  group('Phase 3A: Safe Routing Intelligence Refinements Tests', () {
    test('SafetyScoreBreakdown computes strictly positive weighted score reaching 100.0', () {
      // Perfect conditions
      const breakdownMax = SafetyScoreBreakdown(
        pinkSpotScore: 100.0,
        mainRoadScore: 100.0,
        lightingScore: 100.0,
        regionalSafetyIndex: 100.0,
      );

      expect(breakdownMax.pinkSpotContribution, closeTo(30.0, 0.01));
      expect(breakdownMax.mainRoadContribution, closeTo(30.0, 0.01));
      expect(breakdownMax.lightingContribution, closeTo(15.0, 0.01));
      expect(breakdownMax.regionalContribution, closeTo(25.0, 0.01));
      expect(breakdownMax.totalScore, closeTo(100.0, 0.01));

      // Weights sum strictly to 1.00
      expect(
        SafetyScoreBreakdown.pinkSpotWeight +
            SafetyScoreBreakdown.mainRoadWeight +
            SafetyScoreBreakdown.lightingWeight +
            SafetyScoreBreakdown.regionalSafetyWeight,
        closeTo(1.0, 0.001),
      );
    });

    test('LightingScore is computed as 100 - UnlitPercentage', () {
      const double unlitPercentage = 15.0;
      final double lightingScore = (100.0 - unlitPercentage).clamp(0.0, 100.0);
      expect(lightingScore, 85.0);

      const breakdown = SafetyScoreBreakdown(
        pinkSpotScore: 80.0,
        mainRoadScore: 70.0,
        lightingScore: 85.0,
        regionalSafetyIndex: 52.0, // Bengaluru City baseline
      );

      // (80 * 0.3) + (70 * 0.3) + (85 * 0.15) + (52 * 0.25) = 24.0 + 21.0 + 12.75 + 13.0 = 70.75 -> 70.8
      expect(breakdown.totalScore, closeTo(70.8, 0.1));
    });

    test('SafeHaven retains underlying type and exposes rider-friendly Pink Spot labels', () {
      const policeHaven = SafeHaven(
        name: 'Cubbon Park Police Station',
        type: 'police',
        location: LatLng(12.975, 77.592),
        isVerified: false,
      );

      expect(policeHaven.type, 'police');
      expect(policeHaven.displayType, 'Police Station');
      expect(policeHaven.riderLabel, 'Pink Spot (Police Station)');
      expect(policeHaven.isVerified, isFalse);

      const verifiedHospital = SafeHaven(
        name: 'Bowring and Lady Curzon Hospital',
        type: 'hospital',
        location: LatLng(12.982, 77.604),
        isVerified: true,
      );

      expect(verifiedHospital.type, 'hospital');
      expect(verifiedHospital.displayType, 'Hospital');
      expect(verifiedHospital.isVerified, isTrue);
    });

    test('CrimeDataService loads Karnataka 2025 baseline with district-level granularity', () async {
      final service = CrimeDataService();
      await service.initialize();

      expect(service.isInitialized, isTrue);
      expect(CrimeDataService.datasetYear, '2025');
      expect(CrimeDataService.datasetSource, contains('Karnataka State Police'));
      expect(CrimeDataService.datasetGranularity, contains('District'));
      expect(CrimeDataService.datasetDisclaimer, contains('Historical Regional Crime Indicator'));

      // Bengaluru City lookup
      final blr = service.getIndicatorForLocation(const LatLng(12.9716, 77.5946));
      expect(blr.districtName, 'Bengaluru City');
      expect(blr.ipcCrimes, 37181);
      expect(blr.safetyIndex, 52.0);
      expect(blr.riskCategory, 'Moderate Urban Baseline');

      // Mysuru City lookup
      final mysuru = service.getIndicatorForLocation(const LatLng(12.305, 76.655));
      expect(mysuru.districtName, contains('Mysuru'));
      expect(mysuru.safetyIndex, greaterThanOrEqualTo(70.0));
    });

    test('selectSafestPracticalRoute recommends safest route using Pink Spots terminology', () {
      final routeA = SafeRouteModel(
        polylineCoordinates: const [LatLng(12.97, 77.59), LatLng(12.98, 77.60)],
        distance: '10 km',
        duration: '20 mins',
        distanceMeters: 10000,
        durationSeconds: 1200,
        safetyScore: 68.0,
        riskTags: const [],
        safeHavens: const [
          SafeHaven(name: 'Station 1', type: 'police', location: LatLng(12.972, 77.592))
        ],
      );

      final routeB = SafeRouteModel(
        polylineCoordinates: const [LatLng(12.97, 77.59), LatLng(12.98, 77.61)],
        distance: '11 km',
        duration: '22 mins',
        distanceMeters: 11000,
        durationSeconds: 1320,
        safetyScore: 84.0, // Substantially safer with minimal 2 min detour
        riskTags: const [],
        safeHavens: const [
          SafeHaven(name: 'Station 1', type: 'police', location: LatLng(12.972, 77.592)),
          SafeHaven(name: 'Hospital 1', type: 'hospital', location: LatLng(12.975, 77.595)),
          SafeHaven(name: 'Fire Stn 1', type: 'fire_station', location: LatLng(12.978, 77.599)),
        ],
      );

      final selected = SafeRoutingService.selectSafestPracticalRoute([routeA, routeB]);
      expect(selected.isNotEmpty, isTrue);
      final recommended = selected.firstWhere((r) => r.isRecommended);

      expect(recommended.safetyScore, 84.0);
      expect(recommended.recommendationReason, contains('Pink Spots'));
      expect(recommended.recommendationReason, contains('Recommended for superior safety'));
    });
  });

  group('Supabase Table Models Serialization Tests', () {
    test('RideModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final ride = RideModel(
        id: 'ride-123',
        userId: 'user-abc',
        title: 'Morning Ride to Nandi Hills',
        origin: 'Indiranagar',
        destination: 'Nandi Hills',
        distanceKm: 62.5,
        durationMin: 75,
        safetyScore: 92.0,
        startedAt: now,
      );

      final json = ride.toJson();
      expect(json['title'], 'Morning Ride to Nandi Hills');
      expect(json['distance_km'], 62.5);
      expect(json['safety_score'], 92.0);

      final reconstructed = RideModel.fromJson(json);
      expect(reconstructed.id, 'ride-123');
      expect(reconstructed.title, 'Morning Ride to Nandi Hills');
      expect(reconstructed.distanceKm, 62.5);
      expect(reconstructed.durationMin, 75);
      expect(reconstructed.safetyScore, 92.0);
    });

    test('SosEventModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final event = SosEventModel(
        id: 'sos-456',
        userId: 'user-abc',
        type: 'silent',
        lat: 12.9716,
        lng: 77.5946,
        resolved: false,
        createdAt: now,
      );

      final json = event.toJson();
      expect(json['type'], 'silent');
      expect(json['lat'], 12.9716);
      expect(json['resolved'], isFalse);

      final reconstructed = SosEventModel.fromJson(json);
      expect(reconstructed.id, 'sos-456');
      expect(reconstructed.type, 'silent');
      expect(reconstructed.resolved, isFalse);
    });

    test('GuardianAlertModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final alert = GuardianAlertModel(
        id: 'guard-789',
        userId: 'user-abc',
        vehicleId: 'KA03HA1234',
        followedSeconds: 45,
        mode: 'single',
        source: 'manual',
        createdAt: now,
      );

      final json = alert.toJson();
      expect(json['vehicle_id'], 'KA03HA1234');
      expect(json['followed_seconds'], 45);
      expect(json['mode'], 'single');

      final reconstructed = GuardianAlertModel.fromJson(json);
      expect(reconstructed.id, 'guard-789');
      expect(reconstructed.followedSeconds, 45);
      expect(reconstructed.mode, 'single');
    });

    test('PinkSpotModel serializes and deserializes correctly', () {
      final spot = PinkSpotModel(
        id: 'pink-101',
        userId: 'user-abc',
        name: 'All-Women 24/7 Fuel Station',
        category: 'fuel_station',
        lat: 12.975,
        lng: 77.605,
        notes: 'Well-lit, CCTV-monitored, women attendants',
      );

      final json = spot.toJson();
      expect(json['name'], 'All-Women 24/7 Fuel Station');
      expect(json['category'], 'fuel_station');

      final reconstructed = PinkSpotModel.fromJson(json);
      expect(reconstructed.id, 'pink-101');
      expect(reconstructed.name, 'All-Women 24/7 Fuel Station');
      expect(reconstructed.category, 'fuel_station');
      expect(reconstructed.displayCategory, 'Fuel Station');
    });
  });

  group('AuthService, Offline Emergency Contact & Salted PIN Tests', () {
    test('Salted SHA-256 PIN hashing behaves deterministically and never stores raw PIN', () {
      const pin = '4321';
      final hash1 = SupabaseAuthService.hashSafetyPin(pin);
      final hash2 = SupabaseAuthService.hashSafetyPin(pin);

      expect(hash1, isNotEmpty);
      expect(hash1.length, 64); // 256 bits = 64 hex characters
      expect(hash1, equals(hash2));
      expect(hash1, isNot(contains(pin))); // Never raw

      final differentHash = SupabaseAuthService.hashSafetyPin('9999');
      expect(hash1, isNot(equals(differentHash)));
    });

    test('FakeAuthService validates demo user credentials', () async {
      final auth = FakeAuthService();
      final valid = await auth.login(
        'ananya.rider@shetorque.io',
        'password123',
      );
      expect(valid.success, isTrue);

      final invalid = await auth.login(
        'ananya.rider@shetorque.io',
        'wrongpassword',
      );
      expect(invalid.success, isFalse);
    });

    test('Offline Emergency Contact resolves strictly from local cache without network', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(SupabaseAuthService.kCachedEmergencyContact);

      // 1. Unconfigured state returns null
      final emptyContact = await SmsService.resolveEmergencyContact();
      expect(emptyContact, isNull);

      // 2. Set cached contact (simulating profile sync or offline login)
      const testPhone = '+919876543210';
      await prefs.setString(SupabaseAuthService.kCachedEmergencyContact, testPhone);

      // 3. Instant local resolution without network
      final resolved = await SmsService.resolveEmergencyContact();
      expect(resolved, testPhone);
    });

    test('Safety PIN updates cache with salted hash and verifies entered PIN', () async {
      final auth = FakeAuthService();

      // Set new PIN
      await auth.saveSafetyPin('1357');

      // Check verification
      expect(await auth.verifySafetyPin('1357'), isTrue);
      expect(await auth.verifySafetyPin('0000'), isFalse);
      expect(await auth.verifySafetyPin('1234'), isFalse);
    });

    test('FakeAuthService conforms to all AuthService contract requirements', () async {
      final AuthService auth = FakeAuthService();

      expect(await auth.isLoggedIn(), isFalse);
      expect(await auth.currentUser(), isNull);
      expect(await auth.currentUserId(), isNull);

      final loginRes = await auth.login('ananya.rider@shetorque.io', 'password123');
      expect(loginRes.success, isTrue);
      expect(loginRes.userId, 'mock-user-123');
      expect(await auth.isLoggedIn(), isTrue);
      expect(await auth.currentUser(), 'ananya.rider@shetorque.io');

      // Update rider and emergency contact
      final rider = await auth.getRiderProfile();
      final updatedRider = rider.copyWith(emergencyContactPhone: '+91 91234 56789');
      await auth.saveRiderProfile(updatedRider);

      expect(await auth.getCachedEmergencyContact(), '+91 91234 56789');
      expect(await SmsService.resolveEmergencyContact(), '+91 91234 56789');

      // Logout clears session and cached contact
      await auth.logout();
      expect(await auth.isLoggedIn(), isFalse);
      expect(await auth.getCachedEmergencyContact(), isNull);
    });
  });

  group('App Configuration & Environment Smoke Tests', () {
    test('AppConfig handles configuration state correctly', () {
      if (!AppConfig.isConfigured) {
        expect(AppConfig.supabaseUrl, isEmpty);
        expect(AppConfig.supabaseAnonKey, isEmpty);
        expect(AppConfig.missingVariables, contains('SUPABASE_URL'));
        expect(AppConfig.missingVariables, contains('SUPABASE_ANON_KEY'));
      } else {
        expect(AppConfig.supabaseUrl, isNotEmpty);
        expect(AppConfig.supabaseAnonKey, isNotEmpty);
      }
    });

    testWidgets('SheTorqueApp builds cleanly in test environment',
        (WidgetTester tester) async {
      await tester.pumpWidget(const SheTorqueApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      if (!AppConfig.isConfigured) {
        expect(find.byType(ConfigErrorScreen), findsOneWidget);
        expect(find.text('CONFIGURATION REQUIRED'), findsOneWidget);
      }
    });
  });
}

/// Fake AuthService for local testing without calling Supabase network
class FakeAuthService implements AuthService {
  bool _loggedIn = false;
  RiderProfile _rider = RiderProfile(
    name: 'Ananya Rider',
    email: 'ananya.rider@shetorque.io',
    phone: '+91 98765 43210',
    emergencyContactName: 'Emergency Contact',
    emergencyContactPhone: '+91 99999 88888',
  );
  BikeInfo _bike = BikeInfo(
    brand: 'Royal Enfield',
    model: 'Hunter 350',
    regNumber: 'KA 03 HA 9876',
  );
  String? _safetyPinHash;

  @override
  Future<AuthResult> login(String email, String password) async {
    if (email == 'ananya.rider@shetorque.io' && password == 'password123') {
      _loggedIn = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          SupabaseAuthService.kCachedEmergencyContact, _rider.emergencyContactPhone);
      return AuthResult(true, 'Login successful', userId: 'mock-user-123');
    }
    return AuthResult(false, 'Invalid email or password.');
  }

  @override
  Future<AuthResult> signUp(String email, String password, {String? fullName}) async {
    _loggedIn = true;
    _rider.name = fullName ?? 'Rider';
    _rider.email = email;
    return AuthResult(true, 'Account created', userId: 'mock-user-123');
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SupabaseAuthService.kCachedEmergencyContact);
    await prefs.remove(SupabaseAuthService.kCachedSafetyPinHash);
  }

  @override
  Future<bool> isLoggedIn() async => _loggedIn;

  @override
  Future<String?> currentUser() async => _loggedIn ? _rider.email : null;

  @override
  Future<String?> currentUserId() async => _loggedIn ? 'mock-user-123' : null;

  @override
  Future<RiderProfile> getRiderProfile() async => _rider;

  @override
  Future<void> saveRiderProfile(RiderProfile profile) async {
    _rider = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        SupabaseAuthService.kCachedEmergencyContact, profile.emergencyContactPhone);
  }

  @override
  Future<BikeInfo> getVehicleProfile() async => _bike;

  @override
  Future<void> saveVehicleProfile(BikeInfo bike) async {
    _bike = bike;
  }

  @override
  Future<void> saveSafetyPin(String pin) async {
    final hash = SupabaseAuthService.hashSafetyPin(pin);
    _safetyPinHash = hash;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SupabaseAuthService.kCachedSafetyPinHash, hash);
  }

  @override
  Future<bool> verifySafetyPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedHash =
        prefs.getString(SupabaseAuthService.kCachedSafetyPinHash) ?? _safetyPinHash;
    if (cachedHash == null || cachedHash.isEmpty) return false;
    return SupabaseAuthService.hashSafetyPin(enteredPin) == cachedHash;
  }

  @override
  Future<String?> getCachedEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SupabaseAuthService.kCachedEmergencyContact);
  }
}
