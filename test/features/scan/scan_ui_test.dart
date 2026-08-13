import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_result_screen.dart';
import 'package:rakoon_frontend/features/recommendation/recommendation_screen.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> mockEvaluateResponse(List<dynamic> items) {
  final validList = [];
  final excludedList = [];
  
  for (final item in items) {
    final name = item['nama_produk']?.toString() ?? '';
    final price = item['harga'] as num?;
    final size = item['ukuran'] as num?;
    final unit = item['satuan']?.toString() ?? '';
    final category = item['kategori']?.toString() ?? 'Lainnya';
    
    if (name.isEmpty || price == null || price <= 0 || size == null || size <= 0 || unit.isEmpty) {
      excludedList.add({
        'product_id': item['product_id'],
        'nama_produk': name.isEmpty ? null : name,
        'harga': price,
        'ukuran': size,
        'satuan': unit,
        'reason': 'Data tidak valid',
      });
      continue;
    }
    
    validList.add({
      'product_id': item['product_id'],
      'nama_produk': name,
      'harga': price.toDouble(),
      'ukuran': size.toDouble(),
      'satuan': unit,
      'kategori': category,
    });
  }

  final Map<String, List<dynamic>> catGroups = {};
  for (final item in validList) {
    final cat = item['kategori'];
    catGroups.putIfAbsent(cat, () => []).add(item);
  }

  final categoriesJson = [];
  for (final cat in catGroups.keys) {
    final groupItems = catGroups[cat]!;
    
    final Map<String, List<dynamic>> dimGroups = {};
    for (final item in groupItems) {
      final unit = item['satuan'].toString().toLowerCase();
      String dim = 'count';
      String baseUnit = 'pcs';
      double multiplier = 1.0;
      if (['ml', 'l'].contains(unit)) {
        dim = 'volume';
        baseUnit = 'ml';
        multiplier = unit == 'l' ? 1000.0 : 1.0;
      } else if (['g', 'kg'].contains(unit)) {
        dim = 'weight';
        baseUnit = 'g';
        multiplier = unit == 'kg' ? 1000.0 : 1.0;
      }
      
      dimGroups.putIfAbsent(dim, () => []).add({
        'item': item,
        'normalized_size': item['ukuran'] * multiplier,
        'unit_price': item['harga'] / (item['ukuran'] * multiplier),
        'base_unit': baseUnit,
      });
    }

    final dimGroupsJson = [];
    for (final dim in dimGroups.keys) {
      final list = dimGroups[dim]!;
      final bool isComparable = list.length >= 2;
      
      final rankedItems = [];
      if (isComparable) {
        list.sort((a, b) => (a['unit_price'] as double).compareTo(b['unit_price'] as double));
        final double priceA = list[0]['unit_price'];
        final double priceB = list[1]['unit_price'];
        final bool isEqual = (priceA - priceB).abs() < 1e-6;
        
        for (int rank = 0; rank < list.length; rank++) {
          final el = list[rank];
          final double up = el['unit_price'];
          final isBest = (rank == 0) && !isEqual;
          
          rankedItems.add({
            'product_id': el['item']['product_id'],
            'nama_produk': el['item']['nama_produk'],
            'harga': el['item']['harga'],
            'ukuran_original': el['item']['ukuran'],
            'satuan_original': el['item']['satuan'],
            'normalized_ukuran': el['normalized_size'],
            'base_unit': el['base_unit'],
            'harga_per_unit': up,
            'unit_price_label': 'Rp ${up.toStringAsFixed(0)} / ${el['base_unit']}',
            'rank': rank + 1,
            'is_best_value': isBest,
            'badge': isBest ? 'Best Value' : null,
            'explanation': isEqual ? 'Harga unit sama' : (isBest ? 'Paling murah' : 'Lebih mahal'),
          });
        }
      } else {
        final el = list[0];
        rankedItems.add({
          'product_id': el['item']['product_id'],
          'nama_produk': el['item']['nama_produk'],
          'harga': el['item']['harga'],
          'ukuran_original': el['item']['ukuran'],
          'satuan_original': el['item']['satuan'],
          'normalized_ukuran': el['normalized_size'],
          'base_unit': el['base_unit'],
          'harga_per_unit': el['unit_price'],
          'unit_price_label': 'Rp ${el['unit_price'].toStringAsFixed(0)} / ${el['base_unit']}',
          'rank': 1,
          'is_best_value': false,
          'badge': null,
          'explanation': 'Single Item',
        });
      }

      dimGroupsJson.add({
        'dimension': dim,
        'dimension_label': dim == 'volume' ? 'Volume' : (dim == 'weight' ? 'Berat' : 'Jumlah'),
        'base_unit': list[0]['base_unit'],
        'is_comparable': isComparable,
        'best_value': isComparable && rankedItems[0]['is_best_value'] ? rankedItems[0] : null,
        'ranked_items': rankedItems,
      });
    }

    categoriesJson.add({
      'kategori': cat,
      'dimension_groups': dimGroupsJson,
    });
  }

  return {
    'total_evaluated': items.length,
    'total_valid': validList.length,
    'total_excluded': excludedList.length,
    'categories': categoriesJson,
    'excluded_items': excludedList,
  };
}

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

      expect(find.text('Pindai Rak'), findsOneWidget);
      expect(find.byKey(const Key('scan_close_button')), findsOneWidget);
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

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Kamera Tidak Tersedia'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      Supabase.instance.client.auth.stopAutoRefresh();
      await tester.pumpAndSettle();
    });

    test('ScanCameraScreen does not use BoxFit.fill for camera preview or captured imagery', () {
      final file = File('lib/features/scan/scan_camera_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('BoxFit.fill'), isFalse);
    });

    test('ScanCameraScreen implements native portrait aspect ratio preservation logic', () {
      final file = File('lib/features/scan/scan_camera_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('_cameraController!.value.aspectRatio > 1.0'), isTrue);
      expect(content.contains('1.0 / _cameraController!.value.aspectRatio'), isTrue);
    });

    test('ScanCameraScreen passes captured image file directly without modifications', () {
      final file = File('lib/features/scan/scan_camera_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('ScanService.scanPhoto('), isTrue);
      expect(content.contains('_imageFile!,'), isTrue);
    });
  });

  group('Scan Correction & On-Demand Best Value Tests', () {
    late List<ScanResultItem> mockItems;
    late MockClient mockHttpClient;

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
        ScanResultItem(
          namaProduk: 'Ultra Milk 1L',
          harga: 18000.0,
          ukuran: 1.0,
          satuan: 'l',
          kategori: 'Susu & Olahan',
          confidence: 'tinggi',
          needsVerification: false,
        ),
      ];

      mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/recommendation/evaluate')) {
          final requestBody = jsonDecode(request.body);
          final candidates = requestBody['items'] as List;
          final responseBody = mockEvaluateResponse(candidates);
          return http.Response(jsonEncode(responseBody), 200);
        }
        return http.Response('Not Found', 404);
      });
    });

    testWidgets('ScanResultScreen does not calculate or display Best Value on initial render', (WidgetTester tester) async {
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

      // Flat list of products, NO category headings on main screen
      expect(find.text('Kategori: Makanan Pokok'), findsNothing);
      expect(find.text('Kategori: Susu & Olahan'), findsNothing);

      // Best Value winner tags are NOT displayed on initial render
      expect(find.text('Nilai Terbaik'), findsNothing);

      // CTA button is visible
      expect(find.byKey(const Key('best_value_cta_button')), findsOneWidget);
    });

    testWidgets('Tapping CTA triggers Best Value calculation and opens RecommendationScreen', (WidgetTester tester) async {
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

      // Tap CTA to compute Best Value on-demand
      await tester.ensureVisible(find.byKey(const Key('best_value_cta_button')));
      await tester.tap(find.byKey(const Key('best_value_cta_button')));
      await tester.pumpAndSettle();

      // Now RecommendationScreen is opened and displays per-category winner cards
      expect(find.text('Best Value Recommendation'), findsOneWidget);
      expect(find.text('Makanan Pokok'), findsOneWidget);
      expect(find.text('Susu & Olahan'), findsOneWidget);

      // In comparable Makanan Pokok category: Filma 2L (Rp18/ml) wins over Filma 1L (Rp20/ml)
      expect(find.descendant(of: find.byType(RecommendationScreen), matching: find.text('Minyak Filma 2L')), findsWidgets);
      expect(find.text('Best Value'), findsWidgets);

      // Single item Susu & Olahan displays Single Item badge
      expect(find.text('Single Item'), findsWidgets);

      // Close Best Value recommendation screen
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Returns cleanly to ScanResultScreen with no mutation to items
      expect(find.text('Koreksi Hasil Scan'), findsOneWidget);
    });

    testWidgets('Editing price modifies inputs and recalculates correct winner upon opening CTA again', (WidgetTester tester) async {
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

      // Edit Filma 2L price from 36000 to 45000 (unit price 22.5/ml vs Filma 1L 20/ml)
      await tester.tap(find.byKey(const Key('edit_item_0_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit_price_field')), '45000');
      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pumpAndSettle();

      // Tap CTA to view updated Best Value
      await tester.ensureVisible(find.byKey(const Key('best_value_cta_button')));
      await tester.tap(find.byKey(const Key('best_value_cta_button')));
      await tester.pumpAndSettle();

      // Now Filma 1L should be the winner!
      expect(find.descendant(of: find.byType(RecommendationScreen), matching: find.text('Minyak Filma 1L')), findsWidgets);
      expect(find.text('Best Value'), findsWidgets);
    });

    testWidgets('Deleted items are excluded and added items participate in Best Value calculation', (WidgetTester tester) async {
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

      // Delete Ultra Milk 1L (index 2)
      await tester.ensureVisible(find.byKey(const Key('delete_item_2_btn')));
      await tester.tap(find.byKey(const Key('delete_item_2_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();

      // Add Indomilk 1L (15000, 1L) to Makanan Pokok
      await tester.ensureVisible(find.byKey(const Key('add_product_button')));
      await tester.tap(find.byKey(const Key('add_product_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('add_name_field')), 'Indomilk 1L');
      await tester.enterText(find.byKey(const Key('add_price_field')), '15000');
      await tester.enterText(find.byKey(const Key('add_size_field')), '1');
      await tester.enterText(find.byKey(const Key('add_unit_field')), 'l');
      await tester.tap(find.byKey(const Key('save_add_button')));
      await tester.pumpAndSettle();

      // Tap CTA to view updated Best Value
      await tester.ensureVisible(find.byKey(const Key('best_value_cta_button')));
      await tester.tap(find.byKey(const Key('best_value_cta_button')));
      await tester.pumpAndSettle();

      // Ultra Milk should be gone
      expect(find.text('Ultra Milk 1L'), findsNothing);

      // Makanan Pokok now has 3 comparable items (Filma 2L, Filma 1L, Indomilk 1L)
      // Indomilk 1L is Rp15/ml, making it the winner!
      expect(find.descendant(of: find.byType(RecommendationScreen), matching: find.text('Indomilk 1L')), findsWidgets);
      expect(find.text('Best Value'), findsWidgets);
    });

    testWidgets('Incompatible dimensions or invalid products are safely handled without crash', (WidgetTester tester) async {
      final badItems = [
        ScanResultItem(
          namaProduk: 'Valid Soda 1L',
          harga: 10000.0,
          ukuran: 1.0,
          satuan: 'l',
          kategori: 'Minuman',
          confidence: 'tinggi',
          needsVerification: false,
        ),
        ScanResultItem(
          namaProduk: 'Zero Price Soda',
          harga: 0.0,
          ukuran: 1.0,
          satuan: 'l',
          kategori: 'Minuman',
          confidence: 'tinggi',
          needsVerification: true,
        ),
        ScanResultItem(
          namaProduk: 'Incompatible weight 200g',
          harga: 8000.0,
          ukuran: 200.0,
          satuan: 'g',
          kategori: 'Minuman',
          confidence: 'tinggi',
          needsVerification: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            baseUrl: 'http://localhost:8000',
            detectedItems: badItems,
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap CTA to compute Best Value
      await tester.ensureVisible(find.byKey(const Key('best_value_cta_button')));
      await tester.tap(find.byKey(const Key('best_value_cta_button')));
      await tester.pumpAndSettle();

      // RecommendationScreen should load without crashing.
      expect(find.text('Best Value Recommendation'), findsOneWidget);
      expect(find.text('Minuman'), findsOneWidget);
      
      // Excluded products are rendered in details list
      expect(find.text('1 Produk Dikecualikan'), findsOneWidget);
    });
  });
}
