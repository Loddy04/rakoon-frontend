import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/price_check/data/datasources/price_check_service.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';

const _base = 'http://localhost:8000';

typedef _Call = Future<Object?> Function(http.Client client);

final Map<String, _Call> _calls = {
  'catalog (first page)': (c) => PriceCheckService.getCatalogProducts(baseUrl: _base, client: c),
  'catalog (next page)': (c) => PriceCheckService.getCatalogProducts(baseUrl: _base, offset: 100, client: c),
  'price history': (c) => PriceCheckService.getPriceHistory(productId: 'p1', baseUrl: _base, client: c),
  'price compare (catalog)': (c) => PriceCheckService.getPriceComparison(productId: 'p1', lat: -7.7, lng: 110.4, baseUrl: _base, client: c),
  'nearby stores': (c) => StoresService.getNearbyStores(lat: -7.7, lng: 110.4, baseUrl: _base, client: c),
  'price compare (stores)': (c) => http.runWithClient(
        () => StoresService.getPriceComparison(productId: 'p1', lat: -7.7, lng: 110.4, baseUrl: _base),
        () => c,
      ),
  'store products (first page)': (c) => StoresService.getStoreProducts(storeId: 's1', baseUrl: _base, client: c),
  'store products (next page)': (c) => StoresService.getStoreProducts(storeId: 's1', baseUrl: _base, offset: 100, client: c),
  'budget shopping': (c) => http.runWithClient(
        () => BudgetShoppingService.evaluateBudgetShopping(
          baseUrl: _base,
          request: BudgetRecommendRequest(budget: 50000, items: [BudgetItemInput(productId: 'p1', qty: 1)]),
        ),
        () => c,
      ),
  'evaluate recommendation': (c) => RecommendationService.evaluateRecommendation(candidates: const [], baseUrl: _base, client: c),
  'recommended products': (c) => RecommendationService.getRecommendedProducts(baseUrl: _base, client: c),
};

void main() {
  final failures = <String, Object Function()>{
    'SocketException': () => const SocketException('Failed host lookup: secret.host'),
    'TimeoutException': () => TimeoutException('slow'),
    'ClientException': () => http.ClientException('Connection closed'),
  };

  for (final call in _calls.entries) {
    for (final failure in failures.entries) {
      test('${call.key}: ${failure.key} gives NoConnectionException', () async {
        final client = MockClient((_) async => throw failure.value());
        await expectLater(
          call.value(client),
          throwsA(isA<NoConnectionException>().having((e) => e.toString(), 'message', noConnectionMessage)),
        );
      });
    }

    test('${call.key}: HTTP 503 gives ServerErrorException without the body', () async {
      final client = MockClient((_) async => http.Response('psycopg2 secret', 503));
      await expectLater(
        call.value(client),
        throwsA(isA<ServerErrorException>().having((e) => e.toString(), 'message', serverErrorMessage)),
      );
    });
  }
}
