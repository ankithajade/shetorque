import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_siren_service.dart';
import '../services/sos_notification_service.dart';
import '../services/sos_session_manager.dart';
import '../services/sms_service.dart';
import '../services/supabase_auth_service.dart';

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
  bool _isVerifying = false;

  Future<void> _verifyPin() async {
    if (_isLocked || _isVerifying) return;

    final String entered = _pinController.text.trim();
    if (entered.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 4-digit PIN.')),
      );
      return;
    }

    setState(() => _isVerifying = true);
    final isValid = await SupabaseAuthService.instance.verifySafetyPin(entered);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (isValid) {
      await _confirmSafe();
    } else {
      setState(() {
        _attempts++;
        if (_attempts >= 3) {
          _isLocked = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLocked
              ? 'Account locked after 3 failed PIN attempts.'
              : 'Incorrect PIN (${3 - _attempts} attempts remaining)'),
        ),
      );
    }
  }

  Future<void> _confirmSafe() async {
    // 1. Stop siren if it was playing during crash detection
    try {
      EmergencySirenService.instance.stopSiren();
    } catch (_) {}

    // 2. Dismiss persistent ongoing notification
    try {
      await SosNotificationService().cancelNotification();
    } catch (_) {}

    // 3. Send safe confirmation SMS (or simulate in demo mode)
    try {
      final isDemo = await SmsService.isDemoModeEnabled();
      await SmsService.sendSafeConfirmation(isDemoMode: isDemo);
    } catch (_) {}

    // 4. Mark session ended in SosSessionManager (flips notifier to false)
    await SosSessionManager.endSession();

    // 5. Notify caller
    widget.onSafeConfirmed();
  }

  Future<void> _callEmergencyContact() async {
    final contact = await SmsService.resolveEmergencyContact();
    if (contact != null && contact.isNotEmpty) {
      final Uri url = Uri.parse('tel:$contact');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No emergency contact configured.')),
        );
      }
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
