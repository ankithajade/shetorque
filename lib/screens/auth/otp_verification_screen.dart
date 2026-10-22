import 'package:flutter/material.dart';
import '../../theme/she_torque_theme.dart';
import '../../models/rider_profile.dart';
import 'bike_details_screen.dart';

/// Verification screen for rider contact info, preserving Nisarga's
/// original visual layout and 4-digit input box design.
class OtpVerificationScreen extends StatefulWidget {
  final RiderProfile rider;
  final String password;

  const OtpVerificationScreen({
    super.key,
    required this.rider,
    required this.password,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Default mock PIN for frictionless testing
    _controllers[0].text = '1';
    _controllers[1].text = '2';
    _controllers[2].text = '3';
    _controllers[3].text = '4';
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 4-digit code.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BikeDetailsScreen(
          rider: widget.rider,
          password: widget.password,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            SheTorqueTheme.primaryCyan.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.sms_rounded,
                      size: 40, color: SheTorqueTheme.primaryCyan),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Verify Your Number',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.textWhite,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'We sent a 4-digit verification code to\n${widget.rider.phone}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: SheTorqueTheme.textMuted,
                      height: 1.4),
                ),
              ),
              const SizedBox(height: 36),

              // 4 OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 60,
                    height: 64,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.primaryCyan,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: SheTorqueTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Helper message
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SheTorqueTheme.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_clock_rounded,
                          size: 14, color: SheTorqueTheme.warningAmber),
                      SizedBox(width: 6),
                      Text(
                        'Demo Verification • Code 1234 Applied',
                        style: TextStyle(
                            fontSize: 12, color: SheTorqueTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Resend Code Link
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'A fresh mock OTP has been sent: 1234'),
                      ),
                    );
                  },
                  child: const Text(
                    "Didn't receive code? Resend Code",
                    style: TextStyle(
                      color: SheTorqueTheme.primaryCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Verify Button
              ElevatedButton(
                onPressed: _verifyOtp,
                child: const Text('VERIFY & PROCEED'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
