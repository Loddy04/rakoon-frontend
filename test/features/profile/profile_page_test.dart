// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets('ProfilePage shows login invitation when session is null', (
    WidgetTester tester,
  ) async {
    AuthService.mockSession = null;

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('Profil Saya'), findsOneWidget);
    expect(find.text('Belum Masuk Akun'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.byKey(const Key('signin_invitation_button')), findsOneWidget);
    expect(find.byKey(const Key('profile_logout_button')), findsNothing);
  });

  testWidgets('ProfilePage shows user email when session is non-null', (
    WidgetTester tester,
  ) async {
    // Create mock user session
    final mockSession = Session(
      accessToken: 'mock-token',
      refreshToken: 'mock-refresh-token',
      expiresIn: 3600,
      tokenType: 'bearer',
      user: User(
        id: 'mock-user-id-12345',
        appMetadata: {},
        userMetadata: {'name': 'Budi Rakoon'},
        aud: 'authenticated',
        email: 'budi@rakoon.co',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    AuthService.mockSession = mockSession;

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('Profil Saya'), findsOneWidget);
    expect(find.text('Budi Rakoon'), findsOneWidget);
    expect(find.text('budi@rakoon.co'), findsOneWidget);
    expect(
      find.text('mock-user-id-12345'),
      findsNothing,
    ); // Ensure UUID is not visible to users
    expect(find.byKey(const Key('profile_logout_button')), findsOneWidget);
    expect(find.byKey(const Key('signin_invitation_button')), findsNothing);
  });
}
