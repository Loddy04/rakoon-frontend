import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

const _base = 'http://localhost:8000';

final _failures = <String, Object Function()>{
  'SocketException': () => const SocketException('Failed host lookup: secret.host'),
  'TimeoutException': () => TimeoutException('slow'),
};

Map<String, dynamic> _row(int i) => {
      'id': 'p$i',
      'nama': 'Produk $i',
      'kategori': 'Makanan Pokok',
      'harga_terendah': 1000.0 + i,
      'nama_toko_terendah': 'Toko',
      'jumlah_toko': 1,
    };

void main() {
  group('PriceCheckProvider messages', () {
    for (final failure in _failures.entries) {
      test('${failure.key}: catalog error is the offline message', () async {
        final provider = PriceCheckProvider();
        await provider.fetchCatalog(baseUrl: _base, client: MockClient((_) async => throw failure.value()));
        expect(provider.status, PriceCheckStatus.error);
        expect(provider.errorMessage, noConnectionMessage);
      });

      test('${failure.key}: a failed next page keeps the list and shows the offline message', () async {
        var calls = 0;
        final client = MockClient((request) async {
          if (calls++ == 0) {
            return http.Response(jsonEncode([for (var i = 0; i < 100; i++) _row(i)]), 200);
          }
          throw failure.value();
        });
        final provider = PriceCheckProvider();
        await provider.fetchCatalog(baseUrl: _base, client: client);
        await provider.loadMore(baseUrl: _base, client: client);
        expect(provider.products.length, 100);
        expect(provider.loadMoreError, noConnectionMessage);
      });

      test('${failure.key}: detail error is the offline message', () async {
        final provider = PriceCheckProvider();
        await provider.fetchProductDetail(
          productId: 'p1',
          userLat: -7.7,
          userLng: 110.4,
          baseUrl: _base,
          client: MockClient((_) async => throw failure.value()),
        );
        expect(provider.detailStatus, PriceCheckStatus.error);
        expect(provider.detailErrorMessage, noConnectionMessage);
      });
    }

    test('HTTP 503 gives the server message, never the body; unknown errors stay generic', () async {
      final provider = PriceCheckProvider();
      await provider.fetchCatalog(baseUrl: _base, client: MockClient((_) async => http.Response('psycopg2 secret', 503)));
      expect(provider.errorMessage, serverErrorMessage);

      await provider.fetchCatalog(baseUrl: _base, client: MockClient((_) async => http.Response('boom', 400)));
      expect(provider.errorMessage, isNot(contains('boom')));
      expect(provider.errorMessage, isNotEmpty);
    });
  });

  group('Catalog page', () {
    for (final failure in _failures.entries) {
      testWidgets('${failure.key}: shows the offline message and a Coba lagi button that retries', (tester) async {
        await mockNetworkImagesFor(() async {
          var online = false;
          var calls = 0;
          final client = MockClient((request) async {
            calls++;
            if (!online) throw failure.value();
            return http.Response(jsonEncode([_row(1)]), 200);
          });

          await tester.pumpWidget(MaterialApp(home: PriceCheckCatalogPage(baseUrl: _base, httpClient: client)));
          await tester.pumpAndSettle();

          expect(find.text(noConnectionMessage), findsOneWidget);
          expect(find.byKey(const Key('retry_catalog_button')), findsOneWidget);
          expect(find.textContaining('secret.host'), findsNothing);

          online = true;
          await tester.tap(find.byKey(const Key('retry_catalog_button')));
          await tester.pumpAndSettle();

          expect(calls, 2);
          expect(find.text(noConnectionMessage), findsNothing);
          expect(find.textContaining('Produk 1'), findsWidgets);
        });
      });
    }
  });

  group('Product detail page', () {
    testWidgets('offline shows the offline message and the retry button', (tester) async {
      await mockNetworkImagesFor(() async {
        final product = RecommendedProduct(
          id: 'p1',
          nama: 'INDOMIE GORENG 85G',
          kategori: 'Makanan Instan',
          harga: 3100,
          ukuran: 85,
          satuan: 'g',
          namaToko: 'Toko Terdekat',
          jarakKm: null,
          updatedAt: 'baru saja',
          fotoUrl: null,
        );
        final client = MockClient((_) async => throw const SocketException('Failed host lookup'));

        await tester.pumpWidget(MaterialApp(
          home: UnifiedProductPriceDetailPage(product: product, baseUrl: _base, httpClient: client),
        ));
        await tester.pumpAndSettle();

        expect(find.text(noConnectionMessage), findsOneWidget);
        expect(find.byKey(const Key('retry_detail_button')), findsOneWidget);
      });
    });
  });
}
