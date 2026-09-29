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

  /// Google OAuth Web Client ID for native Google Sign-In.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '814624284238-pgqnd3ara3v98ulgpd4k7a4mh9m9qkpl.apps.googleusercontent.com',
  );
}
