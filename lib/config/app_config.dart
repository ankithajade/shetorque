/// Centralized application configuration.
///
/// Reads environment variables injected at compile-time via `--dart-define` or
/// `--dart-define-from-file=env.json` with NO hardcoded fallback values.
class AppConfig {
  AppConfig._();

  /// Supabase project URL injected via SUPABASE_URL.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anonymous public API key injected via SUPABASE_ANON_KEY.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Google Maps Directions / Geocoding Web API Key injected via GOOGLE_MAPS_API_KEY.
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// Evaluates whether the required environment configuration (specifically Supabase)
  /// is present.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Returns the names of all missing mandatory environment variables.
  static List<String> get missingVariables {
    final List<String> missing = [];
    if (supabaseUrl.trim().isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (supabaseAnonKey.trim().isEmpty) {
      missing.add('SUPABASE_ANON_KEY');
    }
    return missing;
  }
}
