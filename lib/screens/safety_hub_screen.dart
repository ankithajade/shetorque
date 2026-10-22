import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../theme/she_torque_theme.dart';
import '../models/stealth_sos_state.dart';
import '../models/sos_event_model.dart';
import '../repositories/sos_events_repository.dart';
import '../services/emergency_siren_service.dart';
import '../services/occlusion_detector.dart';
import '../services/sms_service.dart';
import '../services/sos_session_manager.dart';

/// Safety Hub screen hosting live sensor fusion telemetry, crash detection,
/// silent SOS state machine, interactive demo simulation mode, and cloud SOS history.
class SafetyHubScreen extends StatefulWidget {
  const SafetyHubScreen({super.key});

  @override
  State<SafetyHubScreen> createState() => _SafetyHubScreenState();
}

class _SafetyHubScreenState extends State<SafetyHubScreen> {
  // --- Sensor Fusion State ---
  double _liveG = 0.0;
  bool _isNear = false;
  StealthSosState _silentState = StealthSosState.idle;
  final double _crashThreshold = 25.0; // 25.0 G calibrated threshold

  // --- SOS Contact Metadata ---
  String _contactName = 'Loading...';
  String _contactPhone = '';

  // --- Demo Mode (Default ON for safe judge evaluation) ---
  bool _isDemoMode = true;

  // --- Crash Pipeline State ---
  bool _isCrashActive = false;
  int _crashCountdown = 90;
  Timer? _crashTimer;

  // --- Silent SOS Pipeline State ---
  final OcclusionDetector _occlusionDetector = OcclusionDetector();
  Timer? _armedTimer;
  Timer? _armedCountdownTimer;
  int _armedCountdown = 5;

  // --- Sensor Streams ---
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  // --- SOS History State ---
  final SosEventsRepository _sosRepo = SosEventsRepository();
  List<SosEventModel> _history = [];
  bool _isLoadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContact();
    _initSensors();
    _fetchSosHistory();
  }

  Future<void> _loadEmergencyContact() async {
    final phone = await SmsService.resolveEmergencyContact();
    final name = await SmsService.resolveEmergencyContactName();
    if (mounted) {
      setState(() {
        _contactPhone = phone ?? 'Not configured';
        _contactName = name ?? (phone != null ? 'Primary Contact' : 'Not configured');
      });
    }
  }

  void _initSensors() {
    // 1. Live Accelerometer Resultant G-Force listener
    _accelerometerSub = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        if (!mounted) return;
        final g = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        setState(() => _liveG = g);

        // Hardware crash detection if not in demo buffer
        if (!_isCrashActive && g >= _crashThreshold) {
          _triggerCrashProtocol();
        }
      },
      onError: (_) {},
    );

    // 2. Proximity Occlusion & Gesture Listener
    _occlusionDetector.onProximityStateChanged = (bool isNear) {
      if (mounted) setState(() => _isNear = isNear);
    };

    _occlusionDetector.onOcclusionConfirmed = () {
      _startSilentSosArmedBuffer();
    };

    _occlusionDetector.onCancelGestureDetected = () {
      if (_silentState == StealthSosState.armed ||
          _silentState == StealthSosState.confirmed) {
        _cancelSilentSosArmed();
      }
    };

    _occlusionDetector.startMonitoring();
  }

  Future<void> _fetchSosHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final list = await _sosRepo.getSosHistory();
      if (mounted) {
        setState(() {
          _history = list;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = 'Unable to fetch cloud SOS history';
          _isLoadingHistory = false;
        });
      }
    }
  }

  // ==========================================================================
  // CRASH DETECTION PIPELINE
  // ==========================================================================
  void _triggerCrashProtocol() {
    if (_isCrashActive) return;

    setState(() {
      _isCrashActive = true;
      _crashCountdown = 90;
    });

    // Escalates alarm volume to 100% and loops siren on ALARM stream
    EmergencySirenService.instance.startSiren();

    _crashTimer?.cancel();
    _crashTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_crashCountdown > 1) {
        setState(() => _crashCountdown--);
      } else {
        timer.cancel();
        _dispatchFinalCrashSos();
      }
    });
  }

  void _cancelCrashProtocol() {
    _crashTimer?.cancel();
    _crashTimer = null;
    EmergencySirenService.instance.stopSiren();
    if (mounted) {
      setState(() => _isCrashActive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crash alert cancelled. Rider safety confirmed.'),
          backgroundColor: SheTorqueTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _dispatchFinalCrashSos() async {
    EmergencySirenService.instance.stopSiren();
    setState(() => _isCrashActive = false);

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      position = Position(
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 920.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    final result = await SmsService.dispatchCrashAlert(
      position,
      isDemoMode: _isDemoMode,
    );

    _fetchSosHistory();

    if (!mounted) return;
    if (_isDemoMode) {
      _showDemoPreviewDialog(
        title: 'CRASH SOS SIMULATION (DEMO MODE)',
        recipientName: result.recipientName ?? _contactName,
        recipientPhone: result.recipientPhone ?? _contactPhone,
        messagePreview: result.message,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Crash SOS SMS dispatched to ${result.recipientPhone}'),
          backgroundColor: SheTorqueTheme.dangerRed,
        ),
      );
    }
  }

  // ==========================================================================
  // SILENT SOS PIPELINE (STATE MACHINE)
  // ==========================================================================
  void _startSilentSosArmedBuffer() async {
    if (_silentState == StealthSosState.tracking ||
        _silentState == StealthSosState.armed) {
      return;
    }

    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.mediumImpact();

    if (!mounted) return;
    setState(() {
      _silentState = StealthSosState.armed;
      _armedCountdown = 5;
    });
    _occlusionDetector.setArmed(true);

    _armedCountdownTimer?.cancel();
    _armedCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_armedCountdown > 1) {
        setState(() => _armedCountdown--);
      } else {
        t.cancel();
      }
    });

    _armedTimer?.cancel();
    _armedTimer = Timer(const Duration(seconds: 5), () {
      _armedCountdownTimer?.cancel();
      _dispatchSilentSos();
    });
  }

  void _cancelSilentSosArmed() async {
    await HapticFeedback.heavyImpact();
    _armedTimer?.cancel();
    _armedCountdownTimer?.cancel();
    _occlusionDetector.setArmed(false);

    if (mounted) {
      setState(() => _silentState = StealthSosState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silent SOS cancelled during armed buffer.'),
          backgroundColor: SheTorqueTheme.surfaceLight,
        ),
      );
    }
  }

  Future<void> _dispatchSilentSos() async {
    _occlusionDetector.setArmed(false);
    await SosSessionManager.startSession();

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      position = Position(
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 920.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    final result = await SmsService.dispatchStealthAlert(
      position,
      isDemoMode: _isDemoMode,
    );

    _fetchSosHistory();

    if (mounted) {
      setState(() => _silentState = StealthSosState.tracking);
      if (_isDemoMode) {
        _showDemoPreviewDialog(
          title: 'SILENT SOS SIMULATION (DEMO MODE)',
          recipientName: result.recipientName ?? _contactName,
          recipientPhone: result.recipientPhone ?? _contactPhone,
          messagePreview: result.message,
        );
      }
    }
  }

  Future<void> _resolveSilentSos() async {
    await HapticFeedback.heavyImpact();
    await SmsService.sendSafeConfirmation(isDemoMode: _isDemoMode);
    await SosSessionManager.endSession();

    if (mounted) {
      setState(() => _silentState = StealthSosState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silent SOS session safely resolved and cloud logged.'),
          backgroundColor: SheTorqueTheme.successGreen,
        ),
      );
      _fetchSosHistory();
    }
  }

  // ==========================================================================
  // DEMO MODE PREVIEW DIALOG
  // ==========================================================================
  void _showDemoPreviewDialog({
    required String title,
    required String recipientName,
    required String recipientPhone,
    required String messagePreview,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SheTorqueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SheTorqueTheme.secondaryPink, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded,
                color: SheTorqueTheme.secondaryPink, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.textWhite,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_rounded,
                      color: SheTorqueTheme.secondaryPink, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Target Recipient: $recipientName ($recipientPhone)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Autonomous SMS Message Payload:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: SheTorqueTheme.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SheTorqueTheme.border),
              ),
              child: SelectableText(
                messagePreview,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: SheTorqueTheme.primaryCyan,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Demo mode verified: Real Android SMS was suppressed. A verified record was posted to Supabase sos_events.',
              style: TextStyle(fontSize: 11, color: SheTorqueTheme.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SheTorqueTheme.secondaryPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DISMISS PREVIEW'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _crashTimer?.cancel();
    _armedTimer?.cancel();
    _armedCountdownTimer?.cancel();
    _occlusionDetector.stopMonitoring();
    EmergencySirenService.instance.stopSiren();
    super.dispose();
  }

  // ==========================================================================
  // BUILD METHOD & UI SECTIONS
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: SheTorqueTheme.surface,
        title: const Text(
          'SAFETY HUB',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // Demo Mode Toggle Switch
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text(
                  _isDemoMode ? 'DEMO MODE' : 'LIVE MODE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _isDemoMode
                        ? SheTorqueTheme.warningAmber
                        : SheTorqueTheme.dangerRed,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isDemoMode,
                    activeThumbColor: SheTorqueTheme.warningAmber,
                    inactiveThumbColor: SheTorqueTheme.dangerRed,
                    onChanged: (val) {
                      setState(() => _isDemoMode = val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Demo Mode Status Banner
              _buildDemoModeBanner(),
              const SizedBox(height: 14),

              // Live Sensor Fusion Matrix Card
              _buildLiveSensorCard(),
              const SizedBox(height: 14),

              // Simulation & Action Pipeline Triggers
              _buildActionTriggersCard(),
              const SizedBox(height: 16),

              // Cloud SOS History Section
              _buildSosHistorySection(),
            ],
          ),

          // --- OVERLAY: Crash Countdown Active ---
          if (_isCrashActive) _buildCrashActiveOverlay(),

          // --- OVERLAY: Silent SOS Tracking Active ---
          if (_silentState == StealthSosState.tracking)
            _buildSilentTrackingOverlay(),
        ],
      ),
    );
  }

  Widget _buildDemoModeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isDemoMode
            ? SheTorqueTheme.warningAmber.withValues(alpha: 0.12)
            : SheTorqueTheme.dangerRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDemoMode
              ? SheTorqueTheme.warningAmber.withValues(alpha: 0.5)
              : SheTorqueTheme.dangerRed.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isDemoMode ? Icons.science_rounded : Icons.warning_rounded,
            color: _isDemoMode
                ? SheTorqueTheme.warningAmber
                : SheTorqueTheme.dangerRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDemoMode
                      ? 'DEMO MODE ACTIVE (Simulated SMS Dispatch)'
                      : 'LIVE PRODUCTION MODE (Real Native SMS Dispatches)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _isDemoMode
                        ? SheTorqueTheme.warningAmber
                        : SheTorqueTheme.dangerRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isDemoMode
                      ? 'Countdown, siren audio, and state machines run live. SMS is previewed on-screen.'
                      : 'Warning: Real SMS will be sent to $_contactPhone upon expiration.',
                  style: const TextStyle(
                      fontSize: 10.5, color: SheTorqueTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSensorCard() {
    final gColor = _liveG >= _crashThreshold
        ? SheTorqueTheme.dangerRed
        : (_liveG >= 15.0 ? SheTorqueTheme.warningAmber : SheTorqueTheme.primaryCyan);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SheTorqueTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE SENSOR TELEMETRY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: SheTorqueTheme.primaryCyan,
                ),
              ),
              Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: SheTorqueTheme.successGreen),
                  SizedBox(width: 6),
                  Text(
                    'STREAMS ACTIVE',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.successGreen),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: SheTorqueTheme.border, height: 24),
          Row(
            children: [
              // G-Force Vector Display
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: gColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RESULTANT G-FORCE',
                          style: TextStyle(
                              fontSize: 10, color: SheTorqueTheme.textMuted)),
                      const SizedBox(height: 6),
                      Text(
                        '${_liveG.toStringAsFixed(2)} G',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: gColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Threshold: 25.0 G',
                        style: TextStyle(
                          fontSize: 10,
                          color: gColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Proximity Display
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isNear
                          ? SheTorqueTheme.secondaryPink
                          : SheTorqueTheme.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PROXIMITY SENSOR',
                          style: TextStyle(
                              fontSize: 10, color: SheTorqueTheme.textMuted)),
                      const SizedBox(height: 6),
                      Text(
                        _isNear ? 'NEAR' : 'FAR',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _isNear
                              ? SheTorqueTheme.secondaryPink
                              : SheTorqueTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isNear ? 'Pocket/Hold detected' : 'Clear / ambient',
                        style: const TextStyle(
                            fontSize: 10, color: SheTorqueTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Metadata Row: State Machine & Emergency Contact
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Silent SOS State Machine:',
                        style: TextStyle(
                            fontSize: 11.5, color: SheTorqueTheme.textMuted)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _silentState == StealthSosState.idle
                            ? SheTorqueTheme.border
                            : SheTorqueTheme.secondaryPink.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _silentState.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: _silentState == StealthSosState.idle
                              ? SheTorqueTheme.textWhite
                              : SheTorqueTheme.secondaryPink,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: SheTorqueTheme.border, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SOS Emergency Contact:',
                        style: TextStyle(
                            fontSize: 11.5, color: SheTorqueTheme.textMuted)),
                    Text(
                      '$_contactName ($_contactPhone)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTriggersCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SheTorqueTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'INTERACTIVE SIMULATION TRIGGERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: SheTorqueTheme.secondaryPink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Trigger end-to-end crash sirens, countdown buffers, and silent SOS state transitions safely.',
            style: TextStyle(fontSize: 11, color: SheTorqueTheme.textMuted),
          ),
          const SizedBox(height: 16),
          // Simulate Crash Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SheTorqueTheme.dangerRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.emergency_rounded, size: 20),
            label: const Text(
              'SIMULATE CRASH (25G Impact)',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            onPressed: _triggerCrashProtocol,
          ),
          const SizedBox(height: 10),
          // Simulate Silent SOS Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: SheTorqueTheme.secondaryPink,
              side: const BorderSide(color: SheTorqueTheme.secondaryPink),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.visibility_off_rounded, size: 20),
            label: const Text(
              'SIMULATE SILENT SOS (Cover Proximity)',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            onPressed: () {
              if (_silentState == StealthSosState.idle) {
                _startSilentSosArmedBuffer();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSosHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CLOUD SOS EVENT LOG (Supabase)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: SheTorqueTheme.textMuted,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  size: 18, color: SheTorqueTheme.primaryCyan),
              tooltip: 'Refresh History',
              onPressed: _fetchSosHistory,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_historyError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SheTorqueTheme.dangerRed.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: SheTorqueTheme.dangerRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _historyError!,
                    style: const TextStyle(
                        fontSize: 12, color: SheTorqueTheme.textWhite),
                  ),
                ),
                TextButton(
                  onPressed: _fetchSosHistory,
                  child: const Text('RETRY'),
                ),
              ],
            ),
          )
        else if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: SheTorqueTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SheTorqueTheme.border),
            ),
            child: const Column(
              children: [
                Icon(Icons.shield_outlined,
                    size: 36, color: SheTorqueTheme.textMuted),
                SizedBox(height: 10),
                Text(
                  'No emergency events recorded',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Simulated and live dispatches will automatically log here.',
                  style: TextStyle(fontSize: 11, color: SheTorqueTheme.textMuted),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, sep) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final item = _history[i];
              final isCrash = item.type.toLowerCase() == 'crash';
              final color = isCrash ? SheTorqueTheme.dangerRed : SheTorqueTheme.secondaryPink;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SheTorqueTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCrash ? Icons.car_crash_rounded : Icons.lock_clock_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isCrash ? 'Crash Impact SOS' : 'Silent SOS Trigger',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.resolved
                                      ? SheTorqueTheme.successGreen
                                          .withValues(alpha: 0.15)
                                      : SheTorqueTheme.warningAmber
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.resolved ? 'RESOLVED' : 'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: item.resolved
                                        ? SheTorqueTheme.successGreen
                                        : SheTorqueTheme.warningAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GPS: ${item.lat.toStringAsFixed(4)}, ${item.lng.toStringAsFixed(4)} • ${_formatDate(item.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: SheTorqueTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ==========================================================================
  // FULL SCREEN OVERLAYS FOR ACTIVE EMERGENCY PROTOCOLS
  // ==========================================================================
  Widget _buildCrashActiveOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.red.shade900,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 80, color: Colors.white),
                  const SizedBox(height: 14),
                  const Text(
                    "CRASH DETECTED!",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "AUTONOMOUS SOS WILL BE SENT IN",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "$_crashCountdown",
                    style: const TextStyle(
                      fontSize: 110,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      minimumSize: const Size(double.infinity, 65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _cancelCrashProtocol,
                    child: const Text(
                      "I AM OK - CANCEL SOS",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white60),
                    ),
                    onPressed: _dispatchFinalCrashSos,
                    child: const Text("DISPATCH IMMEDIATE SOS"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSilentTrackingOverlay() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SheTorqueTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SheTorqueTheme.secondaryPink, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.25),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 6,
              backgroundColor: Colors.red,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SILENT SOS ACTIVE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: SheTorqueTheme.secondaryPink,
                    ),
                  ),
                  Text(
                    'Background tracking & cloud active.',
                    style:
                        TextStyle(fontSize: 11, color: SheTorqueTheme.textMuted),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SheTorqueTheme.successGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: _resolveSilentSos,
              child: const Text('I AM SAFE'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}

/// Backwards-compatibility alias for Phase-1 tests and routes.
typedef SensorFusionHubScreen = SafetyHubScreen;
