// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_history_screen.dart';
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
    AuthService.mockIsAdmin = null;
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
      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.text('Masuk'), findsNothing);
      expect(find.byKey(const Key('google_signin_note')), findsOneWidget);
      expect(find.textContaining('Belum punya akun'), findsNothing);
      expect(find.textContaining('menyetujui Syarat & Ketentuan dan Kebijakan Privasi'), findsOneWidget);
      expect(find.byKey(const Key('signin_invitation_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_logout_button')), findsNothing);

      // Verify App Info card is present
      expect(find.text('Informasi Aplikasi'), findsOneWidget);
      expect(find.text('Versi Aplikasi'), findsOneWidget);
    });

    testWidgets('tapping "Masuk dengan Google" signs in directly, with no login popup', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = null;
      var calls = 0;

      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(signInWithGoogle: () async {
          calls++;
          return AuthResponse();
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('signin_invitation_button')));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.byType(LoginBottomSheet), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('a cancelled Google login shows a friendly snackbar', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = null;

      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(
          signInWithGoogle: () async => throw const AuthException('Login Google dibatalkan oleh pengguna.'),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('signin_invitation_button')));
      await tester.pumpAndSettle();

      expect(find.text('Login dibatalkan. Coba lagi bila ingin melanjutkan.'), findsOneWidget);
      expect(find.byKey(const Key('signin_invitation_button')), findsOneWidget);
    });

    testWidgets('a failed Google login shows a friendly snackbar without the raw error', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = null;

      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(
          signInWithGoogle: () async => throw Exception('PlatformException(sign_in_failed, secret.host)'),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('signin_invitation_button')));
      await tester.pumpAndSettle();

      expect(find.text('Gagal masuk dengan Google. Coba lagi.'), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
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
      // P1-17: tidak ada lencana "Akun Terverifikasi" tanpa email_confirmed_at, dan tidak ada kartu sinkronisasi statis.
      expect(find.text('Akun Terverifikasi'), findsNothing);
      expect(find.text('Status Sinkronisasi'), findsNothing);

      // Ensure sensitive tokens/UUIDs are NEVER leaked to UI
      expect(find.text('mock-user-uuid-98765-secret'), findsNothing);
      expect(find.text('mock-token-xyz-secret'), findsNothing);

      expect(find.byKey(const Key('profile_logout_button')), findsOneWidget);
      expect(find.byKey(const Key('signin_invitation_button')), findsNothing);
    });

    testWidgets('hides "Akun Terverifikasi" badge for regular user even if email is confirmed', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'confirmed-user',
          appMetadata: {},
          userMetadata: {'full_name': 'Dewi Konfirmasi'},
          aud: 'authenticated',
          email: 'dewi@rakoon.co',
          emailConfirmedAt: '2026-01-02T00:00:00Z',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      AuthService.mockIsAdmin = false;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Akun Terverifikasi'), findsNothing);
    });

    testWidgets('admin with confirmed email displays only "Admin Rakoon" badge and no "Akun Terverifikasi" badge', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'admin-confirmed-user',
          appMetadata: {'role': 'admin'},
          userMetadata: {'role': 'admin', 'name': 'Admin Terverifikasi'},
          aud: 'authenticated',
          email: 'admin@rakoon.co',
          emailConfirmedAt: '2026-01-02T00:00:00Z',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      AuthService.mockIsAdmin = true;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_admin_badge')), findsOneWidget);
      expect(find.text('Admin Rakoon'), findsOneWidget);
      expect(find.text('Akun Terverifikasi'), findsNothing);
    });

    testWidgets('admin claims in user metadata do not show admin UI (P1-14)', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: User(
          id: 'claims-user',
          appMetadata: {'role': 'admin'},
          userMetadata: {'role': 'admin', 'is_admin': true, 'name': 'Penyusup'},
          aud: 'authenticated',
          email: 'penyusup@rakoon.co',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_admin_badge')), findsNothing);
      expect(find.byKey(const Key('admin_panel_tile')), findsNothing);
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

  group('ProfilePage - Logout Behavior & Confirmation Dialog', () {
    testWidgets('tapping logout opens confirmation dialog, and tapping Batal does not sign out', (
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

      await tester.ensureVisible(logoutBtn);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should be visible
      expect(find.text('Keluar dari akun?'), findsOneWidget);
      expect(find.byKey(const Key('logout_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('logout_confirm_button')), findsOneWidget);

      // Tap Batal
      await tester.tap(find.byKey(const Key('logout_cancel_button')));
      await tester.pumpAndSettle();

      // Dialog dismissed, session NOT cleared
      expect(find.text('Keluar dari akun?'), findsNothing);
      expect(AuthService.currentSession, isNotNull);
    });

    testWidgets('tapping Keluar in confirmation dialog calls signOut and clears session', (
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
      await tester.ensureVisible(logoutBtn);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Tap Keluar
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Session should be cleared
      expect(AuthService.currentSession, isNull);
    });

    testWidgets('logout button is an outline button positioned after Informasi Aplikasi', (
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

      // Check button is OutlinedButton
      expect(tester.widget(logoutBtn), isA<OutlinedButton>());

      // Check position: logout button is below "Informasi Aplikasi"
      final appInfoFinder = find.text('Informasi Aplikasi');
      expect(appInfoFinder, findsOneWidget);
      final appInfoCenter = tester.getCenter(appInfoFinder);
      final logoutCenter = tester.getCenter(logoutBtn);
      expect(logoutCenter.dy, greaterThan(appInfoCenter.dy));
    });
  });

  group('ProfilePage - Menu Sections & Navigation', () {
    testWidgets('admin sees section Admin (Kelola Foto Produk, Verifikasi Klaim Toko) and Toko (Mode Mitra Toko)', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: const User(
          id: 'admin-user',
          email: 'admin@rakoon.app',
          appMetadata: {'role': 'admin'},
          userMetadata: {'role': 'admin', 'name': 'Super Admin'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = true;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Kelola Foto Produk'), findsOneWidget);
      expect(find.text('Verifikasi Klaim Toko'), findsOneWidget);

      expect(find.text('Toko'), findsOneWidget);
      expect(find.text('Mode Mitra Toko'), findsOneWidget);

      expect(find.text('Akun'), findsOneWidget);
      expect(find.text('Riwayat Scan'), findsOneWidget);
      expect(find.text('Bantuan'), findsOneWidget);
      expect(find.text('Kebijakan Privasi'), findsOneWidget);
      expect(find.text('Syarat & Ketentuan'), findsOneWidget);
    });

    testWidgets('regular user sees section Toko and Akun, but NOT section Admin or admin tiles', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: const User(
          id: 'regular-user',
          email: 'user@rakoon.co',
          appMetadata: {},
          userMetadata: {'name': 'Regular User'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = false;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Admin'), findsNothing);
      expect(find.text('Kelola Foto Produk'), findsNothing);
      expect(find.text('Verifikasi Klaim Toko'), findsNothing);

      expect(find.text('Toko'), findsOneWidget);
      expect(find.text('Mode Mitra Toko'), findsOneWidget);

      expect(find.text('Akun'), findsOneWidget);
      expect(find.text('Riwayat Scan'), findsOneWidget);
      expect(find.text('Bantuan'), findsOneWidget);
      expect(find.text('Kebijakan Privasi'), findsOneWidget);
      expect(find.text('Syarat & Ketentuan'), findsOneWidget);
    });

    testWidgets('tapping Riwayat Scan navigates to ScanHistoryScreen', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: const User(
          id: 'regular-user',
          email: 'user@rakoon.co',
          appMetadata: {},
          userMetadata: {'name': 'Regular User'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = false;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      final scanHistoryTile = find.byKey(const Key('scan_history_tile'));
      expect(scanHistoryTile, findsOneWidget);

      await tester.ensureVisible(scanHistoryTile);
      await tester.tap(scanHistoryTile);
      await tester.pumpAndSettle();

      expect(find.byType(ScanHistoryScreen), findsOneWidget);
    });

    testWidgets('tapping Bantuan navigates to DocumentViewerPage and shows title and first section', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: const User(
          id: 'regular-user',
          email: 'user@rakoon.co',
          appMetadata: {},
          userMetadata: {'name': 'Regular User'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = false;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('help_center_tile'));
      expect(tile, findsOneWidget);

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('Bantuan'), findsOneWidget);
      expect(find.text('1. Tentang Rakoon'), findsOneWidget);
    });

    testWidgets('tapping Kebijakan Privasi launches external URL in external application mode', (
      WidgetTester tester,
    ) async {
      Uri? launchedUri;
      LaunchMode? usedMode;

      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: const User(
          id: 'regular-user',
          email: 'user@rakoon.co',
          appMetadata: {},
          userMetadata: {'name': 'Regular User'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = false;

      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(
          launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
            launchedUri = url;
            usedMode = mode;
            return true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('privacy_policy_tile'));
      expect(tile, findsOneWidget);

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri.toString(), 'https://loddy04.github.io/rakoon-frontend/privacy.html');
      expect(usedMode, LaunchMode.externalApplication);
    });

    testWidgets('tapping Syarat & Ketentuan launches external URL in external application mode', (
      WidgetTester tester,
    ) async {
      Uri? launchedUri;
      LaunchMode? usedMode;

      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: const User(
          id: 'regular-user',
          email: 'user@rakoon.co',
          appMetadata: {},
          userMetadata: {'name': 'Regular User'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = false;

      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(
          launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
            launchedUri = url;
            usedMode = mode;
            return true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('terms_of_service_tile'));
      expect(tile, findsOneWidget);

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri.toString(), 'https://loddy04.github.io/rakoon-frontend/terms.html');
      expect(usedMode, LaunchMode.externalApplication);
    });

    testWidgets('when launchUrl fails or throws on privacy/terms, shows friendly SnackBar', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: const User(
          id: 'regular-user',
          email: 'user@rakoon.co',
          appMetadata: {},
          userMetadata: {'name': 'Regular User'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = false;

      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(
          launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
            return false;
          },
        ),
      ));
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('privacy_policy_tile'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('Tidak dapat membuka halaman. Periksa koneksi internet.'), findsOneWidget);
    });

    testWidgets('unauthenticated state does not show section Akun, Bantuan, Privasi, or Syarat Ketentuan', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = null;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Akun'), findsNothing);
      expect(find.text('Riwayat Scan'), findsNothing);
      expect(find.text('Bantuan'), findsNothing);
      expect(find.text('Kebijakan Privasi'), findsNothing);
      expect(find.text('Syarat & Ketentuan'), findsNothing);
    });
  });

  group('ProfilePage - App Info Row Updates', () {
    testWidgets('displays dynamic app version from fake PackageInfo (format version (buildNumber))', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(
          getPackageInfo: () async => PackageInfo(
            appName: 'Rakoon',
            packageName: 'com.rakoon',
            version: '1.2.3',
            buildNumber: '45',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Engine AI'), findsNothing);
      expect(find.text('Versi Aplikasi'), findsOneWidget);
      expect(find.text('1.2.3 (45)'), findsOneWidget);
      expect(find.textContaining('Release Candidate'), findsNothing);
    });

    testWidgets('displays "-" when package info fails to load or throws', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(
          getPackageInfo: () async => throw Exception('Platform channel failed'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Versi Aplikasi'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.textContaining('Release Candidate'), findsNothing);
    });
  });

  group('ProfilePage - Accessibility & Touch Targets', () {
    testWidgets('all menu tiles and action buttons have touch targets >= 48dp and Indonesian semantics', (
      WidgetTester tester,
    ) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: const User(
          id: 'admin-user',
          email: 'admin@rakoon.app',
          appMetadata: {'role': 'admin'},
          userMetadata: {'role': 'admin', 'name': 'Super Admin'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = true;

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      for (final key in [
        const Key('admin_panel_tile'),
        const Key('admin_claim_approval_tile'),
        const Key('merchant_hub_tile'),
        const Key('scan_history_tile'),
        const Key('help_center_tile'),
        const Key('privacy_policy_tile'),
        const Key('terms_of_service_tile'),
        const Key('profile_logout_button'),
      ]) {
        final finder = find.byKey(key);
        expect(finder, findsOneWidget);
        await tester.ensureVisible(finder);
        final size = tester.getSize(finder);
        expect(size.height, greaterThanOrEqualTo(48.0), reason: 'Key $key height should be >= 48dp');
        final semantics = tester.getSemantics(finder);
        expect(semantics.label.isNotEmpty, isTrue, reason: 'Key $key should have a non-empty semantics label');
      }
    });
  });

  group('ProfilePage - Padding and Responsive across States', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('renders cleanly without overflow at ${width.toInt()}dp width for admin', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        AuthService.mockSession = Session(
          accessToken: 'mock-token',
          refreshToken: 'mock-refresh-token',
          expiresIn: 3600,
          tokenType: 'bearer',
          user: const User(
            id: 'admin-user',
            email: 'admin@rakoon.app',
            appMetadata: {'role': 'admin'},
            userMetadata: {'role': 'admin', 'name': 'Super Admin'},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          ),
        );
        AuthService.mockIsAdmin = true;

        await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Check horizontal padding consistency (20dp)
        final headerTopLeft = tester.getTopLeft(find.text('Profil Saya'));
        expect(headerTopLeft.dx, equals(20.0));
      });

      testWidgets('padding horizontal header and content is consistent at ${width.toInt()}dp for regular user', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        AuthService.mockSession = Session(
          accessToken: 'mock-token',
          refreshToken: 'mock-refresh-token',
          expiresIn: 3600,
          tokenType: 'bearer',
          user: const User(
            id: 'reg-user',
            email: 'reg@rakoon.app',
            appMetadata: {},
            userMetadata: {'name': 'Reg User'},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          ),
        );
        AuthService.mockIsAdmin = false;

        await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final headerTopLeft = tester.getTopLeft(find.text('Profil Saya'));
        expect(headerTopLeft.dx, equals(20.0));
      });
    }
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
