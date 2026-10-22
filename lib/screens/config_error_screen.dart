import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/she_torque_theme.dart';

/// A visible, non-crashing configuration error screen displayed when
/// mandatory environment secrets (e.g. SUPABASE_URL, SUPABASE_ANON_KEY)
/// are missing from the compile-time configuration.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final missing = AppConfig.missingVariables;

    return Scaffold(
      backgroundColor: SheTorqueTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Warning / Alert Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.15),
                      border: Border.all(
                        color: SheTorqueTheme.secondaryPink,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 56,
                      color: SheTorqueTheme.secondaryPink,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Main Title
                Text(
                  'CONFIGURATION REQUIRED',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 12),

                // Explanation
                Text(
                  'SheTorque Hub cannot start because mandatory environment variables were not supplied at compile-time.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SheTorqueTheme.textMuted,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 28),

                // Missing Keys Box
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: SheTorqueTheme.secondaryPink.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: SheTorqueTheme.secondaryPink,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Missing Environment Variables (${missing.length})',
                            style: const TextStyle(
                              color: SheTorqueTheme.secondaryPink,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...missing.map((key) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: SheTorqueTheme.primaryCyan,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SheTorqueTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      key,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        color: SheTorqueTheme.primaryCyan,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Remediation Box
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: SheTorqueTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: SheTorqueTheme.primaryCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            size: 18,
                            color: SheTorqueTheme.primaryCyan,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'How to Resolve',
                            style: TextStyle(
                              color: SheTorqueTheme.primaryCyan,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '1. Copy env.example.json to env.json\n'
                        '2. Add your SUPABASE_URL and SUPABASE_ANON_KEY\n'
                        '3. Run the application with:',
                        style: TextStyle(
                          color: SheTorqueTheme.textMuted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: SheTorqueTheme.surfaceLight,
                          ),
                        ),
                        child: const SelectableText(
                          'flutter run --dart-define-from-file=env.json',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
