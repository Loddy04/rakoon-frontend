import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';

const _base = 'http://localhost:8000';

Map<String, dynamic> _item(int i) => {
      'id': 'p$i',
      'nama': 'Produk $i',
      'kategori': 'Makanan Pokok',
      'harga_terendah': 1000.0 + i,
      'nama_toko_terendah': 'Toko',
      'jumlah_toko': 1,
    };

/// Simulates /products/catalog with [total] rows, honouring limit and offset.
http.Response _page(http.Request request, int total) {
  final limit = int.parse(request.url.queryParameters['limit'] ?? '100');
  final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
  final end = (offset + limit) > total ? total : offset + limit;
  final rows = [for (var i = offset; i < end; i++) _item(i)];
  return http.Response(jsonEncode(rows), 200, headers: {'content-type': 'application/json'});
}

void main() {
  group('Catalog infinite scroll (provider)', () {
    test('151 items load fully over two pages and stop after the short page', () async {
      final offsets = <String>[];
      final client = MockClient((request) async {
        offsets.add(request.url.queryParameters['offset'] ?? '0');
        return _page(request, 151);
      });
      final provider = PriceCheckProvider();

      await provider.fetchCatalog(baseUrl: _base, client: client);
      expect(provider.products.length, 100);
      expect(provider.hasMore, isTrue);

      await provider.loadMore(baseUrl: _base, client: client);
      expect(provider.products.length, 151);
      expect(provider.hasMore, isFalse);
      expect(provider.products.map((p) => p.id).toSet().length, 151);

      await provider.loadMore(baseUrl: _base, client: client);
      expect(offsets, ['0', '100']);
    });

    test('an empty next page stops further loading', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _page(request, 100);
      });
      final provider = PriceCheckProvider();

      await provider.fetchCatalog(baseUrl: _base, client: client);
      expect(provider.hasMore, isTrue);

      await provider.loadMore(baseUrl: _base, client: client);
      expect(provider.products.length, 100);
      expect(provider.hasMore, isFalse);

      await provider.loadMore(baseUrl: _base, client: client);
      expect(calls, 2);
    });

    test('a second loadMore while one is in flight sends no extra request', () async {
      final gate = Completer<void>();
      var nextPageCalls = 0;
      final client = MockClient((request) async {
        if (request.url.queryParameters['offset'] == '100') {
          nextPageCalls++;
          await gate.future;
        }
        return _page(request, 151);
      });
      final provider = PriceCheckProvider();
      await provider.fetchCatalog(baseUrl: _base, client: client);

      final Future<void> first = provider.loadMore(baseUrl: _base, client: client);
      final Future<void> second = provider.loadMore(baseUrl: _base, client: client);
      expect(provider.isLoadingMore, isTrue);
      gate.complete();
      await Future.wait([first, second]);

      expect(nextPageCalls, 1);
      expect(provider.products.length, 151);
    });

    test('failing page 2 keeps page 1, sets a friendly error, and retry succeeds', () async {
      var failNext = true;
      final client = MockClient((request) async {
        if (request.url.queryParameters['offset'] == '100' && failNext) {
          return http.Response('{"detail":"boom internal"}', 500);
        }
        return _page(request, 151);
      });
      final provider = PriceCheckProvider();
      await provider.fetchCatalog(baseUrl: _base, client: client);

      await provider.loadMore(baseUrl: _base, client: client);
      expect(provider.products.length, 100);
      expect(provider.status, PriceCheckStatus.success);
      expect(provider.loadMoreError, isNotNull);
      expect(provider.loadMoreError, isNot(contains('boom')));
      expect(provider.hasMore, isTrue);

      failNext = false;
      await provider.loadMore(baseUrl: _base, client: client);
      expect(provider.products.length, 151);
      expect(provider.loadMoreError, isNull);
    });

    test('a new search resets the offset and replaces the list', () async {
      final seen = <Map<String, String>>[];
      final client = MockClient((request) async {
        seen.add(request.url.queryParameters);
        return _page(request, request.url.queryParameters['search'] == 'susu' ? 3 : 151);
      });
      final provider = PriceCheckProvider();
      await provider.fetchCatalog(baseUrl: _base, client: client);
      await provider.loadMore(baseUrl: _base, client: client);
      expect(provider.products.length, 151);

      await provider.fetchCatalog(search: 'susu', baseUrl: _base, client: client);
      expect(seen.last['offset'] ?? '0', '0');
      expect(provider.products.length, 3);
      expect(provider.hasMore, isFalse);
    });
  });

  group('Catalog infinite scroll (page)', () {
    testWidgets('scrolling to the end loads the next page', (tester) async {
      final client = MockClient((request) async => _page(request, 151));
      await tester.pumpWidget(
        MaterialApp(home: PriceCheckCatalogPage(baseUrl: _base, httpClient: client)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Produk 150'), findsNothing);

      for (var i = 0; i < 3; i++) {
        await tester.fling(find.byType(CustomScrollView), const Offset(0, -20000), 8000);
        await tester.pumpAndSettle();
      }

      // The last of 151 rows is only reachable once page 2 (offset 100) has loaded.
      expect(find.text('Produk 150'), findsOneWidget);
    });

    testWidgets('failed next page shows a friendly message and retry, keeping loaded items', (tester) async {
      var failNext = true;
      final client = MockClient((request) async {
        if (request.url.queryParameters['offset'] == '100' && failNext) {
          return http.Response('{"detail":"boom internal"}', 500);
        }
        return _page(request, 151);
      });
      await tester.pumpWidget(
        MaterialApp(home: PriceCheckCatalogPage(baseUrl: _base, httpClient: client)),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.fling(find.byType(CustomScrollView), const Offset(0, -20000), 8000);
        await tester.pumpAndSettle();
      }

      expect(find.text('Produk 99', skipOffstage: false), findsOneWidget); // page 1 still shown
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text('Coba lagi'), findsOneWidget);

      failNext = false;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Coba lagi'), findsNothing);
      await tester.fling(find.byType(CustomScrollView), const Offset(0, -20000), 8000);
      await tester.pumpAndSettle();
      expect(find.text('Produk 150'), findsOneWidget);
    });
  });
}
