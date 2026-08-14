import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_result_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
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

  tearDown(() {
    AuthService.mockSession = null;
    Supabase.instance.client.auth.stopAutoRefresh();
  });

  group('HomeScreen Empty State Tests (No Mock Data)', () {
    testWidgets('HomeScreen renders clean empty state for recent scans without fabricated mock products', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Section title is present
      expect(find.text('Scan Terakhir'), findsOneWidget);
      expect(find.text('Lihat semua'), findsOneWidget);

      // Verify clean Indonesian empty state is rendered
      expect(find.text('Belum Ada Riwayat Pindai'), findsOneWidget);
      expect(
        find.text('Pindai label harga rak produk di toko untuk mulai mencatat dan membandingkan harga.'),
        findsOneWidget,
      );

      // Verify CTA button
      expect(find.byKey(const Key('home_start_scan_cta')), findsOneWidget);
      expect(find.text('Mulai Pindai Rak'), findsOneWidget);

      // Verify no hardcoded mock products exist on HomeScreen
      expect(find.text('Minyak Goreng Filma 2L'), findsNothing);
      expect(find.text('Susu UHT Ultra Milk 1L'), findsNothing);
      expect(find.text('Indomie Goreng Spesial'), findsNothing);
      expect(find.text('Kecap Manis Bango'), findsNothing);
    });

    testWidgets('HomeScreen CTA button opens ScanCameraScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.byKey(const Key('home_start_scan_cta'));
      await tester.scrollUntilVisible(
        ctaFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ScanCameraScreen), findsOneWidget);
      expect(find.text('Pindai Rak'), findsOneWidget);
    });
  });

  group('User Identity & Scan Confirmation Hardening Tests', () {
    testWidgets('ScanResultScreen defaults to empty store and user id without hardcoded UUIDs', (
      WidgetTester tester,
    ) async {
      final mockItems = [
        ScanResultItem(
          namaProduk: 'Beras Ramos 5kg',
          harga: 65000.0,
          ukuran: 5.0,
          satuan: 'kg',
          kategori: 'Makanan Pokok',
          confidence: 'tinggi',
          needsVerification: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            baseUrl: 'http://localhost:8000',
            detectedItems: mockItems,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify widget mounted properly
      expect(find.text('Koreksi Hasil Scan'), findsOneWidget);

      // Verify no hardcoded UUIDs are present in source
      final file = File('lib/features/scan/scan_result_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('21ba0855-bf71-4e6a-9718-b7ac79d8cfd2'), isFalse);
      expect(content.contains('c61b0cfa-3512-4fb3-96b6-3974c05ef1c8'), isFalse);
    });

    test('Source code audit confirms absence of _mockScans and hardcoded UUIDs in production widgets', () {
      final homeFile = File('lib/features/app_shell/presentation/pages/home_screen.dart');
      final homeContent = homeFile.readAsStringSync();
      expect(homeContent.contains('_mockScans'), isFalse);
      expect(homeContent.contains('MockProduct'), isFalse);

      final scanResultFile = File('lib/features/scan/scan_result_screen.dart');
      final scanResultContent = scanResultFile.readAsStringSync();
      expect(scanResultContent.contains('defaultStoreId'), isFalse);
      expect(scanResultContent.contains('defaultUserId'), isFalse);

      final recFile = File('lib/features/recommendation/recommendation_screen.dart');
      final recContent = recFile.readAsStringSync();
      expect(recContent.contains('Ultra Milk 1L'), isFalse);
    });
  });
}
