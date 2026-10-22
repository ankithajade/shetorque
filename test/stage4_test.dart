// Stage 4 tests: BikeTelemetryCalculator (A5) + FollowerTracker (Part B)
// + SosSessionManager ValueNotifier (A1 verification)
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shetorque_hub/services/bike_telemetry_calculator.dart';
import 'package:shetorque_hub/services/follower_tracker.dart';
import 'package:shetorque_hub/services/sos_session_manager.dart';
import 'package:shetorque_hub/models/vehicle_detection.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════════════════════
  // A5: BikeTelemetryCalculator unit tests
  // ════════════════════════════════════════════════════════════════════════════
  group('BikeTelemetryCalculator Tests', () {
    test('Fuel range is correct for full tank (100%)', () {
      final range = BikeTelemetryCalculator.calculateRemainingRangeKm(
        fuelCapacityL: 13.0,
        avgMileageKmpl: 35.0,
        fuelLevelPercent: 100.0,
      );
      // 13L * 35 km/L = 455 km
      expect(range, closeTo(455.0, 0.1));
    });

    test('Fuel range is correct for half tank (50%)', () {
      final range = BikeTelemetryCalculator.calculateRemainingRangeKm(
        fuelCapacityL: 13.0,
        avgMileageKmpl: 35.0,
        fuelLevelPercent: 50.0,
      );
      expect(range, closeTo(227.5, 0.1));
    });

    test('Fuel range is 0 for empty tank', () {
      final range = BikeTelemetryCalculator.calculateRemainingRangeKm(
        fuelCapacityL: 13.0,
        avgMileageKmpl: 35.0,
        fuelLevelPercent: 0.0,
      );
      expect(range, 0.0);
    });

    test('Fuel range is 0 when fuelCapacityL is 0', () {
      final range = BikeTelemetryCalculator.calculateRemainingRangeKm(
        fuelCapacityL: 0.0,
        avgMileageKmpl: 35.0,
        fuelLevelPercent: 80.0,
      );
      expect(range, 0.0);
    });

    test('Fuel range is 0 when avgMileageKmpl is 0', () {
      final range = BikeTelemetryCalculator.calculateRemainingRangeKm(
        fuelCapacityL: 13.0,
        avgMileageKmpl: 0.0,
        fuelLevelPercent: 80.0,
      );
      expect(range, 0.0);
    });

    test('Fuel range clamps negative fuelLevelPercent to 0', () {
      final range = BikeTelemetryCalculator.calculateRemainingRangeKm(
        fuelCapacityL: 13.0,
        avgMileageKmpl: 35.0,
        fuelLevelPercent: -10.0,
      );
      expect(range, 0.0);
    });

    test('50% consumed threshold triggers advisory alert (fuelLevel=50%)', () {
      // 50% remaining -> 50% consumed -> advisory
      final level = BikeTelemetryCalculator.getFuelAlertLevel(50.0);
      expect(level, FuelAlertLevel.advisory);
    });

    test('Fuel consumed exactly 50% gives advisory', () {
      final consumed =
          BikeTelemetryCalculator.calculateFuelConsumedPercent(50.0);
      expect(consumed, closeTo(50.0, 0.01));
      expect(BikeTelemetryCalculator.getFuelAlertLevel(50.0),
          FuelAlertLevel.advisory);
    });

    test('75% consumed threshold triggers critical alert (fuelLevel=25%)', () {
      // 25% remaining -> 75% consumed -> critical
      final level = BikeTelemetryCalculator.getFuelAlertLevel(25.0);
      expect(level, FuelAlertLevel.critical);
    });

    test('Fuel consumed exactly 75% gives critical', () {
      final consumed =
          BikeTelemetryCalculator.calculateFuelConsumedPercent(25.0);
      expect(consumed, closeTo(75.0, 0.01));
      expect(BikeTelemetryCalculator.getFuelAlertLevel(25.0),
          FuelAlertLevel.critical);
    });

    test('Above 50% fuel remaining gives no alert', () {
      expect(BikeTelemetryCalculator.getFuelAlertLevel(51.0),
          FuelAlertLevel.none);
      expect(BikeTelemetryCalculator.getFuelAlertLevel(80.0),
          FuelAlertLevel.none);
      expect(BikeTelemetryCalculator.getFuelAlertLevel(100.0),
          FuelAlertLevel.none);
    });

    test('Service due in correct km when not yet overdue', () {
      // lastService=3000, odometer=4820, interval=3000 -> due in 3000-(4820-3000)=1180
      final dueIn = BikeTelemetryCalculator.calculateServiceDueInKm(
        currentOdometerKm: 4820.0,
        lastServiceKm: 3000.0,
      );
      expect(dueIn, closeTo(1180.0, 0.1));
    });

    test('isServiceOverdue returns false when service is not yet due', () {
      final overdue = BikeTelemetryCalculator.isServiceOverdue(
        currentOdometerKm: 4820.0,
        lastServiceKm: 3000.0,
      );
      expect(overdue, false);
    });

    test('isServiceOverdue returns true when past interval', () {
      final overdue = BikeTelemetryCalculator.isServiceOverdue(
        currentOdometerKm: 7500.0,
        lastServiceKm: 3000.0,
      );
      expect(overdue, true);
    });

    test('Service status text reflects overdue state', () {
      final text = BikeTelemetryCalculator.getServiceStatusText(
        currentOdometerKm: 7500.0,
        lastServiceKm: 3000.0,
      );
      expect(text, contains('overdue'));
    });

    test('Service status text reflects due-in km when not overdue', () {
      final text = BikeTelemetryCalculator.getServiceStatusText(
        currentOdometerKm: 4820.0,
        lastServiceKm: 3000.0,
      );
      expect(text, contains('180'));
    });

    test('getFuelAlertMessage returns null when no alert', () {
      final msg = BikeTelemetryCalculator.getFuelAlertMessage(
        fuelCapacityL: 13.0,
        avgMileageKmpl: 35.0,
        fuelLevelPercent: 80.0,
      );
      expect(msg, isNull);
    });

    test('getFuelAlertMessage includes consumed% and range for advisory', () {
      final msg = BikeTelemetryCalculator.getFuelAlertMessage(
        fuelCapacityL: 13.0,
        avgMileageKmpl: 35.0,
        fuelLevelPercent: 50.0,
      );
      expect(msg, isNotNull);
      expect(msg, contains('50%'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Part B: FollowerTracker unit tests (injectable fake clock)
  // ════════════════════════════════════════════════════════════════════════════
  group('FollowerTracker Tests', () {
    /// Helper: produce one vehicle detection with a fake Rect.
    VehicleDetection makeDetection(String id) => VehicleDetection(
          trackId: id,
          bbox: const Rect.fromLTWH(0.4, 0.7, 0.2, 0.15),
          confidence: 0.9,
          label: 'motorcycle',
        );

    test('No alert before threshold is reached', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 20,
        gapToleranceSeconds: 3,
        clock: () => now,
      );

      // 19 seconds of presence → no alert
      for (int i = 0; i < 19; i++) {
        now = now.add(const Duration(seconds: 1));
        final alerts = tracker.process([makeDetection('V1')]);
        expect(alerts, isEmpty, reason: 'Should not alert before 20s');
      }
    });

    test('Alert emitted exactly at threshold', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 20,
        gapToleranceSeconds: 3,
        clock: () => now,
      );

      List<dynamic> lastAlerts = [];
      for (int i = 0; i < 21; i++) {
        now = now.add(const Duration(seconds: 1));
        lastAlerts = tracker.process([makeDetection('V1')]);
      }
      expect(lastAlerts.length, 1);
      expect(lastAlerts.first.trackId, 'V1');
    });

    test('Only one alert per episode (not spammed on every frame)', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 5,
        gapToleranceSeconds: 3,
        clock: () => now,
      );

      int alertCount = 0;
      for (int i = 0; i < 30; i++) {
        now = now.add(const Duration(seconds: 1));
        alertCount += tracker.process([makeDetection('V1')]).length;
      }
      expect(alertCount, 1, reason: 'Exactly one alert per episode');
    });

    test('Dropout within gap tolerance does not reset episode', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 10,
        gapToleranceSeconds: 3,
        clock: () => now,
      );

      // 7 seconds present
      for (int i = 0; i < 7; i++) {
        now = now.add(const Duration(seconds: 1));
        tracker.process([makeDetection('V1')]);
      }
      // 2 second dropout (within 3 s tolerance)
      for (int i = 0; i < 2; i++) {
        now = now.add(const Duration(seconds: 1));
        tracker.process([]); // not seen
      }
      // 3 more seconds → should still fire (total > 10 s from firstSeen)
      final allAlerts = <dynamic>[];
      for (int i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 1));
        allAlerts.addAll(tracker.process([makeDetection('V1')]));
      }
      expect(allAlerts.length, 1,
          reason: 'Alert fires after tolerance dropout');
    });

    test('Dropout beyond gap tolerance resets episode', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 10,
        gapToleranceSeconds: 3,
        clock: () => now,
      );

      // 8 seconds present
      for (int i = 0; i < 8; i++) {
        now = now.add(const Duration(seconds: 1));
        tracker.process([makeDetection('V1')]);
      }
      // 5 second dropout (exceeds 3 s tolerance → episode reset)
      for (int i = 0; i < 5; i++) {
        now = now.add(const Duration(seconds: 1));
        tracker.process([]);
      }
      // 9 more seconds present → should NOT fire (new episode, only 9 s)
      List<dynamic> alerts = [];
      for (int i = 0; i < 9; i++) {
        now = now.add(const Duration(seconds: 1));
        alerts = tracker.process([makeDetection('V1')]);
      }
      expect(alerts, isEmpty,
          reason: 'Episode was reset; new episode < threshold');
    });

    test('Whitelisted vehicle suppresses alert', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 5,
        gapToleranceSeconds: 3,
        trustedMesh: {'GROUP-A'},
        clock: () => now,
      );

      int alertCount = 0;
      for (int i = 0; i < 20; i++) {
        now = now.add(const Duration(seconds: 1));
        alertCount += tracker.process([makeDetection('GROUP-A')]).length;
      }
      expect(alertCount, 0, reason: 'Whitelisted vehicle must never alert');
    });

    test('Non-whitelisted vehicle alerts even when whitelist is non-empty', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 5,
        gapToleranceSeconds: 3,
        trustedMesh: {'TRUSTED'},
        clock: () => now,
      );

      int alertCount = 0;
      for (int i = 0; i < 10; i++) {
        now = now.add(const Duration(seconds: 1));
        alertCount += tracker
            .process([makeDetection('TRUSTED'), makeDetection('STRANGER')])
            .length;
      }
      expect(alertCount, 1, reason: 'STRANGER should alert once');
    });

    test('reset() clears all tracking state', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 5,
        gapToleranceSeconds: 3,
        clock: () => now,
      );

      for (int i = 0; i < 6; i++) {
        now = now.add(const Duration(seconds: 1));
        tracker.process([makeDetection('V1')]);
      }
      expect(tracker.currentTrackedSeconds, isNotEmpty);
      tracker.reset();
      expect(tracker.currentTrackedSeconds, isEmpty);
    });

    test('Alert fires after disappearance and reappearance beyond tolerance', () {
      var now = DateTime(2025);
      final tracker = FollowerTracker(
        thresholdSeconds: 5,
        gapToleranceSeconds: 3,
        clock: () => now,
      );

      // First episode: fires after 5s
      for (int i = 0; i < 6; i++) {
        now = now.add(const Duration(seconds: 1));
        tracker.process([makeDetection('V1')]);
      }

      // Long absence — resets episode
      for (int i = 0; i < 10; i++) {
        now = now.add(const Duration(seconds: 1));
        tracker.process([]);
      }

      // Second episode: should fire a new alert after 5s again
      int secondEpisodeAlerts = 0;
      for (int i = 0; i < 7; i++) {
        now = now.add(const Duration(seconds: 1));
        secondEpisodeAlerts +=
            tracker.process([makeDetection('V1')]).length;
      }
      expect(secondEpisodeAlerts, 1,
          reason: 'Second episode should fire a new alert');
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // A1: SosSessionManager ValueNotifier (shield reactive source of truth)
  // ════════════════════════════════════════════════════════════════════════════
  group('SosSessionManager ValueNotifier Tests', () {
    test('sessionActiveNotifier starts false', () {
      // Reset to a known state
      SosSessionManager.sessionActiveNotifier.value = false;
      expect(SosSessionManager.sessionActiveNotifier.value, false);
    });

    test('startSession sets notifier to true synchronously', () async {
      SosSessionManager.sessionActiveNotifier.value = false;
      await SosSessionManager.startSession();
      expect(SosSessionManager.sessionActiveNotifier.value, true,
          reason: 'Shield should appear immediately on startSession');
    });

    test('endSession sets notifier to false synchronously', () async {
      SosSessionManager.sessionActiveNotifier.value = true;
      await SosSessionManager.endSession();
      expect(SosSessionManager.sessionActiveNotifier.value, false,
          reason: 'Shield should disappear immediately on endSession');
    });

    test('hydrateNotifier reads persisted state and updates notifier', () async {
      SharedPreferences.setMockInitialValues({
        SosSessionManager.kStealthSosActive: true,
      });
      await SosSessionManager.hydrateNotifier();
      expect(SosSessionManager.sessionActiveNotifier.value, true,
          reason: 'Notifier should hydrate from SharedPreferences at startup');
    });

    test('hydrateNotifier sets false when no persisted session', () async {
      SharedPreferences.setMockInitialValues({});
      await SosSessionManager.hydrateNotifier();
      expect(SosSessionManager.sessionActiveNotifier.value, false);
    });
  });
}
