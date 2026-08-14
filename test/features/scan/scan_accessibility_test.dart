import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/scan/scan_result_screen.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<ScanResultItem> mockItems;
  late MockClient mockHttpClient;

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
    ];

    mockHttpClient = MockClient((request) async {
      return http.Response(jsonEncode([]), 200);
    });
  });

  group('Scan Result Accessibility & Hit Target Tests', () {
    testWidgets(
      'Edit and Delete buttons have at least 48x48dp interactive hit bounds',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ScanResultScreen(
              baseUrl: 'http://localhost:8000',
              detectedItems: mockItems,
              httpClient: mockHttpClient,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editBtnFinder = find.byKey(const Key('edit_item_0_btn'));
        final deleteBtnFinder = find.byKey(const Key('delete_item_0_btn'));

        expect(editBtnFinder, findsOneWidget);
        expect(deleteBtnFinder, findsOneWidget);

        // Verify size of interactive widget is at least 48x48
        final editSize = tester.getSize(editBtnFinder);
        final deleteSize = tester.getSize(deleteBtnFinder);

        expect(editSize.width, greaterThanOrEqualTo(48.0));
        expect(editSize.height, greaterThanOrEqualTo(48.0));

        expect(deleteSize.width, greaterThanOrEqualTo(48.0));
        expect(deleteSize.height, greaterThanOrEqualTo(48.0));
      },
    );

    testWidgets('Edit and Delete buttons have clear button Semantics labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            baseUrl: 'http://localhost:8000',
            detectedItems: mockItems,
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('Edit produk Minyak Filma 2L') &&
            widget.properties.button == true,
      );
      expect(editSemantics, findsOneWidget);

      final deleteSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('Hapus produk Minyak Filma 2L') &&
            widget.properties.button == true,
      );
      expect(deleteSemantics, findsOneWidget);
    });

    testWidgets('ScanResultScreen layout is responsive on 320dp without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            baseUrl: 'http://localhost:8000',
            detectedItems: mockItems,
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Koreksi Hasil Scan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
