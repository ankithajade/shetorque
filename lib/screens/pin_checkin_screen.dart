import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sos_session_manager.dart';
import '../services/sms_service.dart';

class PinCheckinScreen extends StatefulWidget {
  final VoidCallback onSafeConfirmed;
  const PinCheckinScreen({super.key, required this.onSafeConfirmed});

  @override
  State<PinCheckinScreen> createState() => _PinCheckinScreenState();
}

class _PinCheckinScreenState extends State<PinCheckinScreen> {
  final _pinController = TextEditingController();
  int _attempts = 0;
  bool _isLocked = false;
  String? _correctPin;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    _correctPin = await SosSessionManager.getSafetyPin();
  }

  Future<void> _verifyPin() async {
    if (_isLocked) return;

    String entered = _pinController.text.trim();
    if (_correctPin == null) {
      if (entered.length == 4) {
         _confirmSafe();
      }
      return;
    }

    if (entered == _correctPin) {
      _confirmSafe();
    } else {
      setState(() {
        _attempts++;
        if (_attempts >= 3) {
          _isLocked = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  Future<void> _confirmSafe() async {
    await SmsService.sendSafeConfirmation();
    await SosSessionManager.endSession();
    widget.onSafeConfirmed();
  }

  Future<void> _callEmergencyContact() async {
    final Uri url = Uri.parse('tel:${SmsService.emergencyContact}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔴 SOS Session Ended', style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text('An alert was sent. Your emergency contact was notified.'),
                  const SizedBox(height: 20),
                  const Text('Enter your 4-digit safety PIN to confirm you are okay and dismiss this alert.', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pinController,
                    decoration: const InputDecoration(hintText: '_ _ _ _', counterText: ''),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, letterSpacing: 24),
                    enabled: !_isLocked,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLocked ? null : _verifyPin,
                    child: const Text('CONFIRM SAFE'),
                  ),
                  const SizedBox(height: 40),
                  const Divider(color: Colors.white54),
                  const SizedBox(height: 20),
                  const Text("Can't remember your PIN?"),
                  TextButton(
                    onPressed: _callEmergencyContact,
                    child: const Text('Call Emergency Contact', style: TextStyle(color: Colors.blueAccent)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
