import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'sos_session_manager.dart';

class SmsService {
  static const _smsChannel = MethodChannel('com.shetorque.hub/sms');
  static const String emergencyContact = "+916360826795"; // Hardcoded contact

  // Used by CRASH SOS
  static Future<void> sendCrashAlert(Position position) async {
    String mapLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
    String message = "EMERGENCY: SheTorque Hub detected a crash! Rider is unresponsive. Location: $mapLink";

    await _smsChannel.invokeMethod('sendSms', {
      'phone': emergencyContact,
      'message': message,
    });
  }

  // Used by SILENT SOS — SMS #1
  static Future<void> sendStealthAlert(Position position) async {
    String name = await SosSessionManager.getRiderName() ?? "the rider";
    String mapLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String time = _formatTime(DateTime.now());
    String date = _formatDate(DateTime.now());

    String message = "[SheTorque] SILENT ALERT\n"
        "$name may need help.\n\n"
        "Location: $mapLink\n"
        "Time: $time, $date\n\n"
        "DO NOT CALL. Send an SMS or contact authorities.\n"
        "Location will update every 5 minutes.";

    await _smsChannel.invokeMethod('sendSms', {
      'phone': emergencyContact,
      'message': message,
    });
  }

  // Used by SILENT SOS — update SMS
  static Future<void> sendLocationUpdate(Position position, int updateCount) async {
    String name = await SosSessionManager.getRiderName() ?? "the rider";
    String mapLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String time = _formatTime(DateTime.now());

    String message = "[SheTorque] LOCATION UPDATE (#$updateCount)\n"
        "$name — updated location:\n\n"
        "$mapLink\n"
        "Time: $time\n\n"
        "Alert still active.";

    await _smsChannel.invokeMethod('sendSms', {
      'phone': emergencyContact,
      'message': message,
    });
  }

  // Used by SILENT SOS — resolution
  static Future<void> sendSafeConfirmation() async {
    String name = await SosSessionManager.getRiderName() ?? "the rider";
    String time = _formatTime(DateTime.now());

    String message = "[SheTorque] ALL CLEAR\n"
        "$name has confirmed she is safe.\n\n"
        "Time: $time\n"
        "Location tracking stopped.";

    await _smsChannel.invokeMethod('sendSms', {
      'phone': emergencyContact,
      'message': message,
    });
  }

  static String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  static String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }
}
