import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/she_torque_theme.dart';
import '../models/vehicle_detection.dart';
import '../models/following_alert.dart';
import '../models/guardian_alert_model.dart';
import '../repositories/guardian_alerts_repository.dart';
import '../services/simulated_detection_source.dart';
import '../services/follower_tracker.dart';
import '../services/sms_service.dart';

// ─── Scenario metadata ────────────────────────────────────────────────────────
const _scenarios = [
  (label: 'Normal Traffic', desc: 'Vehicles appear, overtake, and leave.'),
  (
    label: 'Following Vehicle',
    desc: 'One ID persists behind the rider with occasional dropouts.'
  ),
  (
    label: 'Group Ride',
    desc: 'Three riders stay close — all trusted group members.'
  ),
];

/// Guardian Eye screen: rear-view vehicle tracking with FollowerTracker,
/// configurable threshold, Group Ride whitelist, and Supabase history.
class GuardianEyeScreen extends StatefulWidget {
  /// Pass the global DEMO MODE flag from Safety Hub (or default true).
  final bool isDemoMode;

  const GuardianEyeScreen({super.key, this.isDemoMode = true});

  @override
  State<GuardianEyeScreen> createState() => _GuardianEyeScreenState();
}

class _GuardianEyeScreenState extends State<GuardianEyeScreen> {
  // ── Source & Tracker ──────────────────────────────────────────────────────
  late SimulatedDetectionSource _source;
  late FollowerTracker _tracker;
  StreamSubscription<List<VehicleDetection>>? _sub;

  // ── Live state ────────────────────────────────────────────────────────────
  List<VehicleDetection> _currentFrame = [];
  Map<String, int> _trackedSeconds = {};

  // ── Scenario & settings ───────────────────────────────────────────────────
  int _scenarioIndex = 0;
  bool _isGroupRide = false;
  int _thresholdSeconds = 20; // demo default; "production" is 180
  final Set<String> _trustedMesh = {};

  // ── Group-ride whitelist panel ────────────────────────────────────────────
  bool _showTrustedMeshPanel = false;

  // ── History ───────────────────────────────────────────────────────────────
  final GuardianAlertsRepository _alertsRepo = GuardianAlertsRepository();
  List<GuardianAlertModel> _history = [];
  bool _loadingHistory = true;
  String? _historyError;

  // ── Banner ────────────────────────────────────────────────────────────────
  FollowingAlert? _activeBanner;

  // ── Ticker for tracked-seconds refresh ───────────────────────────────────
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _rebuildTracker();
    _startSource();
    _fetchHistory();
    // Refresh seconds-followed display at 1 Hz
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _trackedSeconds = _tracker.currentTrackedSeconds);
    });
  }

  void _rebuildTracker() {
    _tracker = FollowerTracker(
      thresholdSeconds: _thresholdSeconds,
      gapToleranceSeconds: 3,
      trustedMesh: _trustedMesh,
    );
  }

  void _startSource() {
    _sub?.cancel();
    _source = SimulatedDetectionSource(scenarioIndex: _scenarioIndex);
    _tracker.reset();
    _sub = _source.detections.listen(_onFrame);
    _source.start();
  }

  void _onFrame(List<VehicleDetection> frame) {
    if (!mounted) return;
    final alerts = _tracker.process(frame);
    setState(() {
      _currentFrame = frame;
      _trackedSeconds = _tracker.currentTrackedSeconds;
    });

    for (final alert in alerts) {
      _handleAlert(alert);
    }
  }

  Future<void> _handleAlert(FollowingAlert alert) async {
    // Haptic
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();

    // Log to Supabase best-effort
    unawaited(_alertsRepo.createAlert(
      vehicleId: alert.trackId,
      followedSeconds: alert.followedSeconds,
      mode: _isGroupRide ? 'group' : 'single',
      source: 'simulated',
    ));

    if (!mounted) return;
    setState(() => _activeBanner = alert);

    // Refresh history
    _fetchHistory();
  }

  void _shareLoc(FollowingAlert alert) async {
    // Uses the same message format as SmsService crash alert,
    // but content describes the follower situation.
    final isDemo = await SmsService.isDemoModeEnabled();
    if (isDemo || widget.isDemoMode) {
      if (mounted) _showSmsPreview(alert);
    } else {
      // Real SMS via SmsService (re-use existing pipeline)
      await SmsService.sendGuardianFollowerAlert(
        trackId: alert.trackId,
        followedSeconds: alert.followedSeconds,
        isDemoMode: false,
      );
    }
  }

  void _showSmsPreview(FollowingAlert alert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SheTorqueTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SheTorqueTheme.warningAmber, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded,
                color: SheTorqueTheme.warningAmber, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'GUARDIAN ALERT (DEMO MODE)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.textWhite,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMS would be sent to emergency contact:',
              style: TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'GUARDIAN ALERT: Vehicle ${alert.trackId} has been following '
                'for ${alert.followedSeconds}s. I may need help. '
                'Sent via SheTorque Guardian Eye.',
                style: const TextStyle(fontSize: 12, color: SheTorqueTheme.textWhite),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: SheTorqueTheme.primaryCyan)),
          ),
        ],
      ),
    );
  }

  void _dismissBanner() {
    setState(() => _activeBanner = null);
  }

  void _changeScenario(int idx) {
    setState(() {
      _scenarioIndex = idx;
      _activeBanner = null;
      _currentFrame = [];
    });
    _startSource();
  }

  void _toggleMode(bool isGroup) {
    setState(() {
      _isGroupRide = isGroup;
      if (!isGroup) {
        _trustedMesh.clear();
      }
      _showTrustedMeshPanel = isGroup;
    });
    _rebuildTracker();
  }

  void _whitelistVehicle(String id) {
    setState(() => _trustedMesh.add(id));
    _tracker.removeTrack(id);
    _rebuildTracker();
  }

  void _removeFromWhitelist(String id) {
    setState(() => _trustedMesh.remove(id));
    _rebuildTracker();
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final list = await _alertsRepo.getAlerts();
      if (mounted) {
        setState(() {
          _history = list;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = 'Unable to load guardian alert history';
          _loadingHistory = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _source.stop();
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SheTorqueTheme.background,
      appBar: AppBar(
        backgroundColor: SheTorqueTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.remove_red_eye_rounded,
                color: SheTorqueTheme.warningAmber, size: 20),
            SizedBox(width: 8),
            Text(
              'GUARDIAN EYE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: SheTorqueTheme.textWhite,
              ),
            ),
          ],
        ),
        actions: [
          // Settings sheet
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: SheTorqueTheme.textMuted),
            tooltip: 'Threshold settings',
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Alert banner ──────────────────────────────────────────────────
          if (_activeBanner != null) _buildAlertBanner(_activeBanner!),

          // ── Detection canvas ──────────────────────────────────────────────
          _buildCanvas(),
          const SizedBox(height: 14),

          // ── Detection source label ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SheTorqueTheme.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_rounded,
                    size: 14, color: SheTorqueTheme.textMuted),
                SizedBox(width: 6),
                Text(
                  'Detection source: Simulator (camera integration planned)',
                  style:
                      TextStyle(fontSize: 11, color: SheTorqueTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Mode toggle ───────────────────────────────────────────────────
          _buildModeToggle(),
          const SizedBox(height: 12),

          // ── Trusted mesh panel ────────────────────────────────────────────
          if (_showTrustedMeshPanel) _buildTrustedMeshPanel(),

          // ── Scenario picker ───────────────────────────────────────────────
          _buildScenarioPicker(),
          const SizedBox(height: 16),

          // ── Live tracked IDs ──────────────────────────────────────────────
          _buildTrackedIds(),
          const SizedBox(height: 20),

          // ── History ───────────────────────────────────────────────────────
          _buildHistory(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Canvas ────────────────────────────────────────────────────────────────
  Widget _buildCanvas() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: SheTorqueTheme.warningAmber.withValues(alpha: 0.4)),
      ),
      child: Stack(
        children: [
          // Road lines
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              size: const Size(double.infinity, 260),
              painter: _RearViewPainter(
                detections: _currentFrame,
                trackedSeconds: _trackedSeconds,
                thresholdSeconds: _thresholdSeconds,
                trustedMesh: _trustedMesh,
              ),
            ),
          ),
          // SIMULATED FEED label
          Positioned(
            top: 10,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SheTorqueTheme.warningAmber.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'SIMULATED FEED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          // Vehicle count
          Positioned(
            top: 10,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_currentFrame.length} detected',
                style: const TextStyle(
                    fontSize: 10, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Alert banner ──────────────────────────────────────────────────────────
  Widget _buildAlertBanner(FollowingAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SheTorqueTheme.dangerRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: SheTorqueTheme.dangerRed.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: SheTorqueTheme.dangerRed, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'FOLLOWING VEHICLE DETECTED',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: SheTorqueTheme.dangerRed,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _dismissBanner,
                child: const Icon(Icons.close,
                    color: Colors.white54, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vehicle ${alert.trackId} has been behind you for ${alert.followedSeconds}s.',
            style: const TextStyle(
                fontSize: 12, color: SheTorqueTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SheTorqueTheme.dangerRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share_location_rounded, size: 16),
                  label: Text(
                    widget.isDemoMode
                        ? 'Share Location (DEMO)'
                        : 'Share Location',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _shareLoc(alert),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mode toggle ───────────────────────────────────────────────────────────
  Widget _buildModeToggle() {
    return Row(
      children: [
        const Text('Ride Mode:',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SheTorqueTheme.textWhite)),
        const SizedBox(width: 12),
        _modeChip('Single Ride', !_isGroupRide, () => _toggleMode(false)),
        const SizedBox(width: 8),
        _modeChip('Group Ride', _isGroupRide, () => _toggleMode(true)),
      ],
    );
  }

  Widget _modeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? SheTorqueTheme.warningAmber.withValues(alpha: 0.2)
              : SheTorqueTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? SheTorqueTheme.warningAmber
                : SheTorqueTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected
                ? SheTorqueTheme.warningAmber
                : SheTorqueTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Trusted mesh panel ────────────────────────────────────────────────────
  Widget _buildTrustedMeshPanel() {
    final activeIds = _trackedSeconds.keys.toSet();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SheTorqueTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: SheTorqueTheme.warningAmber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group_rounded,
                  color: SheTorqueTheme.warningAmber, size: 16),
              SizedBox(width: 6),
              Text(
                'Trusted Mesh (Biker-Link Whitelist)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.warningAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap a visible vehicle ID to whitelist it. Trusted vehicles will never alert.',
            style:
                TextStyle(fontSize: 11, color: SheTorqueTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Whitelist existing tracks
              for (final id in activeIds)
                _trustedMesh.contains(id)
                    ? Chip(
                        label: Text(id,
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor:
                            SheTorqueTheme.successGreen.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(
                            color: SheTorqueTheme.successGreen),
                        avatar: const Icon(Icons.check_circle_outline,
                            size: 14,
                            color: SheTorqueTheme.successGreen),
                        deleteIcon: const Icon(Icons.close,
                            size: 14, color: SheTorqueTheme.textMuted),
                        onDeleted: () => _removeFromWhitelist(id),
                      )
                    : ActionChip(
                        label: Text(id,
                            style: const TextStyle(
                                fontSize: 11,
                                color: SheTorqueTheme.textWhite)),
                        backgroundColor: SheTorqueTheme.surface,
                        avatar: const Icon(Icons.add_circle_outline,
                            size: 14,
                            color: SheTorqueTheme.warningAmber),
                        onPressed: () => _whitelistVehicle(id),
                      ),
              if (activeIds.isEmpty)
                const Text('No vehicles visible yet.',
                    style: TextStyle(
                        fontSize: 11, color: SheTorqueTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Scenario picker ───────────────────────────────────────────────────────
  Widget _buildScenarioPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Scenario',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: SheTorqueTheme.textWhite)),
        const SizedBox(height: 8),
        for (int i = 0; i < _scenarios.length; i++)
          GestureDetector(
            onTap: () => _changeScenario(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _scenarioIndex == i
                    ? SheTorqueTheme.primaryCyan.withValues(alpha: 0.12)
                    : SheTorqueTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _scenarioIndex == i
                      ? SheTorqueTheme.primaryCyan.withValues(alpha: 0.6)
                      : SheTorqueTheme.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _scenarioIndex == i
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: _scenarioIndex == i
                        ? SheTorqueTheme.primaryCyan
                        : SheTorqueTheme.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _scenarios[i].label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _scenarioIndex == i
                                ? SheTorqueTheme.primaryCyan
                                : SheTorqueTheme.textWhite,
                          ),
                        ),
                        Text(
                          _scenarios[i].desc,
                          style: const TextStyle(
                              fontSize: 11,
                              color: SheTorqueTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Live tracked IDs ──────────────────────────────────────────────────────
  Widget _buildTrackedIds() {
    if (_trackedSeconds.isEmpty) {
      return const Text(
        'No vehicles currently tracked.',
        style: TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Tracked Vehicles',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: SheTorqueTheme.textWhite,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in _trackedSeconds.entries)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SheTorqueTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _trustedMesh.contains(entry.key)
                    ? SheTorqueTheme.successGreen.withValues(alpha: 0.5)
                    : (entry.value >= _thresholdSeconds
                        ? SheTorqueTheme.dangerRed.withValues(alpha: 0.5)
                        : (entry.value >= _thresholdSeconds ~/ 2
                            ? SheTorqueTheme.warningAmber
                                .withValues(alpha: 0.5)
                            : SheTorqueTheme.border)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_bike_rounded,
                    size: 16, color: SheTorqueTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: SheTorqueTheme.textWhite),
                  ),
                ),
                Text(
                  '${entry.value}s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: entry.value >= _thresholdSeconds
                        ? SheTorqueTheme.dangerRed
                        : (entry.value >= _thresholdSeconds ~/ 2
                            ? SheTorqueTheme.warningAmber
                            : SheTorqueTheme.textMuted),
                  ),
                ),
                if (_trustedMesh.contains(entry.key)) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SheTorqueTheme.successGreen
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Trusted',
                        style: TextStyle(
                            fontSize: 9,
                            color: SheTorqueTheme.successGreen,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ── History ───────────────────────────────────────────────────────────────
  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alert History',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: SheTorqueTheme.textWhite,
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: SheTorqueTheme.primaryCyan),
            ),
          )
        else if (_historyError != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SheTorqueTheme.dangerRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: SheTorqueTheme.dangerRed.withValues(alpha: 0.4)),
            ),
            child: Text(
              _historyError!,
              style: const TextStyle(
                  fontSize: 12, color: SheTorqueTheme.textMuted),
            ),
          )
        else if (_history.isEmpty)
          const Text(
            'No guardian alerts logged yet.',
            style:
                TextStyle(fontSize: 12, color: SheTorqueTheme.textMuted),
          )
        else
          for (final item in _history.take(10))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SheTorqueTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SheTorqueTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 18, color: SheTorqueTheme.warningAmber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.vehicleId != null
                              ? 'Vehicle ${item.vehicleId}'
                              : 'Guardian Alert',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: SheTorqueTheme.textWhite,
                          ),
                        ),
                        Text(
                          'Followed ${item.followedSeconds}s • ${item.mode} mode',
                          style: const TextStyle(
                              fontSize: 11,
                              color: SheTorqueTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTime(item.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: SheTorqueTheme.textMuted),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Settings sheet ────────────────────────────────────────────────────────
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SheTorqueTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Guardian Eye Settings',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: SheTorqueTheme.textWhite,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alert Threshold',
                          style: TextStyle(
                              fontSize: 13, color: SheTorqueTheme.textMuted)),
                      Text(
                        '$_thresholdSeconds seconds',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: SheTorqueTheme.primaryCyan,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setModal(() {});
                          setState(() {
                            _thresholdSeconds = 20;
                            _rebuildTracker();
                          });
                        },
                        child: const Text('Demo (20s)',
                            style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setModal(() {});
                          setState(() {
                            _thresholdSeconds = 180;
                            _rebuildTracker();
                          });
                        },
                        child: const Text('Prod (180s)',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Slider(
                value: _thresholdSeconds.toDouble(),
                min: 10,
                max: 300,
                divisions: 29,
                label: '$_thresholdSeconds s',
                activeColor: SheTorqueTheme.primaryCyan,
                onChanged: (v) {
                  setModal(() {});
                  setState(() {
                    _thresholdSeconds = v.round();
                    _rebuildTracker();
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Production value: 180 s. Demo default: 20 s.',
                style: TextStyle(
                    fontSize: 11, color: SheTorqueTheme.textMuted),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CustomPainter: rear-view canvas ────────────────────────────────────────
class _RearViewPainter extends CustomPainter {
  final List<VehicleDetection> detections;
  final Map<String, int> trackedSeconds;
  final int thresholdSeconds;
  final Set<String> trustedMesh;

  _RearViewPainter({
    required this.detections,
    required this.trackedSeconds,
    required this.thresholdSeconds,
    required this.trustedMesh,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Road background
    final roadPaint = Paint()..color = const Color(0xFF0D1B2A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), roadPaint);

    // Perspective road markings
    final linePaint = Paint()
      ..color = const Color(0xFF2A3A4A)
      ..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
      final y = (i + 1) / 5 * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    final midLinePaint = Paint()
      ..color = const Color(0xFF4A5568)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final y = i / 5 * size.height;
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + size.height / 10),
        midLinePaint,
      );
    }

    // Bounding boxes
    for (final det in detections) {
      final rect = Rect.fromLTWH(
        det.bbox.left * size.width,
        det.bbox.top * size.height,
        det.bbox.width * size.width,
        det.bbox.height * size.height,
      );

      final tracked = trackedSeconds[det.trackId] ?? 0;
      final isTrusted = trustedMesh.contains(det.trackId);

      Color boxColor;
      if (isTrusted) {
        boxColor = const Color(0xFF4CAF50); // green
      } else if (tracked >= thresholdSeconds) {
        boxColor = const Color(0xFFEF5350); // red – alert
      } else if (tracked >= thresholdSeconds ~/ 2) {
        boxColor = const Color(0xFFFFC107); // amber – warning
      } else {
        boxColor = const Color(0xFF00BCD4); // cyan – normal
      }

      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, boxPaint);

      // Corner accents
      final cornerPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      const cLen = 8.0;
      // TL
      canvas.drawLine(rect.topLeft, rect.topLeft.translate(cLen, 0), cornerPaint);
      canvas.drawLine(rect.topLeft, rect.topLeft.translate(0, cLen), cornerPaint);
      // TR
      canvas.drawLine(rect.topRight, rect.topRight.translate(-cLen, 0), cornerPaint);
      canvas.drawLine(rect.topRight, rect.topRight.translate(0, cLen), cornerPaint);
      // BL
      canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(cLen, 0), cornerPaint);
      canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(0, -cLen), cornerPaint);
      // BR
      canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(-cLen, 0), cornerPaint);
      canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(0, -cLen), cornerPaint);

      // Label background
      final label = isTrusted
          ? '${det.trackId} ✓'
          : '${det.trackId} ${tracked}s '
              '(${(det.confidence * 100).toStringAsFixed(0)}%)';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: boxColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lblRect = Rect.fromLTWH(
        rect.left,
        rect.top - 14,
        tp.width + 6,
        13,
      );
      canvas.drawRect(lblRect,
          Paint()..color = const Color(0xCC0A1628));
      tp.paint(canvas, Offset(rect.left + 3, rect.top - 13));
    }
  }

  @override
  bool shouldRepaint(_RearViewPainter old) => true;
}
