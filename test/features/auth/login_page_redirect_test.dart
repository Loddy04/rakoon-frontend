// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/auth/presentation/pages/login_page.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Session mockSession;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  setUp(() {
    mockSession = Session(
      accessToken: 'mock-es256-access-token-xyz',
      refreshToken: 'mock-refresh-token',
      expiresIn: 3600,
      tokenType: 'bearer',
      user: User(
        id: 'mock-user-uuid-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-08-14T00:00:00Z',
        email: 'test@example.com',
      ),
    );
  });

  group('LoginPage Redirect Hardening Tests', () {
    testWidgets(
      'LoginPage pushed onto stack: successful login pops back to previous screen',
      (WidgetTester tester) async {
        AuthService.mockSession = mockSession;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    key: const Key('open_login_btn'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text('Open Login'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open LoginPage
        await tester.tap(find.byKey(const Key('open_login_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Masuk Ke Akun Anda'), findsOneWidget);

        // Fill in credentials
        await tester.enterText(
          find.byKey(const Key('email_field')),
          'user@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('password_field')),
          'secretPassword123',
        );

        // Tap login button
        await tester.tap(find.byKey(const Key('login_button')));
        await tester.pumpAndSettle();

        // Should have popped back to previous screen
        expect(find.byKey(const Key('open_login_btn')), findsOneWidget);
        expect(find.text('Masuk Ke Akun Anda'), findsNothing);
      },
    );

    testWidgets(
      'LoginPage as root route: successful login navigates to AppShell without duplicate',
      (WidgetTester tester) async {
        AuthService.mockSession = mockSession;

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginPage(),
          ),
        );

        expect(find.text('Masuk Ke Akun Anda'), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);

        // Fill in credentials
        await tester.enterText(
          find.byKey(const Key('email_field')),
          'user@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('password_field')),
          'secretPassword123',
        );

        // Tap login button
        await tester.tap(find.byKey(const Key('login_button')));
        await tester.pumpAndSettle();

        // Should have pushed replacement to AppShell
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text('Masuk Ke Akun Anda'), findsNothing);
      },
    );
  });
}
