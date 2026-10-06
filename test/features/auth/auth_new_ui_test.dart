import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/auth/presentation/pages/login_page.dart';
import 'package:rakoon_frontend/features/auth/presentation/pages/register_page.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/social_icon_widgets.dart';
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
      'Login page renders header, segmented tab, input icons, and full-width Google button without Facebook',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: LoginPage()));

        // Dark header elements
        expect(find.text('Go ahead and set up\nyour account'), findsOneWidget);
        expect(
          find.text('Sign in-up to enjoy the best managing experience'),
          findsNothing,
        );
        expect(find.text('Rakoon'), findsOneWidget);
        expect(find.text('Masuk Ke Akun Anda'), findsOneWidget);

        // Segmented switcher tabs
        expect(find.text('Login'), findsWidgets);
        expect(find.text('Register'), findsOneWidget);

        // Input fields & green icons
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

        // Eye toggle icon
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

        // Remember me is present, Forgot Password is removed as requested
        expect(find.text('Remember me'), findsOneWidget);
        expect(find.text('Forgot Password?'), findsNothing);

        // Divider & Full-width Google button
        expect(find.text('Or login with'), findsOneWidget);
        expect(find.byType(GoogleLogoWidget), findsOneWidget);
        expect(find.text('Masuk dengan Google'), findsOneWidget);

        // Facebook is omitted as requested
        expect(find.text('Facebook'), findsNothing);
      },
    );

    testWidgets('Password visibility toggle toggles obscureText', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      final passwordFieldFinder = find.byKey(const Key('password_field'));
      final EditableText editableTextBefore =
          tester.widget<EditableText>(find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(EditableText),
      ));
      expect(editableTextBefore.obscureText, isTrue);

      // Tap eye toggle icon
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      final EditableText editableTextAfter =
          tester.widget<EditableText>(find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(EditableText),
      ));
      expect(editableTextAfter.obscureText, isFalse);
    });

    testWidgets('Forgot Password and subtitle are removed from Login', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      expect(find.text('Forgot Password?'), findsNothing);
      expect(
        find.text('Sign in-up to enjoy the best managing experience'),
        findsNothing,
      );
    });

    testWidgets('Remember me checkbox toggles checked state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets(
      'Register page renders with unified design and full-width Google button without Facebook',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

        expect(find.text('Daftar Rakoon'), findsOneWidget);
        expect(find.text('Buat Akun Baru'), findsOneWidget);
        expect(find.text('Konfirmasi Password'), findsOneWidget);
        expect(find.text('Or register with'), findsOneWidget);
        expect(find.text('Daftar dengan Google'), findsOneWidget);
        expect(find.text('Facebook'), findsNothing);
      },
    );

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
      'RegisterPage tapping Login tab navigates back safely',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
                child: const Text('Open Register'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Register'));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterPage), findsOneWidget);

        // Tap Login tab
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();

        // Popped back to initial screen
        expect(find.byType(RegisterPage), findsNothing);
        expect(find.text('Open Register'), findsOneWidget);
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
        // Still inside LoginBottomSheet, NOT RegisterPage route
        expect(find.byType(RegisterPage), findsNothing);
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
