// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/features/debug/integration_dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/profile_page.dart';

void main() {
  setUpAll(() async {
    // Mock SharedPreferences values for local persistence simulation in tests
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase with mock credentials for tests
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  group('Auth UI Tests', () {
    group('JWT Auth Integration Tests', () {
      late Session mockSession;

      setUp(() {
        // Create a mock session using standard Supabase Session model
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
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      });

      tearDown(() {
        // Clear mock session
        AuthService.mockSession = null;
      });

      testWidgets(
        '1. authenticated request menghasilkan Authorization Bearer header',
        (WidgetTester tester) async {
          AuthService.mockSession = mockSession;

          String? capturedHeader;
          final mockClient = MockClient((request) async {
            capturedHeader = request.headers['Authorization'];
            return http.Response(
              jsonEncode({
                'authenticated': true,
                'user_id': 'mock-user-uuid-123',
              }),
              200,
            );
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: IntegrationDashboardPage(httpClient: mockClient),
              ),
            ),
          );

          // Tap on "Kirim Token Bearer JWT"
          await tester.ensureVisible(find.byKey(const Key('test_jwt_button')));
          await tester.tap(find.byKey(const Key('test_jwt_button')));
          await tester.pumpAndSettle();

          expect(capturedHeader, equals('Bearer mock-es256-access-token-xyz'));
          expect(find.text('Status Uji JWT: Sukses'), findsOneWidget);
          expect(find.text('mock-user-uuid-123'), findsOneWidget);
        },
      );

      testWidgets('2. no session tidak mengirim request', (
        WidgetTester tester,
      ) async {
        // No session
        AuthService.mockSession = null;

        bool requestSent = false;
        final mockClient = MockClient((request) async {
          requestSent = true;
          return http.Response('', 401);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IntegrationDashboardPage(httpClient: mockClient),
            ),
          ),
        );

        // Tap on "Kirim Token Bearer JWT"
        await tester.ensureVisible(find.byKey(const Key('test_jwt_button')));
        await tester.tap(find.byKey(const Key('test_jwt_button')));
        await tester.pumpAndSettle();

        expect(requestSent, isFalse);
        expect(find.text('Status Uji JWT: Gagal'), findsOneWidget);
        expect(
          find.text('Error: Silakan login terlebih dahulu.'),
          findsOneWidget,
        );
      });

      testWidgets('3. backend 401 menghasilkan error state', (
        WidgetTester tester,
      ) async {
        AuthService.mockSession = mockSession;

        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Not authenticated'}),
            401,
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IntegrationDashboardPage(httpClient: mockClient),
            ),
          ),
        );

        // Tap on "Kirim Token Bearer JWT"
        await tester.ensureVisible(find.byKey(const Key('test_jwt_button')));
        await tester.tap(find.byKey(const Key('test_jwt_button')));
        await tester.pumpAndSettle();

        expect(find.text('Status Uji JWT: Gagal (401)'), findsOneWidget);
        expect(
          find.text(
            'Error: Not authenticated: Token tidak valid atau expired.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('4. successful response membaca user_id', (
        WidgetTester tester,
      ) async {
        AuthService.mockSession = mockSession;

        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'authenticated': true,
              'user_id': 'another-mock-user-id',
            }),
            200,
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IntegrationDashboardPage(httpClient: mockClient),
            ),
          ),
        );

        // Tap on "Kirim Token Bearer JWT"
        await tester.ensureVisible(find.byKey(const Key('test_jwt_button')));
        await tester.tap(find.byKey(const Key('test_jwt_button')));
        await tester.pumpAndSettle();

        expect(find.text('Status Uji JWT: Sukses'), findsOneWidget);
        expect(find.text('another-mock-user-id'), findsOneWidget);
      });

      testWidgets('5. access token tidak muncul dalam UI/log test', (
        WidgetTester tester,
      ) async {
        AuthService.mockSession = mockSession;

        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'authenticated': true,
              'user_id': 'mock-user-uuid-123',
            }),
            200,
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IntegrationDashboardPage(httpClient: mockClient),
            ),
          ),
        );

        // Tap on "Kirim Token Bearer JWT"
        await tester.ensureVisible(find.byKey(const Key('test_jwt_button')));
        await tester.tap(find.byKey(const Key('test_jwt_button')));
        await tester.pumpAndSettle();

        // The mock access token string 'mock-es256-access-token-xyz' should never be visible in UI elements
        expect(
          find.textContaining('mock-es256-access-token-xyz'),
          findsNothing,
        );
      });
    });

    group('AppShell Tests', () {
      late Session mockSession;

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
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      });

      tearDown(() {
        AuthService.mockSession = null;
      });

      testWidgets('AppShell tab switching works', (WidgetTester tester) async {
        AuthService.mockSession = mockSession;

        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();

        // Initially shows Home tab (Index 0)
        expect(find.text('Rakoon'), findsOneWidget);
        expect(find.byKey(const Key('nav_tab_0')), findsOneWidget);
        expect(find.byKey(const Key('nav_tab_1')), findsOneWidget);
        expect(find.byKey(const Key('nav_tab_2')), findsOneWidget);

        // Tap History tab (Index 2)
        await tester.tap(find.byKey(const Key('nav_tab_2')));
        await tester.pumpAndSettle();

        // Now shows Profil tab
        expect(find.byType(ProfilePage), findsOneWidget);
        // Bottom nav is still visible
        expect(find.byKey(const Key('nav_tab_2')), findsOneWidget);

        // Tap Scan tab (Index 1)
        await tester.tap(find.byKey(const Key('nav_tab_1')));
        await tester.pumpAndSettle();

        // Bottom nav should be hidden in scan mode
        expect(find.byKey(const Key('nav_tab_1')), findsNothing);
        expect(find.byType(ScanCameraScreen), findsOneWidget);
      });
    });
  });
}
