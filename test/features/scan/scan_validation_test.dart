import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/scan/scan_result_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late MockClient mockHttpClient;
  late List<http.Request> capturedConfirmRequests;

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
    capturedConfirmRequests = [];
    AuthService.mockSession = Session(
      accessToken: 'test-bearer-token-xyz',
      tokenType: 'bearer',
      user: User(
        id: 'user-uuid-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'user@example.com',
      ),
    );

    mockHttpClient = MockClient((request) async {
      if (request.url.path.endsWith('/stores/nearby')) {
        return http.Response(
          jsonEncode({
            'source': 'osm',
            'stores': [
              {
                'store_id': 'store-test-id-1',
                'nama': 'Superindo Dago',
                'lat': -6.2088,
                'lng': 106.8456,
                'jarak_km': 0.8,
              },
            ],
            'message': null,
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/scan/confirm')) {
        capturedConfirmRequests.add(request);
        return http.Response(
          jsonEncode({
            'items_saved': 1,
            'products_created': 0,
            'message': 'Berhasil disimpan!',
          }),
          201,
        );
      }

      return http.Response('Not Found', 404);
    });
  });

  tearDown(() {
    AuthService.mockSession = null;
  });

  Widget buildScanResultScreen(List<ScanResultItem> items) {
    return MaterialApp(
      home: ScanResultScreen(
        baseUrl: 'http://localhost:8000',
        detectedItems: items,
        httpClient: mockHttpClient,
      ),
    );
  }

  group('Scan Result Modal Validation UX Tests', () {
    // 1. Invalid product opens validation dialog.
    testWidgets('1. Invalid product opens validation modal dialog and keeps user on screen', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Minyak Goreng',
          harga: 35000.0,
          ukuran: null,
          satuan: 'l',
          kategori: 'Makanan Pokok',
          confidence: 'tinggi',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // Verify modal dialog is shown
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Data Produk Belum Lengkap'), findsOneWidget);
      expect(find.text('Lengkapi data berikut sebelum menyimpan hasil scan:'), findsOneWidget);

      // Verify no top error banner exists
      expect(find.textContaining('Lengkapi data produk sebelum menyimpan hasil scan.\n'), findsNothing);
    });

    // 2. Missing ukuran shows "ukuran belum diisi"
    testWidgets('2. Missing ukuran shows "ukuran belum diisi" in dialog', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Minyak Goreng',
          harga: 35000.0,
          ukuran: null,
          satuan: 'l',
          kategori: 'Makanan Pokok',
          confidence: 'tinggi',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Data Produk Belum Lengkap'), findsOneWidget);
      expect(find.textContaining('Minyak Goreng - ukuran belum diisi.'), findsOneWidget);
    });

    // 3. Missing satuan shows "satuan belum diisi"
    testWidgets('3. Missing satuan shows "satuan belum diisi" in dialog', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Kecap Manis',
          harga: 15000.0,
          ukuran: 500.0,
          satuan: null,
          kategori: 'Bumbu & Saus',
          confidence: 'tinggi',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Data Produk Belum Lengkap'), findsOneWidget);
      expect(find.textContaining('Kecap Manis - satuan belum diisi.'), findsOneWidget);
    });

    // 4. Multiple invalid products appear in the same dialog
    testWidgets('4. Multiple invalid products appear in the same dialog', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Minyak Goreng',
          harga: 34000.0,
          ukuran: null,
          satuan: null,
          kategori: 'Makanan Pokok',
          confidence: 'rendah',
          needsVerification: true,
        ),
        ScanResultItem(
          namaProduk: 'Indomie Goreng',
          harga: 0.0,
          ukuran: 85.0,
          satuan: 'g',
          kategori: 'Makanan Instan',
          confidence: 'rendah',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Data Produk Belum Lengkap'), findsOneWidget);
      expect(find.textContaining('Minyak Goreng - ukuran dan satuan belum diisi.'), findsOneWidget);
      expect(find.textContaining('Indomie Goreng - harga belum diisi.'), findsOneWidget);
    });

    // 5. /scan/confirm is NOT called when dialog is shown
    testWidgets('5. /scan/confirm is NOT called when dialog is shown', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Gula Pasir',
          harga: 18000.0,
          ukuran: null,
          satuan: 'kg',
          kategori: 'Makanan Pokok',
          confidence: 'rendah',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(capturedConfirmRequests.isEmpty, isTrue);
      expect(find.byType(Dialog), findsOneWidget);
    });

    // 6. Tapping "Tutup" closes dialog and remains on ScanResultScreen
    testWidgets('6. Tapping "Tutup" closes dialog and remains on ScanResultScreen', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Teh Celup Kotak',
          harga: 12000.0,
          ukuran: null,
          satuan: null,
          kategori: 'Minuman',
          confidence: 'rendah',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      final closeBtnFinder = find.byKey(const Key('validation_dialog_close_btn'));
      expect(closeBtnFinder, findsOneWidget);
      await tester.tap(closeBtnFinder);
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.byType(Dialog), findsNothing);
      // Still on ScanResultScreen
      expect(find.text('Koreksi Hasil Scan'), findsOneWidget);
      expect(find.text('Teh Celup Kotak'), findsOneWidget);
    });

    // 7. Tapping "Periksa Produk" closes dialog and remains on ScanResultScreen
    testWidgets('7. Tapping "Periksa Produk" closes dialog and allows editing problematic product', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Susu UHT 1L',
          harga: 17000.0,
          ukuran: 0.0,
          satuan: 'l',
          kategori: 'Susu & Olahan',
          confidence: 'rendah',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      final inspectBtnFinder = find.byKey(const Key('validation_dialog_inspect_btn'));
      expect(inspectBtnFinder, findsOneWidget);
      await tester.tap(inspectBtnFinder);
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Koreksi Hasil Scan'), findsOneWidget);

      // User can immediately edit the item
      await tester.tap(find.byKey(const Key('edit_item_0_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Produk'), findsOneWidget);
    });

    // 8. Fixing invalid product and saving successfully does NOT show dialog
    testWidgets('8. Fixing invalid product and saving successfully does NOT show dialog', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Minyak Goreng',
          harga: 35000.0,
          ukuran: null,
          satuan: null,
          kategori: 'Makanan Pokok',
          confidence: 'rendah',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      // Attempt save -> opens modal dialog
      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      // Close dialog via "Periksa Produk"
      await tester.tap(find.byKey(const Key('validation_dialog_inspect_btn')));
      await tester.pumpAndSettle();

      // Edit item to fix ukuran and satuan
      await tester.tap(find.byKey(const Key('edit_item_0_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit_size_field')), '2');
      await tester.enterText(find.byKey(const Key('edit_unit_field')), 'l');
      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pumpAndSettle();

      // Save again -> successfully submitted, no error dialog!
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(capturedConfirmRequests.length, 1);
      expect(find.text('Simpan Berhasil'), findsOneWidget);
    });

    // 9. Valid products still submit normally
    testWidgets('9. Valid products still submit normally with bearer authorization', (
      WidgetTester tester,
    ) async {
      final validItems = [
        ScanResultItem(
          namaProduk: 'Beras Premium 5kg',
          harga: 72000.0,
          ukuran: 5.0,
          satuan: 'kg',
          kategori: 'Makanan Pokok',
          confidence: 'tinggi',
          needsVerification: false,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(validItems));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(capturedConfirmRequests.length, 1);
      final request = capturedConfirmRequests.first;
      expect(request.headers['Authorization'], 'Bearer test-bearer-token-xyz');
      expect(find.text('Simpan Berhasil'), findsOneWidget);
      expect(find.text('Hasil scan berhasil disimpan.'), findsOneWidget);
      expect(find.text('Entri Harga Baru'), findsNothing);
      expect(find.text('Produk Baru Dibuat'), findsNothing);
      expect(find.byKey(const Key('save_success_done_button')), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);

      // Tap Selesai to dismiss
      await tester.tap(find.byKey(const Key('save_success_done_button')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    // 10. Rapidly tapping "Simpan Hasil Scan" does not stack multiple validation dialogs
    testWidgets('10. Rapidly tapping "Simpan Hasil Scan" does not stack multiple validation dialogs', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Item Tanpa Ukuran',
          harga: 10000.0,
          ukuran: null,
          satuan: 'pcs',
          kategori: 'Makanan Pokok',
          confidence: 'rendah',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);

      // Rapidly tap save button twice without pumpAndSettle in between
      await tester.tap(saveButtonFinder);
      await tester.tap(saveButtonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Only one dialog should be on screen
      expect(find.byType(Dialog), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byKey(const Key('validation_dialog_inspect_btn')));
      await tester.pumpAndSettle();

      // No second stacked dialog
      expect(find.byType(Dialog), findsNothing);
    });

    // 11. Dialog has accessible semantics
    testWidgets('11. Dialog has accessible touch targets and readable text', (
      WidgetTester tester,
    ) async {
      final items = [
        ScanResultItem(
          namaProduk: 'Produk A',
          harga: 5000.0,
          ukuran: null,
          satuan: null,
          kategori: 'Makanan Pokok',
          confidence: 'rendah',
          needsVerification: true,
        ),
      ];

      await tester.pumpWidget(buildScanResultScreen(items));
      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      final inspectBtnFinder = find.byKey(const Key('validation_dialog_inspect_btn'));
      final closeBtnFinder = find.byKey(const Key('validation_dialog_close_btn'));

      final inspectSize = tester.getSize(inspectBtnFinder);
      final closeSize = tester.getSize(closeBtnFinder);

      expect(inspectSize.height, greaterThanOrEqualTo(48.0));
      expect(closeSize.height, greaterThanOrEqualTo(48.0));
    });

    // 12. Dialog has no overflow at 320dp, 360dp, 390dp, and 430dp
    testWidgets('12. Dialog has no overflow across 320dp, 360dp, 390dp, and 430dp', (
      WidgetTester tester,
    ) async {
      final screenWidths = [320.0, 360.0, 390.0, 430.0];
      final manyBadItems = List.generate(
        6,
        (i) => ScanResultItem(
          namaProduk: 'Produk Sangat Panjang Yang Terdeteksi Di Rak Toko #${i + 1}',
          harga: 0.0,
          ukuran: null,
          satuan: null,
          kategori: 'Makanan Pokok',
          confidence: 'rendah',
          needsVerification: true,
        ),
      );

      for (final width in screenWidths) {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildScanResultScreen(manyBadItems));
        await tester.pumpAndSettle();

        final saveButtonFinder = find.byKey(const Key('save_confirm_button'));
        await tester.ensureVisible(saveButtonFinder);
        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(Dialog), findsOneWidget);

        // Dismiss dialog
        await tester.tap(find.byKey(const Key('validation_dialog_close_btn')));
        await tester.pumpAndSettle();
      }

      tester.view.resetPhysicalSize();
    });

    testWidgets('13. Store selector card opens bottom sheet modal and selects store', (
      WidgetTester tester,
    ) async {
      final multiStoreClient = MockClient((request) async {
        if (request.url.path.endsWith('/stores/nearby')) {
          return http.Response(
            jsonEncode({
              'source': 'osm',
              'stores': [
                {
                  'store_id': 'store-test-id-1',
                  'nama': 'Superindo Dago',
                  'lat': -6.2088,
                  'lng': 106.8456,
                  'jarak_km': 0.8,
                },
                {
                  'store_id': 'store-test-id-2',
                  'nama': 'Alfamart Gatsu',
                  'lat': -6.2090,
                  'lng': 106.8460,
                  'jarak_km': 1.2,
                },
              ],
              'message': null,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            detectedItems: [
              ScanResultItem(
                namaProduk: 'Minyak Goreng',
                harga: 35000,
                ukuran: 2.0,
                satuan: 'l',
                kategori: 'Makanan Pokok',
                confidence: 'tinggi',
                needsVerification: false,
              ),
            ],
            baseUrl: 'http://localhost:8000',
            httpClient: multiStoreClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Store selector card is present
      final storeCardFinder = find.byKey(const Key('store_selector_card'));
      expect(storeCardFinder, findsOneWidget);
      expect(find.text('Superindo Dago'), findsOneWidget);
      expect(find.text('Otomatis'), findsOneWidget);

      // Tap to open bottom sheet
      await tester.ensureVisible(storeCardFinder);
      await tester.tap(storeCardFinder);
      await tester.pumpAndSettle();

      // Bottom sheet is visible
      expect(find.text('Pilih Lokasi Toko'), findsOneWidget);
      expect(find.text('Alfamart Gatsu'), findsOneWidget);

      // Select second store
      await tester.tap(find.text('Alfamart Gatsu'));
      await tester.pumpAndSettle();

      // Bottom sheet closed and store updated
      expect(find.text('Pilih Lokasi Toko'), findsNothing);
      expect(find.text('Alfamart Gatsu'), findsOneWidget);
    });
  });
}


