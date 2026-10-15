import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';

const _friendly = 'Lokasi atau jumlah data tidak valid, coba lagi';
const _rawBody = '{"detail":[{"loc":["query","radius_km"],"msg":"ensure this value is less than or equal to 100"}]}';

MockClient get _client422 => MockClient((_) async => http.Response(_rawBody, 422));

Matcher get _friendlyError => isA<InvalidRequestException>()
    .having((e) => e.message, 'message', _friendly)
    .having((e) => e.toString(), 'toString', _friendly);

void main() {
  test('nearby stores: 422 gives the friendly message, no raw body', () async {
    await expectLater(
      StoresService.getNearbyStores(
        lat: 95,
        lng: 110,
        baseUrl: 'http://localhost:8000',
        client: _client422,
      ),
      throwsA(_friendlyError),
    );
  });

  test('price compare: 422 gives the friendly message, no raw body', () async {
    await expectLater(
      http.runWithClient(
        () => StoresService.getPriceComparison(
          productId: 'p1',
          lat: -7.7,
          lng: 110.4,
          radiusKm: 500,
          baseUrl: 'http://localhost:8000',
        ),
        () => _client422,
      ),
      throwsA(_friendlyError),
    );
  });

  test('recommended products: 422 surfaces the friendly message instead of the mock fallback', () async {
    await expectLater(
      RecommendationService.getRecommendedProducts(
        baseUrl: 'http://localhost:8000',
        lat: -7.7,
        lng: 110.4,
        limit: 500,
        client: _client422,
      ),
      throwsA(_friendlyError),
    );
  });
}
