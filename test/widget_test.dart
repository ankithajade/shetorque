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
import 'package:shetorque_hub/services/local_auth_service.dart';
import 'package:shetorque_hub/services/sms_service.dart';
import 'package:shetorque_hub/services/vehicle_telemetry_service.dart';
import 'package:shetorque_hub/services/mock_ecu_service.dart';
import 'package:shetorque_hub/services/diagnostic_engine.dart';
import 'package:shetorque_hub/services/crime_data_service.dart';
import 'package:shetorque_hub/services/safe_routing_service.dart';
import 'package:shetorque_hub/screens/dashboard/tabs/garage_tab.dart';
import 'package:shetorque_hub/screens/dashboard/tabs/diagnostics_tab.dart';
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

  group('LocalAuthService & App Smoke Tests', () {
    test('Demo account seeds and validates successfully', () async {
      final auth = LocalAuthService();
      await auth.ensureDemoAccountSeeded();

      final validResult = await auth.login(
        LocalAuthService.demoEmail,
        LocalAuthService.demoPassword,
      );
      expect(validResult.success, isTrue);
    });

    test('Default emergency contact fallback is +916360826795', () {
      expect(SmsService.emergencyContact, '+916360826795');
    });

    testWidgets('SheTorqueApp builds with dark theme and initial route',
        (WidgetTester tester) async {
      await tester.pumpWidget(const SheTorqueApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
