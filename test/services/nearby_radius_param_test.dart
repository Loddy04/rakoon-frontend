import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/price_check/data/datasources/price_check_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';

void main() {
  late List<Uri> seen;
  late MockClient client;

  setUp(() {
    seen = [];
    client = MockClient((req) async {
      seen.add(req.url);
      if (req.url.path.contains('/price/compare')) {
        return http.Response(
          '{"product_id":"p1","nama_produk":"X","comparison":[]}',
          200,
        );
      }
      return http.Response('{"stores":[],"message":null}', 200);
    });
  });

  test('nearby: tanpa radiusKm, radius_km tidak dikirim', () async {
    await StoresService.getNearbyStores(
        lat: -6.2, lng: 106.8, baseUrl: 'http://x', client: client);
    expect(seen.single.queryParameters.containsKey('radius_km'), isFalse);
  });

  test('nearby: dengan radiusKm, radius_km dikirim', () async {
    await StoresService.getNearbyStores(
        lat: -6.2, lng: 106.8, radiusKm: 15, baseUrl: 'http://x', client: client);
    expect(seen.single.queryParameters['radius_km'], '15.0');
  });

  test('price compare (PriceCheckService): radius_km hanya dikirim bila diisi', () async {
    await PriceCheckService.getPriceComparison(
        productId: 'p1', lat: -6.2, lng: 106.8, baseUrl: 'http://x', client: client);
    await PriceCheckService.getPriceComparison(
        productId: 'p1', lat: -6.2, lng: 106.8, radiusKm: 5, baseUrl: 'http://x', client: client);
    expect(seen[0].queryParameters.containsKey('radius_km'), isFalse);
    expect(seen[1].queryParameters['radius_km'], '5.0');
  });

  test('price compare (StoresService): radius_km hanya dikirim bila diisi', () async {
    await http.runWithClient(
      () => StoresService.getPriceComparison(
          productId: 'p1', lat: -6.2, lng: 106.8, baseUrl: 'http://x'),
      () => client,
    );
    expect(seen.single.queryParameters.containsKey('radius_km'), isFalse);
  });
}
