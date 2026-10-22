import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/she_torque_theme.dart';
import 'services/supabase_auth_service.dart';
import 'services/sos_session_manager.dart';
import 'services/sos_notification_service.dart';
import 'config/app_config.dart';
import 'screens/config_error_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/main_dashboard_screen.dart';
import 'screens/pin_checkin_screen.dart';
import 'screens/sensor_fusion_hub_screen.dart';

/// Single, unified application entrypoint for SheTorque Hub.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase.initialize error: $e');
    }
    await SosNotificationService().init();
  }
  runApp(const SheTorqueApp());
}

class SheTorqueApp extends StatefulWidget {
  const SheTorqueApp({super.key});

  @override
  State<SheTorqueApp> createState() => _SheTorqueAppState();
}

class _SheTorqueAppState extends State<SheTorqueApp> {
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isConfigured) {
      _determineInitialScreen();
    }
  }

  Future<void> _determineInitialScreen() async {
    // 1. If an active stealth SOS tracking session timed out or is ongoing,
    // lock down forcefully to PinCheckinScreen.
    final bool isSessionActive = await SosSessionManager.isSessionActive();
    if (isSessionActive) {
      if (mounted) {
        setState(() {
          _initialScreen = PinCheckinScreen(
            onSafeConfirmed: () {
              setState(() {
                _initialScreen = const MainDashboardScreen();
              });
            },
          );
        });
      }
      return;
    }

    // 2. Check Supabase authentication state
    final bool loggedIn = await SupabaseAuthService.instance.isLoggedIn();
    if (mounted) {
      setState(() {
        _initialScreen =
            loggedIn ? const MainDashboardScreen() : const LoginScreen();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SheTorque Hub',
      debugShowCheckedModeBanner: false,
      theme: SheTorqueTheme.darkTheme,
      home: !AppConfig.isConfigured
          ? const ConfigErrorScreen()
          : (_initialScreen ??
              const Scaffold(
                backgroundColor: SheTorqueTheme.background,
                body: Center(
                  child: CircularProgressIndicator(
                    color: SheTorqueTheme.primaryCyan,
                  ),
                ),
              )),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const MainDashboardScreen(),
        '/hub-demo': (context) => const SensorFusionHubScreen(),
      },
    );
  }
}

/// Standalone technical demonstration alias preserving Phase-1 backward compatibility.
typedef SensorFusionHub = SensorFusionHubScreen;