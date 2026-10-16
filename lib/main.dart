import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/splash_screen.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final missing = AppConfig.missingRequiredVariables;
  if (missing.isNotEmpty) {
    runApp(RakoonApp(missingConfig: missing));
    return;
  }

  final String supabaseUrl = AppConfig.supabaseUrl;
  final String supabaseAnonKey = AppConfig.supabaseAnonKey;

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey, // ignore: deprecated_member_use
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Supabase initialization note: ${e.runtimeType}');
    }
  }

  runApp(const RakoonApp());
}

class RakoonApp extends StatelessWidget {
  final String? baseUrl;
  final List<String>? missingConfig;

  const RakoonApp({super.key, this.baseUrl, this.missingConfig});

  @override
  Widget build(BuildContext context) {
    final missing = missingConfig ?? AppConfig.missingRequiredVariables;
    if (missing.isNotEmpty) {
      return MaterialApp(
        title: 'Rakoon',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: ConfigErrorScreen(missingVariables: missing),
      );
    }

    return MaterialApp(
      title: 'Rakoon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode:
          ThemeMode.light, // Menyesuaikan dengan visual referensi light theme
      home: const SplashScreen(),
    );
  }
}

class ConfigErrorScreen extends StatelessWidget {
  final List<String> missingVariables;

  const ConfigErrorScreen({super.key, required this.missingVariables});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCA5A5)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 32),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Konfigurasi Belum Lengkap',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D2818),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Konfigurasi aplikasi belum lengkap: jalankan dengan --dart-define-from-file=.env',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Variabel wajib berikut belum terdefinisi:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  for (final variable in missingVariables)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Text(
                            variable,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1F2937),
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
      ),
    );
  }
}
