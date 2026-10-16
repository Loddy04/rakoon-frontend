import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/price_check/data/datasources/price_check_service.dart';
import 'package:rakoon_frontend/features/price_check/data/models/product_catalog_model.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';

const _base = 'http://localhost:8000';

http.Response _ok(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

void main() {
  group('CatalogProduct.jarakKm', () {
    test('parses jarak_km, missing or null = null', () {
      final base = {'id': 'p1', 'nama': 'Susu', 'kategori': 'Minuman'};
      expect(CatalogProduct.fromJson({...base, 'jarak_km': 0.8}).jarakKm, 0.8);
      expect(CatalogProduct.fromJson({...base, 'jarak_km': 2}).jarakKm, 2.0);
      expect(CatalogProduct.fromJson({...base, 'jarak_km': null}).jarakKm, isNull);
      expect(CatalogProduct.fromJson(base).jarakKm, isNull);
    });
  });

  group('catalog request sends lat/lng only when the location is known', () {
    Future<Uri> catalogUri({double? lat, double? lng}) async {
      late Uri uri;
      final client = MockClient((request) async {
        uri = request.url;
        return _ok([]);
      });
      await PriceCheckService.getCatalogProducts(baseUrl: _base, client: client, lat: lat, lng: lng);
      return uri;
    }

    test('both present -> sent', () async {
      final uri = await catalogUri(lat: -7.78, lng: 110.4);
      expect(uri.queryParameters['lat'], '-7.78');
      expect(uri.queryParameters['lng'], '110.4');
    });

    test('none or only one -> neither is sent', () async {
      for (final uri in [
        await catalogUri(),
        await catalogUri(lat: -7.78),
        await catalogUri(lng: 110.4),
      ]) {
        expect(uri.queryParameters.containsKey('lat'), isFalse);
        expect(uri.queryParameters.containsKey('lng'), isFalse);
      }
    });
  });

  group('PriceCheckProvider location', () {
    test('fetch and loadMore carry the location; clearing it stops sending', () async {
      final seen = <Map<String, String>>[];
      final client = MockClient((request) async {
        seen.add(request.url.queryParameters);
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        return _ok([
          for (var i = offset; i < offset + 100; i++)
            {'id': 'p$i', 'nama': 'P$i', 'kategori': 'Minuman', 'jarak_km': 0.8},
        ]);
      });
      final provider = PriceCheckProvider();

      provider.setUserLocation(-7.78, 110.4);
      await provider.fetchCatalog(baseUrl: _base, client: client);
      await provider.loadMore(baseUrl: _base, client: client);
      expect(seen[0]['lat'], '-7.78');
      expect(seen[1]['lat'], '-7.78');
      expect(seen[1]['offset'], '100');
      expect(provider.products.first.jarakKm, 0.8);

      provider.setUserLocation(null, null);
      await provider.fetchCatalog(baseUrl: _base, client: client);
      expect(seen[2].containsKey('lat'), isFalse);
      expect(seen[2].containsKey('lng'), isFalse);
    });

    test('offline still surfaces the friendly error', () async {
      final client = MockClient((request) async => throw http.ClientException('offline'));
      final provider = PriceCheckProvider();
      provider.setUserLocation(-7.78, 110.4);
      await provider.fetchCatalog(baseUrl: _base, client: client);
      expect(provider.status, PriceCheckStatus.error);
      expect(provider.errorMessage, isNotNull);
    });
  });
}
