import 'package:flutter/material.dart';
import '../../../theme/she_torque_theme.dart';
import '../../../repositories/pink_spots_repository.dart';
import '../../../models/pink_spot_model.dart';

/// HerRide Community tab presenting public Pink Spots from Supabase,
/// community nominations, and simulated group ride convoys.
class CommunityTab extends StatefulWidget {
  final PinkSpotsRepository? repository;

  const CommunityTab({super.key, this.repository});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  late final PinkSpotsRepository _repo;
  List<PinkSpotModel> _pinkSpots = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PinkSpotsRepository();
    _loadPinkSpots();
  }

  Future<void> _loadPinkSpots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final spots = await _repo.getPinkSpots();
      if (mounted) {
        setState(() {
          _pinkSpots = spots;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load community Pink Spots. Showing offline network.';
        });
      }
    }
  }

  void _showAddPinkSpotDialog() {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedCategory = 'police';
    bool isSaving = false;
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
                          'Nominate a Pink Spot',
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
                    const SizedBox(height: 6),
                    const Text(
                      'Share a verified safe haven, all-night police post, or hospital with fellow women riders.',
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
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location / Post Name',
                        prefixIcon: Icon(Icons.location_on_rounded),
                        hintText: 'e.g. Indiranagar Police Station',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      dropdownColor: SheTorqueTheme.surface,
                      items: const [
                        DropdownMenuItem(value: 'police', child: Text('Police Station / Outpost')),
                        DropdownMenuItem(value: 'hospital', child: Text('Hospital / 24x7 ER')),
                        DropdownMenuItem(value: 'safe_zone', child: Text('24x7 Verified Safe Haven')),
                        DropdownMenuItem(value: 'fuel', child: Text('Lit Fuel Station')),
                        DropdownMenuItem(value: 'mechanic', child: Text('Emergency Two-Wheeler Mechanic')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Safety Notes (Optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                        hintText: 'Well-lit area, active security guard present',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                setModalState(() => dialogError = 'Please provide a name for this safe spot.');
                                return;
                              }

                              setModalState(() {
                                isSaving = true;
                                dialogError = null;
                              });

                              try {
                                await _repo.addPinkSpot(
                                  name: name,
                                  category: selectedCategory,
                                  lat: 12.9716, // Bengaluru center demo anchor
                                  lng: 77.5946,
                                  notes: notesCtrl.text.trim(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadPinkSpots();
                              } catch (e) {
                                setModalState(() {
                                  isSaving = false;
                                  dialogError = 'Failed to submit: $e';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SheTorqueTheme.primaryCyan,
                        foregroundColor: Colors.black,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('SUBMIT PINK SPOT'),
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

  Color _categoryColor(String category) {
    switch (category) {
      case 'police':
        return const Color(0xFF2979FF);
      case 'hospital':
        return SheTorqueTheme.dangerRed;
      case 'fuel':
        return SheTorqueTheme.warningAmber;
      default:
        return SheTorqueTheme.secondaryPink;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'police':
        return Icons.local_police_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'fuel':
        return Icons.local_gas_station_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPinkSpots,
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
                    'HerRide Community',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: SheTorqueTheme.textWhite,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sisterhood on two wheels • Peer safety network',
                    style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_location_alt_rounded, color: SheTorqueTheme.primaryCyan),
                tooltip: 'Nominate Pink Spot',
                onPressed: _showAddPinkSpotDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Simulated Group Ride Convoy
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1124), Color(0xFF161B22)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_rounded, color: SheTorqueTheme.secondaryPink, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Weekend Sunrise Breakfast Ride',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: SheTorqueTheme.textWhite,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SheTorqueTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Simulated',
                        style: TextStyle(
                          fontSize: 10,
                          color: SheTorqueTheme.primaryCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bengaluru to Kolar CCD • Convoy tracking & real-time SOS relay demonstration.',
                  style: TextStyle(fontSize: 13, color: SheTorqueTheme.textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 14, color: SheTorqueTheme.textMuted),
                    const SizedBox(width: 6),
                    const Text('Sunday, 06:00 AM', style: TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted)),
                    const Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SheTorqueTheme.secondaryPink,
                        side: const BorderSide(color: SheTorqueTheme.secondaryPink),
                        minimumSize: const Size(90, 32),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Simulated convoy ride RSVP registered.')),
                        );
                      },
                      child: const Text('RSVP', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Community Safe Havens Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pink Spots & Safe Havens',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.textWhite,
                ),
              ),
              TextButton.icon(
                onPressed: _showAddPinkSpotDialog,
                icon: const Icon(Icons.add, size: 16, color: SheTorqueTheme.primaryCyan),
                label: const Text('Nominate', style: TextStyle(color: SheTorqueTheme.primaryCyan, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Loading State
          if (_isLoading) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator(color: SheTorqueTheme.primaryCyan)),
          ]

          // Error State
          else if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SheTorqueTheme.warningAmber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: SheTorqueTheme.warningAmber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  TextButton(onPressed: _loadPinkSpots, child: const Text('RETRY')),
                ],
              ),
            ),
          ]

          // Empty State
          else if (_pinkSpots.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SheTorqueTheme.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.shield_outlined, color: SheTorqueTheme.textMuted, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'No Pink Spots Nominated Yet',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Help protect the sisterhood by nominating your local safe havens and verified pitstops.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SheTorqueTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _showAddPinkSpotDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SheTorqueTheme.primaryCyan,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Nominate First Pink Spot'),
                  ),
                ],
              ),
            ),
          ]

          // Loaded Spots List
          else ...[
            ..._pinkSpots.map((spot) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SheTorqueTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _categoryColor(spot.category).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _categoryIcon(spot.category),
                          color: _categoryColor(spot.category),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spot.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              spot.notes != null && spot.notes!.isNotEmpty
                                  ? spot.notes!
                                  : 'Category: ${spot.category.toUpperCase()}',
                              style: const TextStyle(color: SheTorqueTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _categoryColor(spot.category).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          spot.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _categoryColor(spot.category),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
