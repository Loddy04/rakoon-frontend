import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/splash_screen.dart';
import 'package:rakoon_frontend/features/auth/presentation/pages/login_page.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

export 'package:rakoon_frontend/features/debug/integration_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration sourced via build environment definitions (e.g. --dart-define-from-file=.env.json)
  final String supabaseUrl = AppConfig.supabaseUrl;
  final String supabaseAnonKey = AppConfig.supabaseAnonKey;
  final String apiBaseUrl = AppConfig.apiBaseUrl;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey, // ignore: deprecated_member_use
      );
    } catch (e) {
      debugPrint('Supabase initialization note: $e');
    }
  } else {
    debugPrint(
      'ℹ️ Info: SUPABASE_URL atau SUPABASE_ANON_KEY belum terisi. '
      'Aplikasi berjalan tanpa koneksi langsung Supabase (gunakan --dart-define-from-file=.env).',
    );
  }

  runApp(RakoonApp(baseUrl: apiBaseUrl));
}

class RakoonApp extends StatelessWidget {
  final String? baseUrl;
  const RakoonApp({super.key, this.baseUrl});

  @override
  Widget build(BuildContext context) {
    final String effectiveBaseUrl = baseUrl ?? AppConfig.apiBaseUrl;

    return MaterialApp(
      title: 'Rakoon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode:
          ThemeMode.light, // Menyesuaikan dengan visual referensi light theme
      home: SplashScreen(baseUrl: effectiveBaseUrl),
    );
  }
}

// TODO: Remove or refactor AuthStateGate in Task A6, as it is a mandatory auth gate that conflicts with progressive login production plans.
class AuthStateGate extends StatelessWidget {
  const AuthStateGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        final session = AuthService.currentSession;
        if (session != null) {
          return const AppShell();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
