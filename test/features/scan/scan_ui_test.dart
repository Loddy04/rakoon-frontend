import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_result_screen.dart';
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

  group('Scan Viewfinder UI & Lifecycle Tests', () {
    testWidgets('ScanCameraScreen renders fallback view on headless environment', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Viewfinder header
      expect(find.text('Pindai Rak'), findsOneWidget);
      expect(find.byKey(const Key('scan_close_button')), findsOneWidget);

      // Since headless tests have no cameras, it must render fallback view
      expect(find.text('Kamera Tidak Tersedia'), findsOneWidget);
      expect(find.byKey(const Key('gallery_picker_fallback_btn')), findsOneWidget);
    });

    testWidgets('ScanCameraScreen safely disposes during camera initialization without calling setState', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
          ),
        ),
      );
      // Immediately destroy the widget to test disposal safety
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Disposed Screen'))));
      await tester.pumpAndSettle();

      expect(find.text('Disposed Screen'), findsOneWidget);
    });

    testWidgets('ScanCameraScreen safely handles lifecycle changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger app inactive (deinitializes camera)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      // Trigger app resumed (reinitializes camera)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Kamera Tidak Tersedia'), findsOneWidget);

      // Transition back to inactive at the end of test to clear Supabase token refresh timers
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      Supabase.instance.client.auth.stopAutoRefresh();
      await tester.pumpAndSettle();
    });
  });

  group('Scan Result Redesign UI Tests', () {
    late List<ScanResultItem> mockItems;

    setUp(() {
      mockItems = [
        ScanResultItem(
          namaProduk: 'Minyak Filma 2L',
          harga: 36000.0,
          ukuran: 2.0,
          satuan: 'l',
          kategori: 'Makanan Pokok',
          confidence: 'tinggi',
          needsVerification: false,
        ),
        ScanResultItem(
          namaProduk: 'Minyak Filma 1L',
          harga: 20000.0,
          ukuran: 1.0,
          satuan: 'l',
          kategori: 'Makanan Pokok',
          confidence: 'rendah',
          needsVerification: true,
        ),
      ];
    });

    testWidgets('ScanResultScreen renders read-only comparison details and Best Value Hero Card', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            baseUrl: 'http://localhost:8000',
            detectedItems: mockItems,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Read-only Text fields should NOT be shown by default (e.g. no TextFields for products)
      expect(find.byType(TextField), findsNothing);

      // Best Value Card is shown because we have 2 comparable items in 'Makanan Pokok' + 'volume'
      expect(find.byKey(const Key('best_value_hero_card')), findsOneWidget);
      expect(find.text('NILAI TERBAIK'), findsOneWidget);
      
      // Best Value is Filma 2L (Unit Price: Rp 18/ml vs Filma 1L Unit Price: Rp 20/ml)
      expect(find.text('Minyak Filma 2L'), findsNWidgets(2)); // Once in hero card, once in comparison list
      expect(find.text('Hemat 10.0% dibanding Minyak Filma 1L (Hemat Rp4.000)'), findsOneWidget);

      // Product comparison cards are shown
      expect(find.text('Produk #1'), findsOneWidget);
      expect(find.text('Produk #2'), findsOneWidget);
      expect(find.text('Verifikasi'), findsOneWidget); // Warning status badge for item 2
    });

    testWidgets('Tapping edit reveals bottom sheet editor', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            baseUrl: 'http://localhost:8000',
            detectedItems: mockItems,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap edit button on the first item
      await tester.tap(find.byKey(const Key('edit_item_0_btn')));
      await tester.pumpAndSettle();

      // Bottom sheet editor is opened and exposes TextFields
      expect(find.text('Edit Produk #1'), findsOneWidget);
      expect(find.byKey(const Key('edit_name_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_price_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_size_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_unit_field')), findsOneWidget);
      expect(find.byKey(const Key('save_edit_button')), findsOneWidget);
    });

    testWidgets('Confirm CTA is present and reads "Simpan Hasil Scan"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            baseUrl: 'http://localhost:8000',
            detectedItems: mockItems,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('save_confirm_button')), findsOneWidget);
      expect(find.text('Simpan Hasil Scan'), findsOneWidget);
    });
  });
}
