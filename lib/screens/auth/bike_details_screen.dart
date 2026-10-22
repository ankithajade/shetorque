import 'package:flutter/material.dart';
import '../../theme/she_torque_theme.dart';
import '../../models/rider_profile.dart';
import '../../models/bike_info.dart';
import '../../services/local_auth_service.dart';
import '../../services/sos_session_manager.dart';
import '../dashboard/main_dashboard_screen.dart';

/// Screen for recording motorcycle specifications during onboarding.
class BikeDetailsScreen extends StatefulWidget {
  final RiderProfile rider;
  final String password;

  const BikeDetailsScreen({
    super.key,
    required this.rider,
    required this.password,
  });

  @override
  State<BikeDetailsScreen> createState() => _BikeDetailsScreenState();
}

class _BikeDetailsScreenState extends State<BikeDetailsScreen> {
  final _modelController = TextEditingController(text: 'Hunter 350 Dapper');
  final _regController = TextEditingController(text: 'KA 05 EQ 8824');
  final _odoController = TextEditingController(text: '4,820 km');
  bool _isSaving = false;

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
  final List<String> _years = [
    '2025',
    '2024',
    '2023',
    '2022',
    '2021',
    '2020'
  ];

  String _selectedFuelType = 'Petrol (E20)';
  final List<String> _fuelTypes = [
    'Petrol (E20)',
    'Electric (EV)',
    'Hybrid'
  ];

  @override
  void dispose() {
    _modelController.dispose();
    _regController.dispose();
    _odoController.dispose();
    super.dispose();
  }

  Future<void> _onSaveBike() async {
    setState(() => _isSaving = true);

    final bike = BikeInfo(
      brand: _selectedBrand,
      model: _modelController.text.trim(),
      regNumber: _regController.text.trim().toUpperCase(),
      year: _selectedYear,
      fuelType: _selectedFuelType,
      odometer: _odoController.text.trim(),
      nextService: 'In 180 km',
    );

    // Register user account with LocalAuthService
    final authResult = await LocalAuthService()
        .signUp(widget.rider.email, widget.password);

    if (!authResult.success) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SheTorqueTheme.dangerRed,
            content: Text(authResult.message),
          ),
        );
      }
      return;
    }

    // Persist rider and vehicle profiles
    await LocalAuthService().saveRiderProfile(widget.rider);
    await LocalAuthService().saveVehicleProfile(bike);
    await SosSessionManager.setRiderName(widget.rider.name);
    await SosSessionManager.markOnboardingComplete();

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
      (route) => false,
    );
  }

  Widget _buildIndicator(String num, String label, bool active) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? SheTorqueTheme.primaryCyan
                : SheTorqueTheme.surfaceLight,
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                color: active ? Colors.black : SheTorqueTheme.textMuted,
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
            color: active
                ? SheTorqueTheme.textWhite
                : SheTorqueTheme.textMuted,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: SheTorqueTheme.border,
      ),
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
                gradient: const LinearGradient(
                  colors: [
                    SheTorqueTheme.surface,
                    SheTorqueTheme.surfaceLight
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.motorcycle_rounded,
                        size: 32, color: SheTorqueTheme.primaryCyan),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register Your Motorcycle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: SheTorqueTheme.textWhite,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Connect your bike for live OBD diagnostics & crash safety monitoring.',
                          style: TextStyle(
                              fontSize: 12, color: SheTorqueTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Brand Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedBrand,
              decoration: const InputDecoration(
                labelText: 'Motorcycle Brand / Make',
                prefixIcon: Icon(Icons.directions_bike_rounded),
              ),
              dropdownColor: SheTorqueTheme.surface,
              items: _brands.map((b) {
                return DropdownMenuItem(value: b, child: Text(b));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedBrand = val);
              },
            ),

            const SizedBox(height: 16),

            // Model Input
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model Name / Edition',
                prefixIcon: Icon(Icons.speed_rounded),
              ),
            ),

            const SizedBox(height: 16),

            // Reg Number
            TextFormField(
              controller: _regController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Registration / Plate Number',
                prefixIcon: Icon(Icons.pin_rounded),
                hintText: 'KA 05 EQ 8824',
              ),
            ),

            const SizedBox(height: 16),

            // Row: Year & Fuel Type
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Model Year',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    dropdownColor: SheTorqueTheme.surface,
                    items: _years.map((y) {
                      return DropdownMenuItem(value: y, child: Text(y));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedYear = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFuelType,
                    decoration: const InputDecoration(
                      labelText: 'Powertrain',
                      prefixIcon: Icon(Icons.local_gas_station_rounded),
                    ),
                    dropdownColor: SheTorqueTheme.surface,
                    items: _fuelTypes.map((f) {
                      return DropdownMenuItem(value: f, child: Text(f));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFuelType = val);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Odometer
            TextFormField(
              controller: _odoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Current Odometer Reading',
                prefixIcon: Icon(Icons.av_timer_rounded),
              ),
            ),

            const SizedBox(height: 32),

            // Launch Button
            ElevatedButton(
              onPressed: _isSaving ? null : _onSaveBike,
              child: _isSaving
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
                        Text('LAUNCH DIGITAL GARAGE'),
                        SizedBox(width: 8),
                        Icon(Icons.rocket_launch_rounded, size: 20),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
