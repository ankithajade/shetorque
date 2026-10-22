import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/she_torque_theme.dart';
import '../../../models/rider_profile.dart';
import '../../../models/bike_info.dart';
import '../../../services/supabase_auth_service.dart';
import '../../auth/login_screen.dart';
import '../../sensor_fusion_hub_screen.dart';

/// Safety profile & rider settings tab displaying emergency medical card,
/// emergency contact management, safety PIN setup, and logout functionality.
class ProfileTab extends StatefulWidget {
  final RiderProfile rider;
  final BikeInfo bike;
  final VoidCallback onTestSosPressed;
  final VoidCallback? onProfileUpdated;

  const ProfileTab({
    super.key,
    required this.rider,
    required this.bike,
    required this.onTestSosPressed,
    this.onProfileUpdated,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late RiderProfile _rider;
  late BikeInfo _bike;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasCustomPin = false;

  @override
  void initState() {
    super.initState();
    _rider = widget.rider;
    _bike = widget.bike;
    _checkPinStatus();
    _fetchFreshProfile();
  }

  Future<void> _checkPinStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(SupabaseAuthService.kCachedSafetyPinHash);
    if (mounted) {
      setState(() {
        _hasCustomPin = hash != null && hash.isNotEmpty;
      });
    }
  }

  Future<void> _fetchFreshProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final freshRider = await SupabaseAuthService.instance.getRiderProfile();
      final freshBike = await SupabaseAuthService.instance.getVehicleProfile();
      if (mounted) {
        setState(() {
          _rider = freshRider;
          _bike = freshBike;
          _isLoading = false;
        });
        widget.onProfileUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not sync latest profile data from cloud. Displaying offline cache.';
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await SupabaseAuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showEditContactDialog() {
    final nameCtrl = TextEditingController(text: _rider.emergencyContactName);
    final phoneCtrl = TextEditingController(text: _rider.emergencyContactPhone);
    final riderPhoneCtrl = TextEditingController(text: _rider.phone);
    bool isSavingDialog = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SheTorqueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Update Emergency Contacts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: SheTorqueTheme.textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This phone number receives instant autonomous SMS alerts with GPS coordinates during a crash.',
                      style: TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: SheTorqueTheme.dangerRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(color: SheTorqueTheme.dangerRed, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: riderPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Your Mobile Phone',
                        prefixIcon: Icon(Icons.phone_iphone_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Contact Name (e.g. Sister, Mom)',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Contact Phone (+91...)',
                        prefixIcon: Icon(Icons.emergency_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSavingDialog
                          ? null
                          : () async {
                              final contactPhone = phoneCtrl.text.trim();
                              if (contactPhone.isEmpty) {
                                setModalState(() => dialogError = 'Emergency contact phone cannot be empty.');
                                return;
                              }

                              setModalState(() {
                                isSavingDialog = true;
                                dialogError = null;
                              });

                              try {
                                final updated = _rider.copyWith(
                                  phone: riderPhoneCtrl.text.trim(),
                                  emergencyContactName: nameCtrl.text.trim(),
                                  emergencyContactPhone: contactPhone,
                                );
                                await SupabaseAuthService.instance.saveRiderProfile(updated);

                                if (mounted) {
                                  setState(() => _rider = updated);
                                  widget.onProfileUpdated?.call();
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setModalState(() {
                                  isSavingDialog = false;
                                  dialogError = 'Failed to save to cloud: $e';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SheTorqueTheme.primaryCyan,
                        foregroundColor: Colors.black,
                      ),
                      child: isSavingDialog
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('SAVE EMERGENCY DETAILS'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSetPinDialog() {
    final pinCtrl = TextEditingController();
    bool isSavingPin = false;
    String? pinError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SheTorqueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Set 4-Digit Safety PIN',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: SheTorqueTheme.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Used to stand down an active SOS emergency session and confirm rider safety. Stored as a salted SHA-256 hash.',
                    style: TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  if (pinError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SheTorqueTheme.dangerRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pinError!,
                        style: const TextStyle(color: SheTorqueTheme.dangerRed, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 18, color: SheTorqueTheme.primaryCyan),
                    decoration: const InputDecoration(
                      hintText: '••••',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSavingPin
                        ? null
                        : () async {
                            final pin = pinCtrl.text.trim();
                            if (pin.length != 4 || int.tryParse(pin) == null) {
                              setModalState(() => pinError = 'PIN must be exactly 4 numeric digits.');
                              return;
                            }

                            setModalState(() {
                              isSavingPin = true;
                              pinError = null;
                            });

                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await SupabaseAuthService.instance.saveSafetyPin(pin);
                              await _checkPinStatus();
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Safety PIN successfully configured!')),
                                );
                              }
                            } catch (e) {
                              setModalState(() {
                                isSavingPin = false;
                                pinError = 'Failed to update PIN: $e';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SheTorqueTheme.secondaryPink,
                      foregroundColor: Colors.white,
                    ),
                    child: isSavingPin
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('UPDATE SAFETY PIN'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? 'Not Set' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: value.isEmpty ? SheTorqueTheme.warningAmber : SheTorqueTheme.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMissingEmergencyContact = _rider.emergencyContactPhone.trim().isEmpty;

    return RefreshIndicator(
      onRefresh: _fetchFreshProfile,
      color: SheTorqueTheme.primaryCyan,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency & Rider Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: SheTorqueTheme.textWhite,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Autonomous SOS safety dispatch configuration',
                    style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: SheTorqueTheme.primaryCyan),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Offline / Error banner if present
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SheTorqueTheme.warningAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SheTorqueTheme.warningAmber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: SheTorqueTheme.warningAmber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: SheTorqueTheme.warningAmber),
                    onPressed: _fetchFreshProfile,
                  ),
                ],
              ),
            ),

          // Missing Emergency Contact Warning Prompt
          if (isMissingEmergencyContact)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SheTorqueTheme.dangerRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SheTorqueTheme.dangerRed, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: SheTorqueTheme.dangerRed, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'NO EMERGENCY CONTACT SET',
                        style: TextStyle(
                          color: SheTorqueTheme.dangerRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Autonomous crash SOS cannot dispatch emergency SMS alerts without a verified recipient phone number.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showEditContactDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SheTorqueTheme.dangerRed,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_call, size: 18),
                      label: const Text('ADD EMERGENCY CONTACT NOW'),
                    ),
                  ),
                ],
              ),
            ),

          // Emergency Medical & Contact Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A080C), Color(0xFF161B22)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SheTorqueTheme.dangerRed.withValues(alpha: 0.5)),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: SheTorqueTheme.dangerRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'BLOOD ${_rider.bloodGroup}',
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
                _buildProfileItem('Rider Name', _rider.name),
                _buildProfileItem('Rider Mobile', _rider.phone),
                _buildProfileItem('Emergency Contact Name', _rider.emergencyContactName),
                _buildProfileItem('Emergency Contact Phone', _rider.emergencyContactPhone),
                _buildProfileItem(
                  'Safety PIN Status',
                  _hasCustomPin ? 'Salted Hash Configured' : 'Default (Any 4 Digits)',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showEditContactDialog,
                        icon: const Icon(Icons.edit_rounded, size: 16, color: SheTorqueTheme.primaryCyan),
                        label: const Text('Edit Contact', style: TextStyle(color: SheTorqueTheme.primaryCyan, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showSetPinDialog,
                        icon: const Icon(Icons.lock_reset_rounded, size: 16, color: SheTorqueTheme.secondaryPink),
                        label: const Text('Set PIN', style: TextStyle(color: SheTorqueTheme.secondaryPink, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
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
                    Icon(Icons.two_wheeler_rounded, color: SheTorqueTheme.primaryCyan, size: 22),
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
                _buildProfileItem('Make & Model', '${_bike.brand} ${_bike.model}'),
                _buildProfileItem('Registration Plate', _bike.regNumber),
                _buildProfileItem('Model Year', _bike.year),
                _buildProfileItem('Powertrain', _bike.fuelType),
                _buildProfileItem('Odometer', _bike.odometer),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Test SOS Flow Trigger
          ElevatedButton.icon(
            onPressed: widget.onTestSosPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: SheTorqueTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('TEST EMERGENCY SOS FLOW'),
          ),
          const SizedBox(height: 12),

          // Technical Demo Trigger
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SensorFusionHubScreen()),
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
            icon: const Icon(Icons.logout_rounded, color: SheTorqueTheme.secondaryPink),
            label: const Text(
              'Log Out / Switch Rider',
              style: TextStyle(color: SheTorqueTheme.secondaryPink),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
