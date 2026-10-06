class AppConfig {
  /// Supabase project URL injected via build environment.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pzymqamrmudqrvvysjly.supabase.co',
  );

  /// Supabase public anonymous API key injected via build environment.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6eW1xYW1ybXVkcXJ2dnlzamx5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwODI1MDQsImV4cCI6MjEwMTY1ODUwNH0.YPH27BLz49ML2cVPJLCgkgiB_8LeUyuBgaq6RJGDut4',
  );

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
