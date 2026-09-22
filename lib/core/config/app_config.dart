class AppConfig {
  /// Supabase project URL injected via build environment.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase public anonymous API key injected via build environment.
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Backend FastAPI base URL injected via build environment.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://rakoon-backend.onrender.com',
  );
}
