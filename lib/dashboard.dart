import 'package:flutter/material.dart';

// ============================================================================
// STANDALONE RUNNER
// Run independently with: flutter run -t lib/dashboard.dart
// ============================================================================
void main() {
  runApp(const SheTorqueDashboardApp());
}

// ============================================================================
// APP THEME & DESIGN CONSTANTS
// ============================================================================
class SheTorqueTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);

  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color secondaryPink = Color(0xFFFF2A6D);
  static const Color accentPurple = Color(0xFF9D4EDD);

  static const Color warningAmber = Color(0xFFFFB300);
  static const Color successGreen = Color(0xFF00E676);
  static const Color dangerRed = Color(0xFFFF1744);

  static const Color textWhite = Color(0xFFF0F6FC);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: secondaryPink,
        surface: surface,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textWhite),
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: primaryCyan, fontSize: 14),
        prefixIconColor: primaryCyan,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryCyan, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          elevation: 4,
          shadowColor: primaryCyan.withOpacity(0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textWhite,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ============================================================================
// APPLICATION ROOT
// ============================================================================
class SheTorqueDashboardApp extends StatelessWidget {
  const SheTorqueDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SheTorque Hub',
      debugShowCheckedModeBanner: false,
      theme: SheTorqueTheme.darkTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/garage': (context) => const DigitalGarageDashboard(),
      },
    );
  }
}

// ============================================================================
// DATA MODELS (MOCK DATA HOLDERS)
// ============================================================================
class RiderProfile {
  String name;
  String email;
  String phone;
  String emergencyContactName;
  String emergencyContactPhone;
  String bloodGroup;
  String address;

  RiderProfile({
    this.name = 'Ananya Sharma',
    this.email = 'ananya.rider@shetorque.io',
    this.phone = '+91 98765 43210',
    this.emergencyContactName = 'Sneha Sharma (Sister)',
    this.emergencyContactPhone = '+91 63608 26795',
    this.bloodGroup = 'O+',
    this.address = '42, Lavender Bough, Indiranagar, Bengaluru, KA',
  });
}

class BikeInfo {
  String brand;
  String model;
  String regNumber;
  String year;
  String fuelType;
  String odometer;
  String nextService;

  BikeInfo({
    this.brand = 'Royal Enfield',
    this.model = 'Hunter 350 Dapper',
    this.regNumber = 'KA 05 EQ 8824',
    this.year = '2024',
    this.fuelType = 'Petrol (E20)',
    this.odometer = '4,820 km',
    this.nextService = 'In 180 km',
  });
}

// Global active session for mock preview
RiderProfile activeRider = RiderProfile();
BikeInfo activeBike = BikeInfo();

// ============================================================================
// 1. LOGIN SCREEN
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '+91 98765 43210');
  final _passwordController = TextEditingController(text: '••••••••');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DigitalGarageDashboard()),
    );
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
                          colors: [SheTorqueTheme.primaryCyan, SheTorqueTheme.secondaryPink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SheTorqueTheme.primaryCyan.withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.two_wheeler_rounded, size: 48, color: Colors.black),
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

              const SizedBox(height: 48),

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
                      'Enter your registered mobile or email to access your Digital Garage',
                      style: TextStyle(fontSize: 13, color: SheTorqueTheme.textMuted),
                    ),
                    const SizedBox(height: 22),

                    // Phone / Email Input
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number or Email',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password / Passcode',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Forgot Password Row
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password reset link sent to registered phone.')),
                          );
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: SheTorqueTheme.primaryCyan, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _onLoginPressed,
                      child: const Row(
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

              const SizedBox(height: 24),

              // Quick Login Demo Button
              OutlinedButton.icon(
                onPressed: _onLoginPressed,
                icon: const Icon(Icons.bolt_rounded, color: SheTorqueTheme.warningAmber),
                label: const Text('Quick Demo Access (One Tap)'),
              ),

              const SizedBox(height: 20),

              // Sign Up Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "New to SheTorque? ",
                    style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 14),
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
                        color: SheTorqueTheme.secondaryPink,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
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

// ============================================================================
// 2. SIGN UP / PERSONAL DETAILS SCREEN
// ============================================================================
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Ananya Sharma');
  final _emailController = TextEditingController(text: 'ananya.rider@shetorque.io');
  final _phoneController = TextEditingController(text: '+91 98765 43210');
  final _emergencyNameController = TextEditingController(text: 'Sneha Sharma (Sister)');
  final _emergencyPhoneController = TextEditingController(text: '+91 63608 26795');
  final _addressController = TextEditingController(text: '42, Lavender Bough, Indiranagar, Bengaluru');

  String _selectedBloodGroup = 'O+';
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onContinue() {
    activeRider = RiderProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      emergencyContactName: _emergencyNameController.text.trim(),
      emergencyContactPhone: _emergencyPhoneController.text.trim(),
      bloodGroup: _selectedBloodGroup,
      address: _addressController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(phoneNumber: activeRider.phone),
      ),
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
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),

              const SizedBox(height: 28),

              // Section: Emergency Contact & Medical Info (Critical for SheTorque Safety)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.dangerRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SheTorqueTheme.dangerRed.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SheTorqueTheme.dangerRed.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emergency_rounded, color: SheTorqueTheme.dangerRed, size: 20),
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
                                style: TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted),
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
                        helperText: 'Will receive emergency crash SMS and GPS coordinates',
                        helperStyle: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 11),
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
                              color: isSelected ? Colors.black : SheTorqueTheme.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: SheTorqueTheme.secondaryPink,
                          backgroundColor: SheTorqueTheme.surfaceLight,
                          side: BorderSide(
                            color: isSelected ? SheTorqueTheme.secondaryPink : SheTorqueTheme.border,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedBloodGroup = bg);
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
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.home_outlined),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _onContinue,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VERIFY PHONE NUMBER'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String number, String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? SheTorqueTheme.primaryCyan : SheTorqueTheme.surfaceLight,
            border: Border.all(
              color: isActive ? SheTorqueTheme.primaryCyan : SheTorqueTheme.border,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isActive ? Colors.black : SheTorqueTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? SheTorqueTheme.textWhite : SheTorqueTheme.textMuted,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: SheTorqueTheme.border,
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
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
}

// ============================================================================
// 3. MOCK OTP VERIFICATION SCREEN
// ============================================================================
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BikeDetailsScreen()),
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
                    color: SheTorqueTheme.primaryCyan.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: SheTorqueTheme.primaryCyan.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.sms_rounded, size: 40, color: SheTorqueTheme.primaryCyan),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Verify Your Number',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'We sent a 4-digit verification code to\n${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: SheTorqueTheme.textMuted, height: 1.4),
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
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SheTorqueTheme.primaryCyan),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: SheTorqueTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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

              // Mock helper banner
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SheTorqueTheme.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: SheTorqueTheme.primaryCyan),
                      SizedBox(width: 8),
                      Text(
                        'Mock Verification • Demo Code 1234 Applied',
                        style: TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _verifyOtp,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VERIFY & ADD BIKE DETAILS'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('A fresh mock OTP has been sent: 1234')),
                    );
                  },
                  child: const Text('Resend Code (0:45)', style: TextStyle(color: SheTorqueTheme.textMuted)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. BIKE DETAILS SCREEN
// ============================================================================
class BikeDetailsScreen extends StatefulWidget {
  const BikeDetailsScreen({super.key});

  @override
  State<BikeDetailsScreen> createState() => _BikeDetailsScreenState();
}

class _BikeDetailsScreenState extends State<BikeDetailsScreen> {
  final _modelController = TextEditingController(text: 'Hunter 350 Dapper');
  final _regController = TextEditingController(text: 'KA 05 EQ 8824');
  final _odoController = TextEditingController(text: '4,820 km');

  String _selectedBrand = 'Royal Enfield';
  final List<String> _brands = [
    'Royal Enfield',
    'Yamaha',
    'KTM',
    'TVS',
    'Honda',
    'Kawasaki',
    'Ather',
    'Ola Electric',
  ];

  String _selectedYear = '2024';
  final List<String> _years = ['2025', '2024', '2023', '2022', '2021', '2020'];

  String _selectedFuelType = 'Petrol (E20)';
  final List<String> _fuelTypes = ['Petrol (E20)', 'Electric (EV)', 'Hybrid'];

  @override
  void dispose() {
    _modelController.dispose();
    _regController.dispose();
    _odoController.dispose();
    super.dispose();
  }

  void _onSaveBike() {
    activeBike = BikeInfo(
      brand: _selectedBrand,
      model: _modelController.text.trim(),
      regNumber: _regController.text.trim().toUpperCase(),
      year: _selectedYear,
      fuelType: _selectedFuelType,
      odometer: _odoController.text.trim(),
      nextService: 'In 180 km',
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DigitalGarageDashboard()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motorcycle Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Progress Header
            Row(
              children: [
                _buildIndicator('1', 'Personal', true),
                _buildDivider(),
                _buildIndicator('2', 'Verify', true),
                _buildDivider(),
                _buildIndicator('3', 'Bike', true),
              ],
            ),
            const SizedBox(height: 24),

            // Hero Motorcycle Icon Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SheTorqueTheme.primaryCyan.withOpacity(0.15),
                    SheTorqueTheme.secondaryPink.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SheTorqueTheme.primaryCyan.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.two_wheeler, size: 54, color: SheTorqueTheme.primaryCyan),
                  SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Your Machine',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Connect your bike to the SheTorque Digital Garage for live OBD diagnostics & crash safety.',
                          style: TextStyle(fontSize: 12.5, color: SheTorqueTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Motorcycle Brand Dropdown
            DropdownButtonFormField<String>(
              value: _selectedBrand,
              dropdownColor: SheTorqueTheme.surface,
              decoration: const InputDecoration(
                labelText: 'Motorcycle Brand / Make',
                prefixIcon: Icon(Icons.stars_rounded),
              ),
              items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedBrand = val);
              },
            ),

            const SizedBox(height: 14),

            // Bike Model
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model & Edition',
                prefixIcon: Icon(Icons.motorcycle_rounded),
                hintText: 'e.g. Hunter 350, Duke 250, Aerox 155',
              ),
            ),

            const SizedBox(height: 14),

            // Registration Plate Number
            TextFormField(
              controller: _regController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Registration Number',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
                hintText: 'e.g. KA 05 EQ 8824',
              ),
            ),

            const SizedBox(height: 14),

            // Row: Year & Fuel Type
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    dropdownColor: SheTorqueTheme.surface,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedYear = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFuelType,
                    dropdownColor: SheTorqueTheme.surface,
                    decoration: const InputDecoration(
                      labelText: 'Powertrain',
                      prefixIcon: Icon(Icons.local_gas_station_rounded),
                    ),
                    items: _fuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFuelType = val);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Current Odometer Reading
            TextFormField(
              controller: _odoController,
              decoration: const InputDecoration(
                labelText: 'Current Odometer',
                prefixIcon: Icon(Icons.speed_rounded),
                hintText: 'e.g. 4,820 km',
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _onSaveBike,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('LAUNCH DIGITAL GARAGE'),
                  SizedBox(width: 8),
                  Icon(Icons.dashboard_rounded, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(String num, String label, bool active) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: SheTorqueTheme.primaryCyan,
          ),
          child: Center(
            child: Text(num, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: SheTorqueTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDivider() {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: SheTorqueTheme.primaryCyan,
      ),
    );
  }
}

// ============================================================================
// 5. DIGITAL GARAGE DASHBOARD (MAIN SCREEN)
// ============================================================================
class DigitalGarageDashboard extends StatefulWidget {
  const DigitalGarageDashboard({super.key});

  @override
  State<DigitalGarageDashboard> createState() => _DigitalGarageDashboardState();
}

class _DigitalGarageDashboardState extends State<DigitalGarageDashboard> {
  int _currentTabIndex = 0;

  // Mock telemetry data required by prompt
  final double mockFuelPercentage = 72.0;
  final double mockEngineTemperature = 86.0;
  final double mockBatteryVoltage = 12.6;

  void _triggerEmergencySosModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SheTorqueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.dangerRed.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: SheTorqueTheme.dangerRed, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMERGENCY SOS ARMED',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: SheTorqueTheme.dangerRed,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Sensor Fusion & Native SMS Pipeline',
                          style: TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SheTorqueTheme.border),
                ),
                child: Column(
                  children: [
                    _buildSosDetailRow(
                      icon: Icons.person_pin_rounded,
                      label: 'Emergency Recipient',
                      value: activeRider.emergencyContactName,
                    ),
                    const Divider(color: SheTorqueTheme.border, height: 18),
                    _buildSosDetailRow(
                      icon: Icons.phone_in_talk_rounded,
                      label: 'Emergency Line',
                      value: activeRider.emergencyContactPhone,
                    ),
                    const Divider(color: SheTorqueTheme.border, height: 18),
                    _buildSosDetailRow(
                      icon: Icons.bloodtype_rounded,
                      label: 'Rider Blood Group',
                      value: activeRider.bloodGroup,
                    ),
                    const Divider(color: SheTorqueTheme.border, height: 18),
                    _buildSosDetailRow(
                      icon: Icons.location_on_rounded,
                      label: 'Auto GPS Dispatch',
                      value: 'High-Precision Geolocator Armed',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Note: In real driving conditions, crashes exceeding 25.0 G trigger an instant siren & 90s countdown handled by the core SensorFusionHub.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: SheTorqueTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SheTorqueTheme.dangerRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: SheTorqueTheme.dangerRed,
                      content: Text('Test SOS dispatched to ${activeRider.emergencyContactPhone} (Simulated).'),
                    ),
                  );
                },
                child: const Text('DISPATCH TEST SOS ALERT'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('DISMISS'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSosDetailRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SheTorqueTheme.primaryCyan),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: SheTorqueTheme.textMuted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SheTorqueTheme.primaryCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.two_wheeler, color: SheTorqueTheme.primaryCyan, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('SHETORQUE HUB'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SheTorqueTheme.successGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SheTorqueTheme.successGreen.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 4, backgroundColor: SheTorqueTheme.successGreen),
                SizedBox(width: 6),
                Text(
                  'OBD-II LIVE',
                  style: TextStyle(color: SheTorqueTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildCurrentTab(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: SheTorqueTheme.surface,
          border: Border(top: BorderSide(color: SheTorqueTheme.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: SheTorqueTheme.primaryCyan,
          unselectedItemColor: SheTorqueTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.garage_rounded),
              activeIcon: Icon(Icons.garage_rounded, color: SheTorqueTheme.primaryCyan),
              label: 'Garage',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics_rounded, color: SheTorqueTheme.primaryCyan),
              label: 'Diagnostics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.route_outlined),
              activeIcon: Icon(Icons.route_rounded, color: SheTorqueTheme.primaryCyan),
              label: 'Rides',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield_rounded, color: SheTorqueTheme.primaryCyan),
              label: 'Safety Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        return _buildGarageTab();
      case 1:
        return _buildDiagnosticsTab();
      case 2:
        return _buildRidesTab();
      case 3:
        return _buildSafetyProfileTab();
      default:
        return _buildGarageTab();
    }
  }

  // ==========================================================================
  // TAB 0: DIGITAL GARAGE (MAIN TELEMETRY & DIAGNOSTICS)
  // ==========================================================================
  Widget _buildGarageTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      children: [
        // Rider Greeting
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${activeRider.name.split(' ').first} 👋',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite),
                ),
                const SizedBox(height: 2),
                const Text(
                  'All systems nominal • IMU Active',
                  style: TextStyle(fontSize: 13, color: SheTorqueTheme.textMuted),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: SheTorqueTheme.border),
              ),
              child: const Icon(Icons.notifications_none_rounded, color: SheTorqueTheme.textWhite, size: 22),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Bike Showcase Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F2937), Color(0xFF111827)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: SheTorqueTheme.primaryCyan.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: SheTorqueTheme.primaryCyan.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SheTorqueTheme.primaryCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            activeBike.brand.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: SheTorqueTheme.primaryCyan,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activeBike.model,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: SheTorqueTheme.textWhite,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                activeBike.regNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${activeBike.year}',
                              style: const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SheTorqueTheme.border),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, size: 40, color: SheTorqueTheme.primaryCyan),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: SheTorqueTheme.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickStat(label: 'Odometer', value: activeBike.odometer),
                  _buildQuickStat(label: 'Powertrain', value: activeBike.fuelType),
                  _buildQuickStat(label: 'Service Due', value: activeBike.nextService, isAccent: true),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // PROMINENT EMERGENCY SOS UI BUTTON
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _triggerEmergencySosModal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SheTorqueTheme.dangerRed.withOpacity(0.25),
                  const Color(0xFF3B0B14),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SheTorqueTheme.dangerRed.withOpacity(0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: SheTorqueTheme.dangerRed.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.dangerRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SheTorqueTheme.dangerRed.withOpacity(0.6),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.sos_rounded, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'EMERGENCY SOS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.shield_rounded, color: SheTorqueTheme.dangerRed, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to review emergency line (${activeRider.emergencyContactPhone})',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // SECTION: VEHICLE DIAGNOSTICS (3 Required Mock Metrics)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Live Diagnostics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SheTorqueTheme.border),
              ),
              child: const Text('OBD-II SYNCED', style: TextStyle(fontSize: 10.5, color: SheTorqueTheme.primaryCyan)),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 3 Diagnostic Cards
        Row(
          children: [
            // Fuel Card (72%)
            Expanded(
              child: _buildDiagnosticCard(
                icon: Icons.local_gas_station_rounded,
                iconColor: SheTorqueTheme.primaryCyan,
                title: 'Fuel Level',
                value: '${mockFuelPercentage.toInt()}%',
                subtitle: 'Range ~280 km',
                progress: mockFuelPercentage / 100,
                progressColor: SheTorqueTheme.primaryCyan,
              ),
            ),
            const SizedBox(width: 12),
            // Engine Temperature (86°C)
            Expanded(
              child: _buildDiagnosticCard(
                icon: Icons.thermostat_rounded,
                iconColor: SheTorqueTheme.warningAmber,
                title: 'Engine Temp',
                value: '${mockEngineTemperature.toInt()}°C',
                subtitle: 'Optimal (75-95°C)',
                progress: mockEngineTemperature / 120,
                progressColor: SheTorqueTheme.warningAmber,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            // Battery Voltage (12.6V)
            Expanded(
              child: _buildDiagnosticCard(
                icon: Icons.battery_charging_full_rounded,
                iconColor: SheTorqueTheme.successGreen,
                title: 'Battery Voltage',
                value: '${mockBatteryVoltage}V',
                subtitle: 'Healthy State',
                progress: 0.9,
                progressColor: SheTorqueTheme.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            // Lean & IMU Sensor Fusion Indicator
            Expanded(
              child: _buildDiagnosticCard(
                icon: Icons.sensors_rounded,
                iconColor: SheTorqueTheme.secondaryPink,
                title: 'Crash IMU Sensor',
                value: 'ARMED',
                subtitle: 'Threshold: 25.0 G',
                progress: 1.0,
                progressColor: SheTorqueTheme.secondaryPink,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // SECTION: VEHICLE HEALTH WARNINGS & ALERTS
        const Text(
          'Vehicle Health & Alerts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite),
        ),
        const SizedBox(height: 12),

        _buildHealthWarningTile(
          icon: Icons.build_circle_rounded,
          iconColor: SheTorqueTheme.warningAmber,
          title: 'Chain Lubrication Recommended',
          description: 'Maintenance interval reached. Lube clean scheduled in 80 km.',
          severity: 'Action Recommended',
        ),
        const SizedBox(height: 10),
        _buildHealthWarningTile(
          icon: Icons.disc_full_rounded,
          iconColor: SheTorqueTheme.primaryCyan,
          title: 'Brake Pad Thickness: 78%',
          description: 'Front and rear brake pad wear within optimal safety bounds.',
          severity: 'Good Condition',
        ),
        const SizedBox(height: 10),
        _buildHealthWarningTile(
          icon: Icons.tire_repair_rounded,
          iconColor: SheTorqueTheme.successGreen,
          title: 'Tire Pressure: Front 29 PSI / Rear 33 PSI',
          description: 'Both tires calibrated to factory cold specifications.',
          severity: 'Optimal',
        ),

        const SizedBox(height: 28),
      ],
    );
  }

  // ==========================================================================
  // TAB 1: DIAGNOSTICS DETAILED VIEW
  // ==========================================================================
  Widget _buildDiagnosticsTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'OBD-II Telemetry Breakdown',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite),
        ),
        const SizedBox(height: 4),
        const Text('Real-time ECU parameter values & diagnostic trouble codes (DTC)',
            style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 20),

        _buildDiagnosticDetailRow('Fuel Tank Capacity', '13.5 Liters (9.7L remaining)'),
        _buildDiagnosticDetailRow('Fuel Level Metric', '72% [Mock Sensor Stream]'),
        _buildDiagnosticDetailRow('Engine Coolant / Oil Temp', '86°C [Normal Operating Temp]'),
        _buildDiagnosticDetailRow('Electrical System / Alternator', '12.6V [Stable]'),
        _buildDiagnosticDetailRow('ECU Error Codes', 'None (0 DTCs detected)'),
        _buildDiagnosticDetailRow('IMU Accelerometer Status', 'Streaming via sensors_plus'),
        _buildDiagnosticDetailRow('Crash Threshold Constant', '25.0 G (Trigger Limit)'),
        _buildDiagnosticDetailRow('Native SMS Emergency Route', '+91 63608 26795 (Active)'),

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SheTorqueTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SheTorqueTheme.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: SheTorqueTheme.successGreen, size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'No diagnostic faults found. Your motorcycle is in optimal riding condition.',
                  style: TextStyle(color: SheTorqueTheme.textWhite, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TAB 2: RIDES LOG
  // ==========================================================================
  Widget _buildRidesTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Recent Rides & Telemetry',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite),
        ),
        const SizedBox(height: 4),
        const Text('Tracked ride distances, durations, and safety logs',
            style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 20),

        _buildRideHistoryCard(
          title: 'Nandi Hills Sunrise Ride',
          date: 'Yesterday, 05:30 AM',
          distance: '118.4 km',
          duration: '2h 45m',
          safetyScore: '98/100',
        ),
        const SizedBox(height: 12),
        _buildRideHistoryCard(
          title: 'City Commute - Outer Ring Rd',
          date: 'Sep 02, 2026',
          distance: '24.2 km',
          duration: '48m',
          safetyScore: '94/100',
        ),
        const SizedBox(height: 12),
        _buildRideHistoryCard(
          title: 'Weekend Ghats Exploration',
          date: 'Aug 28, 2026',
          distance: '264.0 km',
          duration: '5h 12m',
          safetyScore: '96/100',
        ),
      ],
    );
  }

  // ==========================================================================
  // TAB 3: SAFETY PROFILE
  // ==========================================================================
  Widget _buildSafetyProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Emergency & Rider Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite),
        ),
        const SizedBox(height: 4),
        const Text('Information transmitted in automated SOS crash dispatches',
            style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 20),

        // Emergency Card Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A080C), Color(0xFF161B22)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SheTorqueTheme.dangerRed.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_services_rounded, color: SheTorqueTheme.dangerRed, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Emergency Medical ID',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.dangerRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Blood: ${activeRider.bloodGroup}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              _buildProfileItem('Rider Name', activeRider.name),
              _buildProfileItem('Registered Phone', activeRider.phone),
              _buildProfileItem('Emergency Contact', activeRider.emergencyContactName),
              _buildProfileItem('Emergency Contact Phone', activeRider.emergencyContactPhone),
              _buildProfileItem('Residential Address', activeRider.address),
            ],
          ),
        ),

        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: _triggerEmergencySosModal,
          style: ElevatedButton.styleFrom(backgroundColor: SheTorqueTheme.dangerRed, foregroundColor: Colors.white),
          icon: const Icon(Icons.emergency_rounded),
          label: const Text('TEST EMERGENCY SOS FLOW'),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          icon: const Icon(Icons.logout_rounded, color: SheTorqueTheme.secondaryPink),
          label: const Text('Log Out / Switch Rider', style: TextStyle(color: SheTorqueTheme.secondaryPink)),
        ),
      ],
    );
  }

  // ==========================================================================
  // HELPER WIDGETS
  // ==========================================================================
  Widget _buildQuickStat({required String label, required String value, bool isAccent = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isAccent ? SheTorqueTheme.warningAmber : SheTorqueTheme.textWhite,
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required double progress,
    required Color progressColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SheTorqueTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: SheTorqueTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: SheTorqueTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthWarningTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String severity,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SheTorqueTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: SheTorqueTheme.textWhite,
                        ),
                      ),
                    ),
                    Text(
                      severity,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: iconColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SheTorqueTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: SheTorqueTheme.textWhite, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRideHistoryCard({
    required String title,
    required String date,
    required String distance,
    required String duration,
    required String safetyScore,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SheTorqueTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SheTorqueTheme.textWhite)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SheTorqueTheme.successGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Safety $safetyScore',
                    style: const TextStyle(fontSize: 11, color: SheTorqueTheme.successGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          const Divider(color: SheTorqueTheme.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten_rounded, size: 16, color: SheTorqueTheme.primaryCyan),
                  const SizedBox(width: 6),
                  Text(distance, style: const TextStyle(color: SheTorqueTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: SheTorqueTheme.primaryCyan),
                  const SizedBox(width: 6),
                  Text(duration, style: const TextStyle(color: SheTorqueTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: SheTorqueTheme.successGreen),
                  SizedBox(width: 6),
                  Text('Zero Incidents', style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: SheTorqueTheme.textWhite, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
