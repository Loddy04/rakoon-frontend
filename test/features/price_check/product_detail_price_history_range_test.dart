import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

void main() {
  final testProduct = RecommendedProduct(
    id: 'prod-001',
    nama: 'Bimoli Minyak Goreng 2L',
    kategori: 'Makanan Pokok',
    harga: 35000.0,
    namaToko: 'Super Indo Babarsari',
    jarakKm: 1.2,
    updatedAt: '2026-10-10T00:00:00Z',
  );

  Map<String, dynamic> makeComparisonJson() => {
        'product_id': 'prod-001',
        'nama_produk': 'Bimoli Minyak Goreng 2L',
        'comparison': [
          {
            'store_id': 's1',
            'nama_toko': 'Super Indo Babarsari',
            'lat': -7.78,
            'lng': 110.40,
            'jarak_km': 1.2,
            'harga_terbaru': 35000,
            'tanggal_update': '2026-10-10T00:00:00Z',
          },
          {
            'store_id': 's2',
            'nama_toko': 'Indomaret Babarsari',
            'lat': -7.77,
            'lng': 110.41,
            'jarak_km': 1.8,
            'harga_terbaru': 36500,
            'tanggal_update': '2026-10-09T00:00:00Z',
          },
        ],
      };

  group('Riwayat Harga Range Selection Tests (Tugas 1, 2, 3)', () {
    testWidgets('30 hari kosong + 3 bulan berisi -> "3 Bulan" aktif otomatis dan catatan tampil', (tester) async {
      final requestedRanges = <String>[];

      final client = MockClient((request) async {
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode(makeComparisonJson()), 200);
        }
        if (request.url.path.contains('price-history')) {
          final range = request.url.queryParameters['range'] ?? '1m';
          requestedRanges.add(range);
          if (range == '1m') {
            return http.Response(
              jsonEncode({
                'product_id': 'prod-001',
                'product_name': 'Bimoli Minyak Goreng 2L',
                'items': [],
                'trend': [],
                'total': 0,
              }),
              200,
            );
          } else if (range == '3m') {
            return http.Response(
              jsonEncode({
                'product_id': 'prod-001',
                'product_name': 'Bimoli Minyak Goreng 2L',
                'items': [
                  {
                    'id': 'h1',
                    'product_id': 'prod-001',
                    'store_id': 's1',
                    'store_name': 'Super Indo Babarsari',
                    'price': 34000.0,
                    'created_at': '2026-08-15T00:00:00Z',
                  },
                  {
                    'id': 'h2',
                    'product_id': 'prod-001',
                    'store_id': 's1',
                    'store_name': 'Super Indo Babarsari',
                    'price': 35000.0,
                    'created_at': '2026-09-20T00:00:00Z',
                  },
                ],
                'trend': [
                  {
                    'date': '2026-08-15',
                    'price': 34000.0,
                    'store_id': 's1',
                  },
                  {
                    'date': '2026-09-20',
                    'price': 35000.0,
                    'store_id': 's1',
                  },
                ],
                'total': 2,
              }),
              200,
            );
          }
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: testProduct,
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verification: 3 Bulan must be automatically selected and note displayed
      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsOneWidget);
      expect(find.text('Belum ada data riwayat harga'), findsNothing);
      expect(requestedRanges, contains('3m'));
      expect(find.text('3 Bulan'), findsOneWidget);
    });

    testWidgets('30 hari berisi -> "30 Hari" aktif, tanpa catatan', (tester) async {
      final requestedRanges = <String>[];

      final client = MockClient((request) async {
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode(makeComparisonJson()), 200);
        }
        if (request.url.path.contains('price-history')) {
          final range = request.url.queryParameters['range'] ?? '1m';
          requestedRanges.add(range);
          return http.Response(
            jsonEncode({
              'product_id': 'prod-001',
              'product_name': 'Bimoli Minyak Goreng 2L',
              'items': [],
              'trend': [
                {'date': '2026-10-01', 'price': 35000.0, 'store_id': 's1'},
                {'date': '2026-10-05', 'price': 36000.0, 'store_id': 's1'},
              ],
              'total': 2,
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: testProduct,
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verification: 30 Hari default remains active, no note displayed, 3m was not fetched
      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsNothing);
      expect(find.text('Belum ada data riwayat harga'), findsNothing);
      expect(requestedRanges, ['1m']);
    });

    testWidgets('keduanya kosong -> keadaan kosong ditampilkan tanpa catatan', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode(makeComparisonJson()), 200);
        }
        if (request.url.path.contains('price-history')) {
          return http.Response(
            jsonEncode({
              'product_id': 'prod-001',
              'product_name': 'Bimoli Minyak Goreng 2L',
              'items': [],
              'trend': [],
              'total': 0,
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: testProduct,
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verification: empty state rendered, no note
      expect(find.text('Belum ada data riwayat harga'), findsOneWidget);
      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsNothing);
    });

    testWidgets('setelah pengguna memilih "30 Hari" manual -> tidak berpindah otomatis dan catatan hilang', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode(makeComparisonJson()), 200);
        }
        if (request.url.path.contains('price-history')) {
          final range = request.url.queryParameters['range'] ?? '1m';
          if (range == '1m') {
            return http.Response(
              jsonEncode({
                'product_id': 'prod-001',
                'items': [],
                'trend': [],
              }),
              200,
            );
          } else {
            return http.Response(
              jsonEncode({
                'product_id': 'prod-001',
                'items': [],
                'trend': [
                  {'date': '2026-08-15', 'price': 34000.0, 'store_id': 's1'},
                ],
              }),
              200,
            );
          }
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: testProduct,
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially auto-selected to 3 Bulan with note
      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsOneWidget);

      // User manually taps "30 Hari"
      await tester.tap(find.text('30 Hari'));
      await tester.pumpAndSettle();

      // Now manual choice wins: 30 Hari selected, empty state shown, note is gone
      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsNothing);
      expect(find.text('Belum ada data riwayat harga'), findsOneWidget);
    });

    testWidgets('berganti toko tidak mengacaukan pilihan rentang', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode(makeComparisonJson()), 200);
        }
        if (request.url.path.contains('price-history')) {
          final range = request.url.queryParameters['range'] ?? '1m';
          if (range == '1m') {
            return http.Response(jsonEncode({'product_id': 'prod-001', 'trend': []}), 200);
          } else {
            return http.Response(
              jsonEncode({
                'product_id': 'prod-001',
                'trend': [
                  {'date': '2026-08-15', 'price': 34000.0, 'store_id': 's1'},
                  {'date': '2026-08-20', 'price': 36500.0, 'store_id': 's2'},
                ],
              }),
              200,
            );
          }
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: testProduct,
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsOneWidget);

      // Tap on specific store chip "Super Indo Babarsari"
      await tester.tap(find.text('Super Indo Babarsari').first);
      await tester.pumpAndSettle();

      // Range choice must still be 3m and note still visible
      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsOneWidget);
      expect(find.text('Belum ada data riwayat harga'), findsNothing);

      // Tap back to "Semua Toko"
      await tester.tap(find.text('Semua Toko'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsOneWidget);
    });

    testWidgets('Tugas 3: tombol rentang memiliki target sentuh >= 48dp', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode(makeComparisonJson()), 200);
        }
        return http.Response(jsonEncode({'product_id': 'prod-001', 'trend': []}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: testProduct,
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btn1m = find.byKey(const Key('range_button_1m'));
      final btn3m = find.byKey(const Key('range_button_3m'));

      expect(btn1m, findsOneWidget);
      expect(btn3m, findsOneWidget);

      final size1m = tester.getSize(btn1m);
      final size3m = tester.getSize(btn3m);

      expect(size1m.width, greaterThanOrEqualTo(48.0));
      expect(size1m.height, greaterThanOrEqualTo(48.0));
      expect(size3m.width, greaterThanOrEqualTo(48.0));
      expect(size3m.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Tugas 3: seksi Riwayat Harga responsive di 320dp tanpa overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockClient((request) async {
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode(makeComparisonJson()), 200);
        }
        if (request.url.path.contains('price-history')) {
          final range = request.url.queryParameters['range'] ?? '1m';
          if (range == '1m') {
            return http.Response(jsonEncode({'product_id': 'prod-001', 'trend': []}), 200);
          } else {
            return http.Response(
              jsonEncode({
                'product_id': 'prod-001',
                'trend': [
                  {'date': '2026-08-15', 'price': 34000.0, 'store_id': 's1'},
                  {'date': '2026-09-15', 'price': 35000.0, 'store_id': 's1'},
                ],
              }),
              200,
            );
          }
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: testProduct,
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Belum ada pembaruan 30 hari terakhir.'), findsOneWidget);
    });
  });
}
