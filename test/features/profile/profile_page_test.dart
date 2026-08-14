// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    // Mock SharedPreferences values for local persistence simulation in tests
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase with mock credentials for test suite
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  tearDown(() {
    AuthService.mockSession = null;
  });

  group('ProfilePage - Unauthenticated State', () {
    testWidgets('shows login invitation when session is null', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = null;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Profil Saya'), findsOneWidget);
      expect(find.text('Belum Masuk Akun'), findsOneWidget);
      expect(
        find.text(
          'Masuk untuk menyinkronkan riwayat belanja dan menikmati semua fitur Rakoon secara maksimal.',
        ),
        findsOneWidget,
      );
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.byKey(const Key('signin_invitation_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_logout_button')), findsNothing);

      // Verify App Info card is present
      expect(find.text('Informasi Aplikasi'), findsOneWidget);
      expect(find.text('1.0.0 (Release Candidate)'), findsOneWidget);
    });

    testWidgets('login invitation button opens LoginBottomSheet', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = null;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('signin_invitation_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginBottomSheet), findsOneWidget);
    });

    testWidgets('login invitation button has >= 48dp height and semantics', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = null;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const Key('signin_invitation_button'));
      expect(buttonFinder, findsOneWidget);

      final buttonSize = tester.getSize(buttonFinder);
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      final semantics = tester.getSemantics(buttonFinder);
      expect(semantics.label, contains('Masuk'));
    });
  });

  group('ProfilePage - Authenticated State & Identity Source', () {
    testWidgets('renders actual session user email and full_name from metadata', (
      WidgetTester tester,
    ) async {
      final mockSession = Session(
        accessToken: 'mock-token-xyz-secret',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'mock-user-uuid-98765-secret',
          appMetadata: {},
          userMetadata: {'full_name': 'Siti Rahmawati'},
          aud: 'authenticated',
          email: 'siti.rahma@rakoon.co',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      AuthService.mockSession = mockSession;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Profil Saya'), findsOneWidget);
      expect(find.text('Siti Rahmawati'), findsOneWidget);
      expect(find.text('siti.rahma@rakoon.co'), findsOneWidget);
      expect(find.text('SR'), findsOneWidget); // User initials in avatar
      expect(find.text('Akun Terverifikasi'), findsOneWidget);
      expect(find.text('Status Sinkronisasi'), findsOneWidget);

      // Ensure sensitive tokens/UUIDs are NEVER leaked to UI
      expect(find.text('mock-user-uuid-98765-secret'), findsNothing);
      expect(find.text('mock-token-xyz-secret'), findsNothing);

      expect(find.byKey(const Key('profile_logout_button')), findsOneWidget);
      expect(find.byKey(const Key('signin_invitation_button')), findsNothing);
    });

    testWidgets('falls back gracefully when metadata is missing (extracts email prefix)', (
      WidgetTester tester,
    ) async {
      final mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'user-no-metadata-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          email: 'alexander@rakoon.co',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      AuthService.mockSession = mockSession;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('alexander'), findsOneWidget);
      expect(find.text('alexander@rakoon.co'), findsOneWidget);
      expect(find.text('AL'), findsOneWidget); // User initials
    });

    testWidgets('handles missing email gracefully with fallback text', (
      WidgetTester tester,
    ) async {
      final mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'user-no-email-123',
          appMetadata: {},
          userMetadata: null,
          aud: 'authenticated',
          email: null,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      AuthService.mockSession = mockSession;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Pengguna Rakoon'), findsOneWidget);
      expect(find.text('Email belum terdaftar'), findsOneWidget);
    });
  });

  group('ProfilePage - Logout Behavior & Loading State', () {
    testWidgets('tapping logout triggers AuthService.signOut and clears mock session', (
      WidgetTester tester,
    ) async {
      final mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'user-logout-test',
          appMetadata: {},
          userMetadata: {'name': 'Budi'},
          aud: 'authenticated',
          email: 'budi@rakoon.co',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      AuthService.mockSession = mockSession;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      final logoutBtn = find.byKey(const Key('profile_logout_button'));
      expect(logoutBtn, findsOneWidget);

      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Session should be cleared
      expect(AuthService.currentSession, isNull);
    });

    testWidgets('logout button has >= 48dp height and semantics', (
      WidgetTester tester,
    ) async {
      final mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {'name': 'Budi'},
          aud: 'authenticated',
          email: 'budi@rakoon.co',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      AuthService.mockSession = mockSession;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      final logoutBtn = find.byKey(const Key('profile_logout_button'));
      final size = tester.getSize(logoutBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));

      final semantics = tester.getSemantics(logoutBtn);
      expect(semantics.label, contains('Keluar'));
    });
  });

  group('ProfilePage - AppShell Tab Integration', () {
    testWidgets('switching to Profile tab in AppShell renders ProfilePage without duplicate shell', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = null;

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      // Switch to Profile Tab (index 2)
      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('Profil Saya'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
    });
  });

  group('ProfilePage - Responsive Layout Verification', () {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('renders cleanly without overflow at ${width.toInt()}dp width (authenticated)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockSession = Session(
          accessToken: 'mock-token',
          refreshToken: 'mock-refresh-token',
          expiresIn: 3600,
          tokenType: 'bearer',
          user: User(
            id: 'long-email-user',
            appMetadata: {},
            userMetadata: {'name': 'Very Long User Name That Should Not Overflow'},
            aud: 'authenticated',
            email: 'verylongemailaddressforresponsivetest@subdomain.rakoon.co.id',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        AuthService.mockSession = mockSession;

        await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
        await tester.pumpAndSettle();

        expect(find.text('Profil Saya'), findsOneWidget);
        expect(find.byKey(const Key('profile_logout_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('renders cleanly without overflow at ${width.toInt()}dp width (unauthenticated)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        AuthService.mockSession = null;

        await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
        await tester.pumpAndSettle();

        expect(find.text('Profil Saya'), findsOneWidget);
        expect(find.byKey(const Key('signin_invitation_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
