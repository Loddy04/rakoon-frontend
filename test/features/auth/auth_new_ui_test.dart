import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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

  group('New Login & Register UI Parity Tests (Full-Width Google)', () {
    testWidgets(
      'LoginBottomSheet renders with unified dark header, segmented tabs, and full-width Google button without Facebook',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LoginBottomSheet(),
            ),
          ),
        );

        // Header elements
        expect(find.text('Rakoon'), findsOneWidget);
        expect(find.text('Masuk Ke Akun Anda'), findsOneWidget);
        expect(find.text('Go ahead and set up\nyour account'), findsOneWidget);
        expect(
          find.text('Sign in-up to enjoy the best managing experience'),
          findsNothing,
        );
        expect(find.text('Forgot Password?'), findsNothing);

        // Segmented switcher tabs
        expect(find.text('Login'), findsWidgets);
        expect(find.text('Register'), findsOneWidget);

        // Input fields and icons
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

        // Full-width Google button
        expect(find.text('Masuk dengan Google'), findsOneWidget);
        expect(find.text('Facebook'), findsNothing);

        // Close button
        expect(find.byKey(const Key('close_login_sheet_button')), findsOneWidget);
      },
    );

    testWidgets(
      'LoginBottomSheet switches in-place between Login and Register without full-screen navigation',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LoginBottomSheet(),
            ),
          ),
        );

        // Initially in Login mode
        expect(find.text('Masuk Ke Akun Anda'), findsOneWidget);
        expect(find.text('Rakoon'), findsOneWidget);
        expect(find.text('Login'), findsWidgets);
        expect(find.byKey(const Key('login_button')), findsOneWidget);
        expect(find.byKey(const Key('confirm_password_field')), findsNothing);

        // Switch to Register via Register tab
        await tester.tap(find.byKey(const Key('goto_register_tab')));
        await tester.pumpAndSettle();

        // Now in Register mode in-place
        expect(find.text('Buat Akun Baru'), findsOneWidget);
        expect(find.text('Daftar Rakoon'), findsOneWidget);
        expect(find.byKey(const Key('confirm_password_field')), findsOneWidget);
        expect(find.byKey(const Key('register_button')), findsOneWidget);
        expect(find.text('Daftar dengan Google'), findsOneWidget);
        // Still inside LoginBottomSheet
        expect(find.byType(LoginBottomSheet), findsOneWidget);

        // Switch back to Login via bottom link 'Masuk'
        await tester.tap(find.byKey(const Key('goto_login_button')));
        await tester.pumpAndSettle();

        expect(find.text('Masuk Ke Akun Anda'), findsOneWidget);
        expect(find.byKey(const Key('login_button')), findsOneWidget);
        expect(find.byKey(const Key('confirm_password_field')), findsNothing);
      },
    );
  });
}
