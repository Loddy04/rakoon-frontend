import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/onboarding_screen.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/splash_screen.dart';
import 'package:rakoon_frontend/main.dart';

void main() {
  group('AppConfig Environment & Validation Tests', () {
    test('Default values for production credentials and endpoints are removed', () {
      expect(AppConfig.apiBaseUrl, isEmpty);
      expect(AppConfig.supabaseUrl, isEmpty);
      expect(AppConfig.supabaseAnonKey, isEmpty);
      expect(AppConfig.googleWebClientId, isEmpty);
    });

    test('missingRequiredVariables lists all missing required variables', () {
      final missing = AppConfig.missingRequiredVariables;
      expect(missing, contains('API_BASE_URL'));
      expect(missing, contains('SUPABASE_URL'));
      expect(missing, contains('SUPABASE_ANON_KEY'));
    });

    testWidgets('RakoonApp displays clear configuration error screen when required variables are missing', (tester) async {
      await tester.pumpWidget(
        const RakoonApp(
          missingConfig: ['API_BASE_URL', 'SUPABASE_URL', 'SUPABASE_ANON_KEY'],
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Konfigurasi aplikasi belum lengkap: jalankan dengan --dart-define-from-file=.env'),
        findsOneWidget,
      );
      expect(find.text('API_BASE_URL'), findsOneWidget);
      expect(find.text('SUPABASE_URL'), findsOneWidget);
      expect(find.text('SUPABASE_ANON_KEY'), findsOneWidget);
    });

    testWidgets('RakoonApp proceeds to SplashScreen when all required variables are present', (tester) async {
      await tester.pumpWidget(
        const RakoonApp(
          missingConfig: [],
        ),
      );
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(
        find.textContaining('Konfigurasi aplikasi belum lengkap: jalankan dengan --dart-define-from-file=.env'),
        findsNothing,
      );

      // Settle the 2500ms splash navigation timer
      await tester.pump(const Duration(milliseconds: 3000));
    });

    testWidgets('SplashScreen and OnboardingScreen can be constructed without baseUrl', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3000));

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });
}
