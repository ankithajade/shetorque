import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const SheTorqueApp());

class SheTorqueApp extends StatelessWidget {
  const SheTorqueApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SensorFusionHub(),
    );
  }
}

class SensorFusionHub extends StatefulWidget {
  const SensorFusionHub({super.key});
  @override
  _SensorFusionHubState createState() => _SensorFusionHubState();
}

class _SensorFusionHubState extends State<SensorFusionHub> {
  // --- CONFIGURATION ---
  final String emergencyContact = "+916360826795"; // Update for your demo
  final double crashThreshold = 25.0; 
  
  bool isCrashDetected = false;
  bool isSosSent = false;
  int countdownSeconds = 90;
  double liveGForce = 0.0;
  
  Timer? _displayTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _accelerometerSubscription;

  // Platform channel for native SMS sending
  static const _smsChannel = MethodChannel('com.shetorque.hub/sms');

  @override
  void initState() {
    super.initState();
    _setupAudio();      // Pre-configures the siren
    _checkPermissions();
    _startListening();
  }

  // Configures audio to play even on silent/vibrate mode
  Future<void> _setupAudio() async {
    try {
      await _audioPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: const AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ));
      
      // Pre-load the siren sound from a reliable source
      await _audioPlayer.setSource(UrlSource('https://crude-silver-wzcjnmjo5u.edgeone.app/emergency_alarm_siren.mp3'));
    } catch (e) {
      print("Audio Setup Error: $e");
    }
  }

  Future<void> _checkPermissions() async {
    await Geolocator.requestPermission();
    await Permission.sms.request();
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

    // Start SIREN
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
      
      String mapLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      String message = "EMERGENCY: SheTorque Hub detected a crash! Rider is unresponsive. Location: $mapLink";

      // Send SMS automatically via native platform channel — no user interaction needed
      await _smsChannel.invokeMethod('sendSms', {
        'phone': emergencyContact,
        'message': message,
      });

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

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: isSosSent ? _buildSuccessUI() : (isCrashDetected ? _buildCrashUI() : _buildNormalUI()),
      ),
    );
  }

  // --- UI COMPONENTS ---

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
    _audioPlayer.dispose();
    super.dispose();
  }
}