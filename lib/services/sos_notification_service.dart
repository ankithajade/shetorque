import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class SosNotificationService {
  static final SosNotificationService _instance = SosNotificationService._internal();
  factory SosNotificationService() => _instance;
  SosNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  Timer? _countdownTimer;
  int _secondsRemaining = 300; 
  VoidCallback? onCancelTapped;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'cancel_stealth_sos') {
          if (onCancelTapped != null) onCancelTapped!();
        }
      },
    );
  }

  Future<void> showPersistentNotification() async {
    _secondsRemaining = 300; 
    await _updateNotification();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      _secondsRemaining -= 60;
      if (_secondsRemaining <= 0) {
        _secondsRemaining = 300; 
      }
      await _updateNotification();
    });
  }

  Future<void> _updateNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'stealth_sos_channel',
      'Silent SOS Alert',
      channelDescription: 'Ongoing notification for stealth SOS mode.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      color: Color(0xFFD32F2F),
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      1001, 
      'Silent SOS Active',
      'Silent SOS active — open the app to cancel',
      platformChannelSpecifics,
    );
  }

  Future<void> cancelNotification() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    await _flutterLocalNotificationsPlugin.cancel(1001);
  }
}
