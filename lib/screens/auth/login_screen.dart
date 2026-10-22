import 'package:flutter/material.dart';
import '../../theme/she_torque_theme.dart';
import '../../services/local_auth_service.dart';
import '../dashboard/main_dashboard_screen.dart';
import 'signup_screen.dart';

/// Rider login screen with SheTorque brand styling and credential verification.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = LocalAuthService();
  final _emailController =
      TextEditingController(text: LocalAuthService.demoEmail);
  final _passwordController =
      TextEditingController(text: LocalAuthService.demoPassword);
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService.ensureDemoAccountSeeded();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: SheTorqueTheme.dangerRed,
          content: Text(result.message),
        ),
      );
    }
  }

  void _fillDemoCredentials() {
    setState(() {
      _emailController.text = LocalAuthService.demoEmail;
      _passwordController.text = LocalAuthService.demoPassword;
    });
    _onLoginPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),

              // SheTorque Branding Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            SheTorqueTheme.primaryCyan,
                            SheTorqueTheme.secondaryPink,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                SheTorqueTheme.primaryCyan.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.two_wheeler_rounded,
                            size: 48, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SHETORQUE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: SheTorqueTheme.secondaryPink,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Empowering Women Riders • Smart Telematics',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: SheTorqueTheme.textMuted,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Login Form Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SheTorqueTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rider Sign In',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your registered email and password to access your Digital Garage',
                      style: TextStyle(
                          fontSize: 13, color: SheTorqueTheme.textMuted),
                    ),
                    const SizedBox(height: 22),

                    // Email Input
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Registered Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Demo credentials hint
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SheTorqueTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: SheTorqueTheme.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: SheTorqueTheme.primaryCyan),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Demo Account: ananya.rider@shetorque.io / password123',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: SheTorqueTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _onLoginPressed,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('ENTER DIGITAL GARAGE'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Login Demo Button (validates pre-seeded demo account)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _fillDemoCredentials,
                icon: const Icon(Icons.bolt_rounded,
                    color: SheTorqueTheme.warningAmber),
                label: const Text('Login as Demo Rider (Ananya)'),
              ),

              const SizedBox(height: 20),

              // Sign Up Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "New to SheTorque? ",
                    style: TextStyle(
                        color: SheTorqueTheme.textMuted, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: SheTorqueTheme.primaryCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
