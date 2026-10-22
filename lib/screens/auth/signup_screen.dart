import 'package:flutter/material.dart';
import '../../theme/she_torque_theme.dart';
import '../../models/rider_profile.dart';
import 'otp_verification_screen.dart';

/// Rider registration screen capturing profile, emergency contact,
/// and medical details.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Ananya Sharma');
  final _emailController =
      TextEditingController(text: 'ananya.rider@shetorque.io');
  final _passwordController = TextEditingController(text: 'password123');
  final _phoneController = TextEditingController(text: '+91 98765 43210');
  final _emergencyNameController =
      TextEditingController(text: 'Sneha Sharma (Sister)');
  final _emergencyPhoneController =
      TextEditingController(text: '+91 63608 26795');
  final _addressController =
      TextEditingController(text: '42, Lavender Bough, Indiranagar, Bengaluru');

  bool _obscurePassword = true;
  String _selectedBloodGroup = 'O+';
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    final newRider = RiderProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      phone: _phoneController.text.trim(),
      emergencyContactName: _emergencyNameController.text.trim(),
      emergencyContactPhone: _emergencyPhoneController.text.trim(),
      bloodGroup: _selectedBloodGroup,
      address: _addressController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          rider: newRider,
          password: _passwordController.text,
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String number, String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isActive ? SheTorqueTheme.primaryCyan : SheTorqueTheme.surfaceLight,
            border: Border.all(
              color: isActive ? SheTorqueTheme.primaryCyan : SheTorqueTheme.border,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.black : SheTorqueTheme.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? SheTorqueTheme.textWhite : SheTorqueTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Expanded(
      child: Container(
        height: 1,
        color: SheTorqueTheme.border,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: SheTorqueTheme.textWhite,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Progress Indicator
              Row(
                children: [
                  _buildStepIndicator('1', 'Personal', true),
                  _buildStepDivider(),
                  _buildStepIndicator('2', 'Verify', false),
                  _buildStepDivider(),
                  _buildStepIndicator('3', 'Bike', false),
                ],
              ),
              const SizedBox(height: 24),

              // Section: Personal Details
              _buildSectionHeader(
                icon: Icons.person_outline_rounded,
                title: 'Personal Details',
                color: SheTorqueTheme.primaryCyan,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Rider Full Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password (minimum 6 characters)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),

              const SizedBox(height: 28),

              // Section: Emergency Contact & Medical Info
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.dangerRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: SheTorqueTheme.dangerRed.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SheTorqueTheme.dangerRed.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emergency_rounded,
                              color: SheTorqueTheme.dangerRed, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Contact & Medical',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: SheTorqueTheme.textWhite,
                                ),
                              ),
                              Text(
                                'Used by the automated crash detection system',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: SheTorqueTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emergencyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Contact Name & Relation',
                        prefixIcon: Icon(Icons.people_alt_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emergencyPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Contact Number',
                        prefixIcon: Icon(Icons.phone_in_talk_rounded),
                        helperText:
                            'Will receive emergency crash SMS and GPS coordinates',
                        helperStyle: TextStyle(
                            color: SheTorqueTheme.textMuted, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Blood Group Picker
                    const Text(
                      'Blood Group',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SheTorqueTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _bloodGroups.map((bg) {
                        final isSelected = _selectedBloodGroup == bg;
                        return ChoiceChip(
                          label: Text(
                            bg,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : SheTorqueTheme.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: SheTorqueTheme.secondaryPink,
                          backgroundColor: SheTorqueTheme.surfaceLight,
                          side: BorderSide(
                            color: isSelected
                                ? SheTorqueTheme.secondaryPink
                                : SheTorqueTheme.border,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedBloodGroup = bg);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section: Address
              _buildSectionHeader(
                icon: Icons.location_on_outlined,
                title: 'Emergency Residential Address',
                color: SheTorqueTheme.primaryCyan,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Home / Permanent Address',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),

              const SizedBox(height: 32),

              // Continue Button
              ElevatedButton(
                onPressed: _onContinue,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('CONTINUE TO VERIFICATION'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
