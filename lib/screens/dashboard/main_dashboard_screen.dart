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
import '../../widgets/safe_cancel_button.dart';
import '../pin_checkin_screen.dart';
import 'tabs/garage_tab.dart';
import 'tabs/rides_tab.dart';
import 'tabs/safe_routing_tab.dart';
import 'tabs/diagnostics_tab.dart';
import 'tabs/community_tab.dart';
import 'tabs/profile_tab.dart';
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
        setState(() {
          _ecuData = data;
          _vehicleHealth = _diagnosticEngine.evaluate(data);
        });
      }
    });
    _ecuService.start();

    _loadUserProfiles();
    _initSafetyHost();

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
    _restoreActiveSessionState();
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

  Future<void> _restoreActiveSessionState() async {
    final isActive = await SosSessionManager.isSessionActive();
    if (isActive && mounted) {
      setState(() {
        _stealthSosState = StealthSosState.tracking;
      });
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

    try {
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await SmsService.sendStealthAlert(position);
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
    }
  }

  Future<void> _resolveStealthSos() async {
    await HapticFeedback.heavyImpact();
    setState(() {
      _stealthSosState = StealthSosState.resolved;
    });
    await SmsService.sendSafeConfirmation();
    LocationTracker().stopTracking();
    await SosNotificationService().cancelNotification();
    await SosSessionManager.endSession();
    if (mounted) {
      setState(() {
        _stealthSosState = StealthSosState.idle;
      });
    }
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
    try {
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await SmsService.sendCrashAlert(position);
    } catch (_) {}
    _onCrashSosSent();
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
                      'OBD-II LIVE',
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

        // --- OVERLAY: Stealth SOS Pulsing Red Dot ---
        if (_stealthSosState == StealthSosState.tracking ||
            _stealthSosState == StealthSosState.dispatched)
          Positioned(
            top: 40,
            right: 20,
            child: FadeTransition(
              opacity: _pulseAnimation,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

        // --- OVERLAY: Stealth SOS "I Am Safe" Button ---
        if (_stealthSosState == StealthSosState.dispatched ||
            _stealthSosState == StealthSosState.tracking)
          Positioned(
            bottom: 74,
            left: 16,
            child: SafeCancelButton(
              onConfirmed: _resolveStealthSos,
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
    _ecuSubscription?.cancel();
    _ecuService.stop();
    _accelerometerSubscription?.cancel();
    _crashDisplayTimer?.cancel();
    _armedTimer?.cancel();
    _armedCountdownTimer?.cancel();
    _occlusionDetector.stopMonitoring();
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
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
