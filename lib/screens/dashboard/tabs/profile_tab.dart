import 'package:flutter/material.dart';
import '../../../theme/she_torque_theme.dart';
import '../../../models/rider_profile.dart';
import '../../../models/bike_info.dart';
import '../../../services/local_auth_service.dart';
import '../../auth/login_screen.dart';
import '../../sensor_fusion_hub_screen.dart';

/// Safety profile & rider settings tab displaying emergency medical card,
/// tech demonstration launcher, and logout functionality.
class ProfileTab extends StatelessWidget {
  final RiderProfile rider;
  final BikeInfo bike;
  final VoidCallback onTestSosPressed;

  const ProfileTab({
    super.key,
    required this.rider,
    required this.bike,
    required this.onTestSosPressed,
  });

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: SheTorqueTheme.textMuted, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: SheTorqueTheme.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await LocalAuthService().logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Emergency & Rider Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: SheTorqueTheme.textWhite,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Information transmitted in automated SOS crash dispatches',
          style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13),
        ),
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
            border: Border.all(
                color: SheTorqueTheme.dangerRed.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_services_rounded,
                      color: SheTorqueTheme.dangerRed, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Emergency Medical ID',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.dangerRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'BLOOD ${rider.bloodGroup}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildProfileItem('Rider Name', rider.name),
              _buildProfileItem('Rider Mobile', rider.phone),
              _buildProfileItem('Primary Emergency Contact',
                  rider.emergencyContactName),
              _buildProfileItem('Emergency Contact Phone',
                  rider.emergencyContactPhone),
              _buildProfileItem('Home Address', rider.address),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Motorcycle Details Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: SheTorqueTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SheTorqueTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.two_wheeler_rounded,
                      color: SheTorqueTheme.primaryCyan, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Registered Motorcycle',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: SheTorqueTheme.textWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildProfileItem('Make & Model', '${bike.brand} ${bike.model}'),
              _buildProfileItem('Registration Plate', bike.regNumber),
              _buildProfileItem('Model Year', bike.year),
              _buildProfileItem('Powertrain', bike.fuelType),
              _buildProfileItem('Odometer', bike.odometer),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Test SOS Flow Modal Trigger
        ElevatedButton.icon(
          onPressed: onTestSosPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: SheTorqueTheme.dangerRed,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.emergency_rounded),
          label: const Text('TEST EMERGENCY SOS FLOW'),
        ),

        const SizedBox(height: 12),

        // Technical SensorFusionHub Demo Screen Trigger
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SensorFusionHubScreen(),
              ),
            );
          },
          icon: const Icon(Icons.hub_rounded, color: SheTorqueTheme.primaryCyan),
          label: const Text(
            'Open Standalone Sensor Fusion Hub (Demo)',
            style: TextStyle(color: SheTorqueTheme.primaryCyan),
          ),
        ),

        const SizedBox(height: 12),

        // Log Out Button
        OutlinedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout_rounded,
              color: SheTorqueTheme.secondaryPink),
          label: const Text(
            'Log Out / Switch Rider',
            style: TextStyle(color: SheTorqueTheme.secondaryPink),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
