import 'package:flutter/material.dart';
import '../services/sos_session_manager.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty || _pinController.text.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and a 4-digit PIN')),
      );
      return;
    }
    
    await SosSessionManager.setRiderName(_nameController.text.trim());
    await SosSessionManager.setSafetyPin(_pinController.text.trim());
    await SosSessionManager.markOnboardingComplete();
    
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Stealth SOS')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to SheTorque', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Rider Name'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(labelText: '4-Digit Safety PIN'),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
