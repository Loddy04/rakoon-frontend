import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

void main() {
  testWidgets('Store row without distance omits distance and separator, and null price shows Tidak tersedia', (tester) async {
    final mockClient = MockClient((request) async {
      final headers = {'content-type': 'application/json'};
      if (request.url.path.contains('/price/compare/')) {
        return http.Response(
          jsonEncode({
            'product_id': 'prod-001',
            'nama_produk': 'Indomie Goreng',
            'comparison': [
              {
                'store_id': 's1',
                'nama_toko': 'Toko Tanpa Jarak',
                'jarak_km': null,
                'harga_terbaru': null,
              },
              {
                'store_id': 's2',
                'nama_toko': 'Toko Berjarak',
                'jarak_km': 1.5,
                'harga_terbaru': 3500,
              },
            ],
          }),
          200,
          headers: headers,
        );
      }
      if (request.url.path.contains('price-history')) {
        return http.Response(
          jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
          200,
          headers: headers,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedProductPriceDetailPage(
          product: RecommendedProduct(
            id: 'prod-001',
            nama: 'Indomie Goreng',
            kategori: 'Makanan Instan',
            harga: 3500.0,
            namaToko: 'Toko Berjarak',
            updatedAt: '2026-10-10T00:00:00Z',
          ),
          baseUrl: 'http://localhost:8000',
          httpClient: mockClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verification 1: Store row without distance must NOT contain "Supermarket terdekat"
    expect(find.textContaining('Supermarket terdekat'), findsNothing);

    // Verification 2: Store row without distance must not leave trailing " · "
    expect(find.textContaining('Toko Tanpa Jarak ·'), findsNothing);
    expect(find.text('Toko Tanpa Jarak'), findsWidgets);

    // Verification 3: Store row with distance formatted as "{nama_toko} · {jarak}"
    expect(find.text('Toko Berjarak · 1.5 km'), findsOneWidget);

    // Verification 4: Empty price displays "Tidak tersedia" instead of "N/A"
    expect(find.text('N/A'), findsNothing);
    expect(find.text('Tidak tersedia'), findsOneWidget);

    // Verification 5: Back button has tooltip "Kembali"
    expect(find.byTooltip('Kembali'), findsOneWidget);
  });

  testWidgets('Chip Rute touch target size is at least 48x48', (tester) async {
    final mockClient = MockClient((request) async {
      final headers = {'content-type': 'application/json'};
      if (request.url.path.contains('/price/compare/')) {
        return http.Response(
          jsonEncode({
            'product_id': 'prod-001',
            'nama_produk': 'Indomie Goreng',
            'comparison': [
              {
                'store_id': 's1',
                'nama_toko': 'Toko Berjarak',
                'lat': -7.78,
                'lng': 110.40,
                'jarak_km': 1.5,
                'harga_terbaru': 3500,
              },
            ],
          }),
          200,
          headers: headers,
        );
      }
      if (request.url.path.contains('price-history')) {
        return http.Response(
          jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
          200,
          headers: headers,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedProductPriceDetailPage(
          product: RecommendedProduct(
            id: 'prod-001',
            nama: 'Indomie Goreng',
            kategori: 'Makanan Instan',
            harga: 3500.0,
            namaToko: 'Toko Berjarak',
            updatedAt: '2026-10-10T00:00:00Z',
          ),
          baseUrl: 'http://localhost:8000',
          httpClient: mockClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ruteGestureFinder = find.ancestor(
      of: find.text('Rute'),
      matching: find.byType(GestureDetector),
    );
    expect(ruteGestureFinder, findsOneWidget);
    final size = tester.getSize(ruteGestureFinder);
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });
}
