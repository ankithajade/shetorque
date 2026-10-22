import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../theme/she_torque_theme.dart';
import '../../models/rider_profile.dart';
import '../../models/bike_info.dart';
import '../../models/stealth_sos_state.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/sms_service.dart';
import '../../services/location_tracker.dart';
import '../../services/sos_notification_service.dart';
import '../../services/sos_session_manager.dart';
import '../../services/occlusion_detector.dart';
import '../pin_checkin_screen.dart';
import 'tabs/garage_tab.dart';
import 'tabs/rides_tab.dart';
import 'tabs/safe_routing_tab.dart';
import 'tabs/diagnostics_tab.dart';
import 'tabs/community_tab.dart';
import 'tabs/profile_tab.dart';
import '../../screens/safety_hub_screen.dart';
import '../../screens/guardian_eye_screen.dart';
import '../../models/ecu_data.dart';
import '../../models/vehicle_health.dart';
import '../../services/mock_ecu_service.dart';
import '../../services/diagnostic_engine.dart';

/// The central authenticated application shell hosting the 5-tab dashboard
/// while running the validated Phase-1 Safety Host underneath.
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentTabIndex = 0;
  bool _showProfile = false;

  // Profiles
  RiderProfile _rider = RiderProfile();
  BikeInfo _bike = BikeInfo();

  // Live Vehicle Telemetry & Diagnostics (Mock ECU Bridge)
  final MockEcuService _ecuService = MockEcuService.instance;
  final DiagnosticEngine _diagnosticEngine = const DiagnosticEngine();
  StreamSubscription<EcuData>? _ecuSubscription;
  late EcuData _ecuData;
  late VehicleHealth _vehicleHealth;

  // --- Phase-1 Safety Engine State (Preserved) ---
  final double _crashThreshold = 25.0; // Validated 25G threshold
  bool _isCrashDetected = false;
  bool _isCrashSosSent = false;
  int _crashCountdown = 90; // Validated 90s countdown

  Timer? _crashDisplayTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Stealth SOS
  StealthSosState _stealthSosState = StealthSosState.idle;
  final OcclusionDetector _occlusionDetector = OcclusionDetector();
  Timer? _armedTimer;
  Timer? _armedCountdownTimer;
  int _armedCountdown = 5; // Validated 5s armed buffer

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _ecuData = _ecuService.current;
    _vehicleHealth = _diagnosticEngine.evaluate(_ecuData);
    _ecuSubscription = _ecuService.telemetryStream.listen((data) {
      if (mounted) {
        if (SosSessionManager.sessionActiveNotifier.value) {
          debugPrint(
              '[SHIELD] Dashboard setState while session active (ECU telemetry tick)');
        }
        setState(() {
          _ecuData = data;
          _vehicleHealth = _diagnosticEngine.evaluate(data);
        });
      }
    });
    _ecuService.start();

    _loadUserProfiles();
    _initSafetyHost();
    SosSessionManager.sessionActiveNotifier
        .addListener(_onSessionActiveNotification);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation =
        Tween<double>(begin: 0.3, end: 1.0).animate(_pulseController);
  }

  Future<void> _loadUserProfiles() async {
    final rider = await SupabaseAuthService.instance.getRiderProfile();
    final bike = await SupabaseAuthService.instance.getVehicleProfile();
    if (mounted) {
      setState(() {
        _rider = rider;
        _bike = bike;
      });
    }
  }

  // ==========================================================================
  // SAFETY HOST: Ambient Hardware Monitoring (Phase-1 Validated Logic)
  // ==========================================================================
  Future<void> _initSafetyHost() async {
    await _checkPermissions();
    _setupAudio();
    _startCrashSensorListener();
    _initStealthOcclusionListener();
    // sessionActiveNotifier is hydrated in main() via hydrateNotifier();
    // the ValueListenableBuilder in build() reacts automatically.
  }

  Future<void> _checkPermissions() async {
    try {
      await Geolocator.requestPermission();
      await Permission.sms.request();
      await Permission.notification.request();
    } catch (_) {}
  }

  Future<void> _setupAudio() async {
    try {
      await _audioPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ));
      await _audioPlayer.setSource(
          AssetSource('audio/emergency_alarm_siren.mp3'));
    } catch (_) {}
  }

  void _onSessionActiveNotification() {
    final active = SosSessionManager.sessionActiveNotifier.value;
    debugPrint('[SHIELD] sessionActiveNotifier changed: $active');
    if (!mounted) return;
    if (!active && _stealthSosState != StealthSosState.idle) {
      setState(() {
        _stealthSosState = StealthSosState.idle;
      });
    }
  }

  void _pauseDashboardSafetyMonitoring() {
    _occlusionDetector.stopMonitoring();
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  void _resumeDashboardSafetyMonitoring() {
    _occlusionDetector.startMonitoring();
    _startCrashSensorListener();
  }

  Future<void> _openSafetyHub() async {
    _pauseDashboardSafetyMonitoring();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SafetyHubScreen()),
    );
    if (mounted) {
      _resumeDashboardSafetyMonitoring();
    }
  }

  bool _isOpeningPinScreen = false;

  /// Opens the PIN check-in screen. Used by the active SOS banner when the rider
  /// wants to confirm they are safe and resolve the active SOS session.
  void _openPinCheckin() async {
    if (_isOpeningPinScreen) {
      debugPrint('[SHIELD] _openPinCheckin ignored: PIN screen already opening');
      return;
    }
    _isOpeningPinScreen = true;
    debugPrint('[SHIELD] Before Navigator.push to PinCheckinScreen');
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PinCheckinScreen(
            onSafeConfirmed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ),
      );
    } finally {
      _isOpeningPinScreen = false;
      debugPrint('[SHIELD] After Navigator.push to PinCheckinScreen');
    }
  }

  /// Single, exclusive listener for Accelerometer events
  void _startCrashSensorListener() {
    _accelerometerSubscription =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      final double g =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      if (!_isCrashDetected && !_isCrashSosSent && g > _crashThreshold) {
        _triggerCrashProtocol();
      }
    });
  }

  /// Single, exclusive listener for Proximity occlusion events
  void _initStealthOcclusionListener() {
    _occlusionDetector.onOcclusionConfirmed = () async {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.mediumImpact();

      if (!mounted) return;
      setState(() {
        _stealthSosState = StealthSosState.armed;
        _armedCountdown = 5;
      });
      _occlusionDetector.setArmed(true);

      _armedCountdownTimer?.cancel();
      _armedCountdownTimer =
          Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _armedCountdown--;
          });
        }
      });

      _armedTimer?.cancel();
      _armedTimer = Timer(const Duration(seconds: 5), () {
        _armedCountdownTimer?.cancel();
        _triggerStealthDispatch();
      });
    };

    _occlusionDetector.onCancelGestureDetected = () async {
      if (_stealthSosState == StealthSosState.confirmed ||
          _stealthSosState == StealthSosState.armed) {
        await HapticFeedback.heavyImpact();
        _armedTimer?.cancel();
        _armedCountdownTimer?.cancel();
        _occlusionDetector.setArmed(false);
        if (mounted) {
          setState(() {
            _stealthSosState = StealthSosState.idle;
          });
        }
      }
    };

    _occlusionDetector.startMonitoring();
  }

  Future<void> _triggerStealthDispatch() async {
    _occlusionDetector.setArmed(false);
    await SosSessionManager.startSession();

    final isDemo = await SmsService.isDemoModeEnabled();
    SmsDispatchResult? result;

    try {
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      result =
          await SmsService.dispatchStealthAlert(position, isDemoMode: isDemo);
    } catch (_) {}

    await SosNotificationService().showPersistentNotification();

    LocationTracker().startTracking(onExpired: () async {
      await SosSessionManager.endSession();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (c) => PinCheckinScreen(onSafeConfirmed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
              );
            }),
          ),
        );
      }
    });

    await HapticFeedback.heavyImpact();

    if (mounted) {
      setState(() {
        _stealthSosState = StealthSosState.tracking;
      });
      if (isDemo && result != null) {
        _showDemoSmsPreviewDialog(
          title: 'SILENT SOS SIMULATION (DEMO MODE)',
          recipientName: result.recipientName ?? 'Emergency Contact',
          recipientPhone: result.recipientPhone ?? 'Cached Contact',
          messagePreview: result.message,
        );
      }
    }
  }

  Future<void> _resolveStealthSos() async {
    debugPrint('[SHIELD] _resolveStealthSos called');
    await HapticFeedback.heavyImpact();
    // Open PIN check-in. PinCheckinScreen calls endSession() on correct PIN.
    if (mounted) _openPinCheckin();
  }

  void _triggerCrashProtocol() {
    setState(() {
      _isCrashDetected = true;
      _crashCountdown = 90;
    });

    try {
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
      _audioPlayer.resume();
    } catch (_) {}

    _crashDisplayTimer?.cancel();
    _crashDisplayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_crashCountdown > 0) {
            _crashCountdown--;
          } else {
            _crashDisplayTimer?.cancel();
            _sendCrashFinalSOS();
          }
        });
      }
    });
  }

  Future<void> _sendCrashFinalSOS() async {
    final isDemo = await SmsService.isDemoModeEnabled();
    SmsDispatchResult? result;
    try {
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      result =
          await SmsService.dispatchCrashAlert(position, isDemoMode: isDemo);
    } catch (_) {}
    _onCrashSosSent();
    if (isDemo && result != null && mounted) {
      _showDemoSmsPreviewDialog(
        title: 'CRASH SOS SIMULATION (DEMO MODE)',
        recipientName: result.recipientName ?? 'Emergency Contact',
        recipientPhone: result.recipientPhone ?? 'Cached Contact',
        messagePreview: result.message,
      );
    }
  }

  void _onCrashSosSent() {
    _audioPlayer.stop();
    setState(() {
      _isCrashDetected = false;
      _isCrashSosSent = true;
    });
  }

  void _cancelCrashSOS() {
    _crashDisplayTimer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _isCrashDetected = false;
      _isCrashSosSent = false;
    });
  }

  // ==========================================================================
  // MODAL: Manual Test SOS (Preserved from Nisarga's Dashboard)
  // ==========================================================================
  void _showTestEmergencyModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SheTorqueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.dangerRed.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: SheTorqueTheme.dangerRed, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMERGENCY SOS ARMED',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: SheTorqueTheme.dangerRed,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Sensor Fusion & Native SMS Pipeline',
                          style: TextStyle(
                              fontSize: 12, color: SheTorqueTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SheTorqueTheme.border),
                ),
                child: Column(
                  children: [
                    _buildModalRow(
                      icon: Icons.person_pin_rounded,
                      label: 'Emergency Recipient',
                      value: _rider.emergencyContactName,
                    ),
                    const Divider(color: SheTorqueTheme.border, height: 18),
                    _buildModalRow(
                      icon: Icons.phone_in_talk_rounded,
                      label: 'Emergency Line',
                      value: _rider.emergencyContactPhone,
                    ),
                    const Divider(color: SheTorqueTheme.border, height: 18),
                    _buildModalRow(
                      icon: Icons.bloodtype_rounded,
                      label: 'Rider Blood Group',
                      value: _rider.bloodGroup,
                    ),
                    const Divider(color: SheTorqueTheme.border, height: 18),
                    const _ModalAutoGpsRow(),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Hardware protection is active. Instant impact exceeding 25.0 G or 3s proximity hold initiates emergency alerts.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 11.5, color: SheTorqueTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SheTorqueTheme.dangerRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: SheTorqueTheme.dangerRed,
                      content: Text(
                          'Test alert confirmed for ${_rider.emergencyContactPhone}.'),
                    ),
                  );
                },
                child: const Text('DISPATCH TEST SOS ALERT'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('DISMISS'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildModalRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SheTorqueTheme.primaryCyan),
        const SizedBox(width: 10),
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: SheTorqueTheme.textMuted)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: SheTorqueTheme.textWhite)),
      ],
    );
  }

  // ==========================================================================
  // TAB BUILDER
  // ==========================================================================
  Widget _buildCurrentTab() {
    if (_showProfile) {
      return ProfileTab(
        rider: _rider,
        bike: _bike,
        onTestSosPressed: _showTestEmergencyModal,
        onProfileUpdated: _loadUserProfiles,
      );
    }

    switch (_currentTabIndex) {
      case 0:
        return GarageTab(
          rider: _rider,
          bike: _bike,
          ecuData: _ecuData,
          vehicleHealth: _vehicleHealth,
          onSosPressed: _showTestEmergencyModal,
          onNavigateTab: (index) {
            setState(() {
              _showProfile = false;
              _currentTabIndex = index;
            });
          },
          onSafetyHubPressed: _openSafetyHub,
          onGuardianEyePressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const GuardianEyeScreen()),
          ),
        );
      case 1:
        return const RidesTab();
      case 2:
        return const SafeRoutingTab();
      case 3:
        return DiagnosticsTab(
          rider: _rider,
          ecuData: _ecuData,
          vehicleHealth: _vehicleHealth,
        );
      case 4:
        return const CommunityTab();
      default:
        return GarageTab(
          rider: _rider,
          bike: _bike,
          ecuData: _ecuData,
          vehicleHealth: _vehicleHealth,
          onSosPressed: _showTestEmergencyModal,
          onSafetyHubPressed: _openSafetyHub,
          onGuardianEyePressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const GuardianEyeScreen()),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        SheTorqueTheme.primaryCyan,
                        SheTorqueTheme.secondaryPink
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.two_wheeler_rounded,
                        size: 18, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _showProfile ? 'RIDER PROFILE' : 'SHETORQUE HUB',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          SheTorqueTheme.successGreen.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                        radius: 4,
                        backgroundColor: SheTorqueTheme.successGreen),
                    SizedBox(width: 6),
                    Text(
                      'SIMULATED ECU',
                      style: TextStyle(
                        color: SheTorqueTheme.successGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _showProfile
                      ? Icons.dashboard_rounded
                      : Icons.account_circle_outlined,
                  color: _showProfile
                      ? SheTorqueTheme.primaryCyan
                      : SheTorqueTheme.textWhite,
                ),
                onPressed: () {
                  setState(() => _showProfile = !_showProfile);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (!_showProfile &&
                  _rider.emergencyContactPhone.trim().isEmpty)
                Material(
                  color: SheTorqueTheme.dangerRed.withValues(alpha: 0.15),
                  child: InkWell(
                    onTap: () {
                      setState(() => _showProfile = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: SheTorqueTheme.dangerRed, width: 1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: SheTorqueTheme.dangerRed, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SAFETY ALERT: Emergency contact missing. Tap to configure.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Active SOS Pinned Full-Width Banner (Stage 4.1 Requirement 2) ──
              ValueListenableBuilder<bool>(
                valueListenable: SosSessionManager.sessionActiveNotifier,
                builder: (ctx, isActive, child) {
                  if (!isActive) return const SizedBox.shrink();
                  return _buildActiveSosBanner();
                },
              ),

              Expanded(child: _buildCurrentTab()),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: SheTorqueTheme.surface,
              border: Border(
                  top: BorderSide(color: SheTorqueTheme.border, width: 1)),
            ),
            child: BottomNavigationBar(
              currentIndex: _showProfile ? 0 : _currentTabIndex,
              onTap: (index) {
                setState(() {
                  _showProfile = false;
                  _currentTabIndex = index;
                });
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor:
                  _showProfile ? SheTorqueTheme.textMuted : SheTorqueTheme.primaryCyan,
              unselectedItemColor: SheTorqueTheme.textMuted,
              selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11.5),
              unselectedLabelStyle: const TextStyle(fontSize: 10.5),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.garage_rounded),
                  activeIcon: Icon(Icons.garage_rounded,
                      color: SheTorqueTheme.primaryCyan),
                  label: 'Garage',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.route_outlined),
                  activeIcon: Icon(Icons.route_rounded,
                      color: SheTorqueTheme.primaryCyan),
                  label: 'Rides',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: Icon(Icons.map_rounded,
                      color: SheTorqueTheme.primaryCyan),
                  label: 'Routing',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_outlined),
                  activeIcon: Icon(Icons.analytics_rounded,
                      color: SheTorqueTheme.primaryCyan),
                  label: 'Diagnostics',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_outlined),
                  activeIcon: Icon(Icons.people_alt_rounded,
                      color: SheTorqueTheme.primaryCyan),
                  label: 'HerRide',
                ),
              ],
            ),
          ),
        ),



        // --- OVERLAY: Armed Buffer 5s Countdown ---
        if (_stealthSosState == StealthSosState.armed) ...[
          IgnorePointer(
            child: Container(
              color: Colors.red.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 32,
            child: Text(
              '$_armedCountdown',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],

        // --- OVERLAY: Crash Detected (25G) Full-Screen Emergency View ---
        if (_isCrashDetected)
          Positioned.fill(
            child: Container(
              color: Colors.red.shade900,
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 80, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text("CRASH DETECTED!",
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const Text("SOS WILL BE SENT IN",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70)),
                      const SizedBox(height: 10),
                      Text("$_crashCountdown",
                          style: const TextStyle(
                              fontSize: 120,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                          minimumSize: const Size(280, 75),
                        ),
                        onPressed: _cancelCrashSOS,
                        child: const Text("I AM OK - CANCEL",
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // --- OVERLAY: Crash SOS Sent Confirmation ---
        if (_isCrashSosSent)
          Positioned.fill(
            child: Container(
              color: Colors.green.shade900,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 100, color: Colors.white),
                        const SizedBox(height: 20),
                        const Text("SOS SENT",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 40, vertical: 20),
                          child: Text(
                            "Emergency SMS with high-accuracy location has been sent to your emergency contact.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _isCrashSosSent = false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                          ),
                          child: const Text("RESET HUB",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    SosSessionManager.sessionActiveNotifier
        .removeListener(_onSessionActiveNotification);
    _pauseDashboardSafetyMonitoring();
    _ecuSubscription?.cancel();
    _ecuService.stop();
    _crashDisplayTimer?.cancel();
    _armedTimer?.cancel();
    _armedCountdownTimer?.cancel();
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Pinned full-width, high-contrast banner displayed while SOS session is active.
  /// Minimum 56dp tall, with pulsing red dot and shield icon. ONE tap opens PIN screen.
  Widget _buildActiveSosBanner() {
    return Material(
      color: Colors.red.shade900,
      elevation: 4,
      child: InkWell(
        onTap: () {
          debugPrint(
              '[SHIELD] Active SOS Banner tapped -> calling _resolveStealthSos');
          _resolveStealthSos();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade900,
            border: const Border(
              bottom: BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              // Pulsing red dot
              FadeTransition(
                opacity: _pulseAnimation,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Shield icon
              const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 12),
              // High-contrast alert text
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SILENT SOS ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap to enter safety PIN & cancel alert',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDemoSmsPreviewDialog({
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
          side: const BorderSide(
              color: SheTorqueTheme.secondaryPink, width: 1.5),
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
              'Autonomous SMS Message Payload (DEMO MODE):',
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
              'No native SMS was dispatched because DEMO MODE is active.',
              style: TextStyle(
                fontSize: 11,
                color: SheTorqueTheme.warningAmber,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('DISMISS',
                style: TextStyle(
                    color: SheTorqueTheme.secondaryPink,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ModalAutoGpsRow extends StatelessWidget {
  const _ModalAutoGpsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.location_on_rounded,
            size: 18, color: SheTorqueTheme.primaryCyan),
        SizedBox(width: 10),
        Text('Auto GPS Dispatch',
            style: TextStyle(fontSize: 13, color: SheTorqueTheme.textMuted)),
        Spacer(),
        Text('High-Precision GPS Armed',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: SheTorqueTheme.textWhite)),
      ],
    );
  }
}
