import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';

import 'services/sos_session_manager.dart';
import 'services/sms_service.dart';
import 'services/location_tracker.dart';
import 'services/sos_notification_service.dart';
import 'services/occlusion_detector.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pin_checkin_screen.dart';
import 'models/stealth_sos_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SosNotificationService().init();
  runApp(const SheTorqueApp());
}

class SheTorqueApp extends StatefulWidget {
  const SheTorqueApp({super.key});

  @override
  State<SheTorqueApp> createState() => _SheTorqueAppState();
}

class _SheTorqueAppState extends State<SheTorqueApp> {
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _determineInitialScreen();
  }

  Future<void> _determineInitialScreen() async {
    bool isSessionActive = await SosSessionManager.isSessionActive();
    if (isSessionActive) {
      setState(() {
        _initialScreen = PinCheckinScreen(
          onSafeConfirmed: () {
            setState(() {
              _initialScreen = const SensorFusionHub();
            });
          },
        );
      });
      return;
    }

    bool hasOnboarded = await SosSessionManager.isOnboardingComplete();
    if (!hasOnboarded) {
      setState(() {
        _initialScreen = OnboardingScreen(
          onComplete: () {
            setState(() {
              _initialScreen = const SensorFusionHub();
            });
          },
        );
      });
      return;
    }

    setState(() {
      _initialScreen = const SensorFusionHub();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: _initialScreen ?? const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class SensorFusionHub extends StatefulWidget {
  const SensorFusionHub({super.key});
  @override
  _SensorFusionHubState createState() => _SensorFusionHubState();
}

class _SensorFusionHubState extends State<SensorFusionHub> with SingleTickerProviderStateMixin {
  final double crashThreshold = 25.0; 
  
  bool isCrashDetected = false;
  bool isSosSent = false;
  int countdownSeconds = 90;
  double liveGForce = 0.0;
  
  Timer? _displayTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _accelerometerSubscription;

  // Stealth SOS
  StealthSosState _stealthSosState = StealthSosState.idle;
  final OcclusionDetector _occlusionDetector = OcclusionDetector();
  Timer? _armedTimer;
  Timer? _armedUsecTimer;
  int _armedCountdown = 5;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAudio();
    _checkPermissions();
    _startListening();
    _initStealthSos();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_pulseController);
  }

  void _initStealthSos() {
    _occlusionDetector.onOcclusionConfirmed = () async {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.mediumImpact();
      
      setState(() {
        _stealthSosState = StealthSosState.armed;
        _armedCountdown = 5;
      });
      _occlusionDetector.setArmed(true);
      
      _armedUsecTimer?.cancel();
      _armedUsecTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
         setState(() {
            _armedCountdown--;
         });
      });

      _armedTimer?.cancel();
      _armedTimer = Timer(const Duration(seconds: 5), () {
        _armedUsecTimer?.cancel();
        _triggerStealthDispatch();
      });
    };

    _occlusionDetector.onCancelGestureDetected = () async {
      if (_stealthSosState == StealthSosState.confirmed || _stealthSosState == StealthSosState.armed) {
        await HapticFeedback.heavyImpact();
        _armedTimer?.cancel();
        _armedUsecTimer?.cancel();
        _occlusionDetector.setArmed(false);
        setState(() {
          _stealthSosState = StealthSosState.idle;
        });
      }
    };
    
    _occlusionDetector.startMonitoring();
  }

  Future<void> _resolveStealthSos() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _stealthSosState = StealthSosState.resolved;
    });
    await SmsService.sendSafeConfirmation();
    LocationTracker().stopTracking();
    await SosNotificationService().cancelNotification();
    await SosSessionManager.endSession();
    setState(() {
      _stealthSosState = StealthSosState.idle;
    });
  }

  Future<void> _triggerStealthDispatch() async {
    _occlusionDetector.setArmed(false);
    await SosSessionManager.startSession();
    
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    await SmsService.sendStealthAlert(position);
    
    await SosNotificationService().showPersistentNotification();
    
    LocationTracker().startTracking(onExpired: () async {
      await SosSessionManager.endSession();
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (c) => PinCheckinScreen(onSafeConfirmed: () {
               Navigator.of(context).pushReplacement(
                 MaterialPageRoute(builder: (c) => const SensorFusionHub())
               );
            }))
        );
      }
    });

    await HapticFeedback.heavyImpact();

    setState(() {
      _stealthSosState = StealthSosState.tracking;
    });
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
      await _audioPlayer.setSource(UrlSource('https://crude-silver-wzcjnmjo5u.edgeone.app/emergency_alarm_siren.mp3'));
    } catch (e) {
      print("Audio Setup Error: $e");
    }
  }

  Future<void> _checkPermissions() async {
    await Geolocator.requestPermission();
    await Permission.sms.request();
    await Permission.notification.request();
  }

  void _startListening() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double g = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      setState(() {
        liveGForce = g;
      });

      if (!isCrashDetected && !isSosSent && g > crashThreshold) {
        _triggerCrashProtocol();
      }
    });
  }

  void _triggerCrashProtocol() {
    setState(() {
      isCrashDetected = true;
      countdownSeconds = 90;
    });

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.resume(); 

    _displayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (countdownSeconds > 0) {
          countdownSeconds--;
        } else {
          _displayTimer?.cancel();
          _sendFinalSOS(); 
        }
      });
    });
  }

  Future<void> _sendFinalSOS() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      await SmsService.sendCrashAlert(position);
      _onSosSent();
    } catch (e) {
      print("SOS Error: $e");
    }
  }

  void _onSosSent() {
    _audioPlayer.stop();
    setState(() {
      isCrashDetected = false;
      isSosSent = true;
    });
  }

  void _cancelSOS() {
    _displayTimer?.cancel();
    _audioPlayer.stop();
    setState(() {
      isCrashDetected = false;
      isSosSent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.black;
    if (isSosSent) bgColor = Colors.green.shade900;
    else if (isCrashDetected) bgColor = Colors.red.shade900;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              Center(
                child: isSosSent ? _buildSuccessUI() : (isCrashDetected ? _buildCrashUI() : _buildNormalUI()),
              ),
              if (_stealthSosState == StealthSosState.tracking || _stealthSosState == StealthSosState.dispatched)
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
              if (_stealthSosState == StealthSosState.dispatched || _stealthSosState == StealthSosState.tracking)
                Positioned(
                  bottom: 24,
                  left: 16,
                  child: _SafeCancelButton(
                    onConfirmed: _resolveStealthSos,
                  ),
                ),
              if (_stealthSosState == StealthSosState.armed)
                Positioned(
                  bottom: 60,
                  right: 40,
                  child: Text('$_armedCountdown', style: const TextStyle(color: Colors.red, fontSize: 48, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        if (_stealthSosState == StealthSosState.armed)
          IgnorePointer(
            child: Container(
              color: Colors.red.withOpacity(0.12),
            ),
          ),
      ],
    );
  }

  Widget _buildNormalUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.motorcycle, size: 100, color: Colors.blueAccent),
        const SizedBox(height: 20),
        const Text("SHETORQUE: HUB ACTIVE", 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              const Text("IMU SENSOR FUSION", style: TextStyle(color: Colors.blueAccent)),
              const SizedBox(height: 10),
              Text("${liveGForce.toStringAsFixed(2)} G", 
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrashUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.white),
        const Text("CRASH DETECTED!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Text("SOS WILL BE SENT IN", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("$countdownSeconds", style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, 
            foregroundColor: Colors.red.shade900, 
            minimumSize: const Size(280, 75)
          ),
          onPressed: _cancelSOS,
          child: const Text("I AM OK - CANCEL", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSuccessUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 100, color: Colors.white),
        const SizedBox(height: 20),
        const Text("SOS SENT", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Text("Emergency SMS with location has been automatically sent to your emergency contact.", 
            textAlign: TextAlign.center),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => setState(() => isSosSent = false),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
          child: const Text("RESET HUB", style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _displayTimer?.cancel();
    _armedTimer?.cancel();
    _armedUsecTimer?.cancel();
    _occlusionDetector.stopMonitoring();
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

class _SafeCancelButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  const _SafeCancelButton({required this.onConfirmed});

  @override
  State<_SafeCancelButton> createState() => _SafeCancelButtonState();
}

class _SafeCancelButtonState extends State<_SafeCancelButton>
    with SingleTickerProviderStateMixin {

  bool _expanded = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: _expanded ? _buildExpanded() : _buildCollapsed(),
    );
  }

  Widget _buildCollapsed() {
    return FadeTransition(
      opacity: _pulseAnimation,
      child: FloatingActionButton.small(
        heroTag: 'safe_cancel_fab',
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: () => setState(() => _expanded = true),
        child: const Icon(Icons.shield_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildExpanded() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            child: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            onPressed: widget.onConfirmed,
            child: const Text('I Am Safe', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}