// Stage 4.1 Test Suite:
// 1. sessionActiveNotifier drives banner visibility
// 2. Demo mode ON blocks real SMS on MethodChannel com.shetorque.hub/sms
// 3. Demo mode OFF dispatches real SMS on MethodChannel
// 4. PIN checkin flow: wrong PIN keeps session active; correct PIN resolves session
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shetorque_hub/theme/she_torque_theme.dart';
import 'package:shetorque_hub/services/sms_service.dart';
import 'package:shetorque_hub/services/sos_session_manager.dart';
import 'package:shetorque_hub/services/supabase_auth_service.dart';
import 'package:shetorque_hub/screens/pin_checkin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const smsChannel = MethodChannel('com.shetorque.hub/sms');
  final List<MethodCall> smsChannelCalls = [];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    smsChannelCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsChannel, (MethodCall call) async {
      smsChannelCalls.add(call);
      return null;
    });

    // Reset session state
    await SosSessionManager.endSession();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsChannel, null);
  });

  group('Stage 4.1: Demo Mode Blocking Real SMS Tests', () {
    test('demo_mode_enabled defaults to true when unset in SharedPreferences',
        () async {
      final isDemo = await SmsService.isDemoModeEnabled();
      expect(isDemo, true);
    });

    test('setDemoModeEnabled persists false and true to cache', () async {
      await SmsService.setDemoModeEnabled(false);
      expect(await SmsService.isDemoModeEnabled(), false);

      await SmsService.setDemoModeEnabled(true);
      expect(await SmsService.isDemoModeEnabled(), true);
    });

    test('Demo Mode ON blocks real SMS on method channel for all pipelines',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          SupabaseAuthService.kCachedEmergencyContact, '+919876543210');
      await prefs.setString(
          SupabaseAuthService.kCachedEmergencyName, 'Mom');
      await SmsService.setDemoModeEnabled(true);

      final dummyPosition = Position(
        longitude: 77.5946,
        latitude: 12.9716,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 900.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      // 1. Stealth Alert
      final stealthRes =
          await SmsService.dispatchStealthAlert(dummyPosition);
      expect(stealthRes.isDemo, true);
      expect(stealthRes.success, true);
      expect(smsChannelCalls.isEmpty, true,
          reason: 'Stealth alert must not call sendSms in demo mode');

      // 2. Crash Alert
      final crashRes = await SmsService.dispatchCrashAlert(dummyPosition);
      expect(crashRes.isDemo, true);
      expect(crashRes.success, true);
      expect(smsChannelCalls.isEmpty, true,
          reason: 'Crash alert must not call sendSms in demo mode');

      // 3. Location Update
      final locRes =
          await SmsService.sendLocationUpdate(dummyPosition, 1);
      expect(locRes, true);
      expect(smsChannelCalls.isEmpty, true,
          reason: 'Location update must not call sendSms in demo mode');

      // 4. Safe Confirmation
      final safeRes = await SmsService.sendSafeConfirmation();
      expect(safeRes, true);
      expect(smsChannelCalls.isEmpty, true,
          reason: 'Safe confirmation must not call sendSms in demo mode');

      // 5. Guardian Follower Alert
      await SmsService.sendGuardianFollowerAlert(
        trackId: 'V-999',
        followedSeconds: 45,
      );
      expect(smsChannelCalls.isEmpty, true,
          reason: 'Guardian alert must not call sendSms in demo mode');
    });

    test('Demo Mode OFF dispatches real SMS to method channel', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          SupabaseAuthService.kCachedEmergencyContact, '+919876543210');
      await prefs.setString(
          SupabaseAuthService.kCachedEmergencyName, 'Mom');
      await SmsService.setDemoModeEnabled(false);

      final dummyPosition = Position(
        longitude: 77.5946,
        latitude: 12.9716,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 900.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      final stealthRes = await SmsService.dispatchStealthAlert(
        dummyPosition,
        isDemoMode: false,
      );
      expect(stealthRes.isDemo, false);
      expect(stealthRes.success, true);
      expect(smsChannelCalls.length, 1);
      expect(smsChannelCalls.first.method, 'sendSms');
      final args = smsChannelCalls.first.arguments as Map;
      expect(args['phone'], '+919876543210');
      expect(args['message'].toString().contains('SheTorque SOS'), true);
    });
  });

  group('Stage 4.1: sessionActiveNotifier & Pinned Banner Widget Tests', () {
    testWidgets('Banner renders when sessionActiveNotifier is true and hides when false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SheTorqueTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: SosSessionManager.sessionActiveNotifier,
                  builder: (ctx, isActive, child) {
                    if (!isActive) return const SizedBox.shrink();
                    return Material(
                      color: Colors.red.shade900,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: const Text('SILENT SOS ACTIVE'),
                      ),
                    );
                  },
                ),
                const Text('Dashboard Content'),
              ],
            ),
          ),
        ),
      );

      // Initially inactive -> banner must not be present
      expect(find.text('SILENT SOS ACTIVE'), findsNothing);
      expect(find.text('Dashboard Content'), findsOneWidget);

      // Start session -> banner must appear
      await SosSessionManager.startSession();
      await tester.pump();
      expect(find.text('SILENT SOS ACTIVE'), findsOneWidget);

      // End session -> banner must disappear
      await SosSessionManager.endSession();
      await tester.pump();
      expect(find.text('SILENT SOS ACTIVE'), findsNothing);
    });

    testWidgets('Tapping the banner can invoke callback immediately',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SheTorqueTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: SosSessionManager.sessionActiveNotifier,
                  builder: (ctx, isActive, child) {
                    if (!isActive) return const SizedBox.shrink();
                    return Material(
                      color: Colors.red.shade900,
                      child: InkWell(
                        onTap: () => tapped = true,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          width: double.infinity,
                          child: const Text('SILENT SOS ACTIVE'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await SosSessionManager.startSession();
      await tester.pump();

      await tester.tap(find.text('SILENT SOS ACTIVE'));
      expect(tapped, true);
    });
  });

  group('Stage 4.1: PIN Check-in Flow Tests', () {
    testWidgets('Wrong PIN keeps session active and shows attempts remaining',
        (tester) async {
      // Setup correct PIN "1234"
      await SupabaseAuthService.instance.saveSafetyPin('1234');
      await SosSessionManager.startSession();
      expect(await SosSessionManager.isSessionActive(), true);

      bool safeConfirmedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PinCheckinScreen(
            onSafeConfirmed: () {
              safeConfirmedCalled = true;
            },
          ),
        ),
      );

      // Enter wrong PIN "9999"
      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text('CONFIRM SAFE'));
      await tester.pumpAndSettle();

      // Session must still be active!
      expect(await SosSessionManager.isSessionActive(), true);
      expect(safeConfirmedCalled, false);
      expect(find.textContaining('Incorrect PIN (2 attempts remaining)'),
          findsOneWidget);
    });

    testWidgets('Correct PIN ends session, flips notifier to false, and calls onSafeConfirmed',
        (tester) async {
      await SupabaseAuthService.instance.saveSafetyPin('5678');
      await SosSessionManager.startSession();
      expect(SosSessionManager.sessionActiveNotifier.value, true);

      bool safeConfirmedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PinCheckinScreen(
            onSafeConfirmed: () {
              safeConfirmedCalled = true;
            },
          ),
        ),
      );

      // Enter correct PIN "5678"
      await tester.enterText(find.byType(TextField), '5678');
      await tester.tap(find.text('CONFIRM SAFE'));
      await tester.pumpAndSettle();

      expect(safeConfirmedCalled, true);
      expect(SosSessionManager.sessionActiveNotifier.value, false);
      expect(await SosSessionManager.isSessionActive(), false);
    });
  });
}
