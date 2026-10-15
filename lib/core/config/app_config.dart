class AppConfig {
  /// Supabase project URL injected via build environment.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );

  /// Supabase public anonymous API key injected via build environment.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Backend FastAPI base URL injected via build environment.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Google OAuth Web Client ID for native Google Sign-In.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  // ponytail: compile-time define for demo ads; add remote config when feature flags are introduced
  /// Flag to request demo promo ads in development environments.
  static const bool allowDemoAds = bool.fromEnvironment(
    'ALLOW_DEMO_ADS',
    defaultValue: false,
  );

  /// Menghitung nama-nama variabel konfigurasi wajib yang belum terdefinisi.
  static List<String> get missingRequiredVariables {
    final missing = <String>[];
    if (apiBaseUrl.trim().isEmpty) missing.add('API_BASE_URL');
    if (supabaseUrl.trim().isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.trim().isEmpty) missing.add('SUPABASE_ANON_KEY');
    return missing;
  }

  static bool get isConfigured => missingRequiredVariables.isEmpty;
}
