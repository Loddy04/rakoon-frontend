import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session _session() => Session(
      accessToken: 'tok',
      tokenType: 'bearer',
      user: User(
        id: 'u1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
    );
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Future<AuthResponse> Function() signIn,
    ValueNotifier<bool?>? result,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open_sheet'),
              onPressed: () async {
                final ok = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => LoginBottomSheet(signInWithGoogle: signIn),
                );
                result?.value = ok;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('open_sheet')));
    await tester.pumpAndSettle();
  }

  testWidgets('the sheet only offers Google: no email, password, register or forgot-password UI', (tester) async {
    await pumpSheet(tester, signIn: () async => AuthResponse());

    expect(find.byKey(const Key('google_login_button')), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);
    expect(find.byKey(const Key('close_login_sheet_button')), findsOneWidget);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    for (final key in ['email_field', 'password_field', 'login_button', 'register_button', 'goto_login_tab', 'goto_register_tab', 'goto_register_button']) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
    for (final text in ['Daftar Sekarang', 'Daftar dengan Google', 'Lupa Password', 'Remember me', 'Email Address', 'Password']) {
      expect(find.textContaining(text), findsNothing, reason: text);
    }
  });

  testWidgets('a successful Google login closes the sheet with true', (tester) async {
    final result = ValueNotifier<bool?>(null);
    await pumpSheet(tester, signIn: () async => AuthResponse(session: _session()), result: result);

    await tester.tap(find.byKey(const Key('google_login_button')));
    await tester.pumpAndSettle();

    expect(result.value, isTrue);
    expect(find.byType(LoginBottomSheet), findsNothing);
  });

  testWidgets('a cancelled Google login shows a friendly message and keeps the sheet open', (tester) async {
    await pumpSheet(tester, signIn: () async => throw const AuthException('Login Google dibatalkan oleh pengguna.'));

    await tester.tap(find.byKey(const Key('google_login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Login dibatalkan. Coba lagi bila ingin melanjutkan.'), findsOneWidget);
    expect(find.byType(LoginBottomSheet), findsOneWidget);
  });

  testWidgets('a failed Google login shows a friendly message without the raw error', (tester) async {
    await pumpSheet(
      tester,
      signIn: () async => throw Exception('PlatformException(sign_in_failed, ApiException: 10, secret.host)'),
    );

    await tester.tap(find.byKey(const Key('google_login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Gagal masuk dengan Google. Coba lagi.'), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.textContaining('secret.host'), findsNothing);
    expect(find.byType(LoginBottomSheet), findsOneWidget);
  });

  testWidgets('an AuthException from the server is not shown raw', (tester) async {
    await pumpSheet(tester, signIn: () async => throw const AuthException('provider is not enabled: internal detail'));

    await tester.tap(find.byKey(const Key('google_login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Gagal masuk dengan Google. Coba lagi.'), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
  });
}
