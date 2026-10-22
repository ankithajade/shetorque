import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// Centralized safety service managing the emergency alarm siren audio pipeline.
///
/// Implements forced alarm stream routing on Android, maximum volume escalation,
/// volume-down lock listener, and clean volume restoration on cancellation or resolution.
class EmergencySirenService with WidgetsBindingObserver {
  static final EmergencySirenService _instance = EmergencySirenService._internal();
  factory EmergencySirenService() => _instance;
  static EmergencySirenService get instance => _instance;

  EmergencySirenService._internal() {
    WidgetsBinding.instance.addObserver(this);
    _initAudioPlayer();
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<double>? _volumeListener;
  double? _previousAlarmVolume;
  bool _isPlaying = false;
  bool _isConfigured = false;

  bool get isPlaying => _isPlaying;

  Future<void> _initAudioPlayer() async {
    if (_isConfigured) return;
    try {
      // Configure audio routing strictly to the hardware ALARM stream on Android
      // so it sounds even if the device media/ringer is muted.
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setSource(AssetSource('audio/emergency_alarm_siren.mp3'));
      _isConfigured = true;
    } catch (e) {
      debugPrint('EmergencySirenService: Error initializing AudioPlayer: $e');
    }
  }

  /// Starts the emergency siren at maximum hardware alarm volume.
  ///
  /// Deliberate safety design: An emergency alarm must not be muted or
  /// silenced accidentally while a crash or distress protocol is active.
  /// If the user or bystander attempts to lower the alarm volume using physical
  /// volume rocker buttons, the active listener immediately restores it to 100%.
  Future<void> startSiren() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      await _initAudioPlayer();

      // 1. Snapshot previous alarm volume level before escalating
      try {
        _previousAlarmVolume = await FlutterVolumeController.getVolume(
          stream: AudioStream.alarm,
        );
      } catch (e) {
        debugPrint('EmergencySirenService: Failed reading alarm volume: $e');
        _previousAlarmVolume = 0.5;
      }

      // 2. Set alarm volume to maximum (1.0)
      try {
        await FlutterVolumeController.setVolume(
          1.0,
          stream: AudioStream.alarm,
        );
      } catch (e) {
        debugPrint('EmergencySirenService: Failed setting max volume: $e');
      }

      // 3. Attach active anti-mute listener while siren is active
      // Deliberate design: Automatically restores volume to 1.0 if lowered.
      _volumeListener?.cancel();
      try {
        _volumeListener = FlutterVolumeController.addListener(
          (double currentVolume) {
            if (_isPlaying && currentVolume < 0.95) {
              FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
            }
          },
          stream: AudioStream.alarm,
          emitOnStart: false,
        );
      } catch (e) {
        debugPrint('EmergencySirenService: Failed attaching volume listener: $e');
      }

      // 4. Play looped siren asset
      await _player.stop();
      await _player.play(AssetSource('audio/emergency_alarm_siren.mp3'));
    } catch (e) {
      debugPrint('EmergencySirenService: startSiren error: $e');
    }
  }

  /// Immediately stops the siren and restores the previous alarm volume.
  ///
  /// Guarantees that the device's alarm stream is never left stuck at max volume.
  Future<void> stopSiren() async {
    if (!_isPlaying) return;
    _isPlaying = false;

    // 1. Remove anti-mute volume listener
    try {
      _volumeListener?.cancel();
      _volumeListener = null;
      FlutterVolumeController.removeListener();
    } catch (_) {}

    // 2. Stop audio player
    try {
      await _player.stop();
    } catch (_) {}

    // 3. Restore previous alarm stream volume
    if (_previousAlarmVolume != null) {
      try {
        await FlutterVolumeController.setVolume(
          _previousAlarmVolume!,
          stream: AudioStream.alarm,
        );
      } catch (e) {
        debugPrint('EmergencySirenService: Failed restoring previous volume: $e');
      }
      _previousAlarmVolume = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the application is detached or terminated, ensure volume is restored
    if (state == AppLifecycleState.detached && _isPlaying) {
      stopSiren();
    }
  }

  /// Cleans up audio resources and listeners.
  void dispose() {
    stopSiren();
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
  }
}
