import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';

const _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

Map<String, dynamic> _item(int i) => {
      'id': 'p$i',
      'nama': 'Produk $i',
      'kategori': 'Makanan Pokok',
      'harga': 1000.0 + i,
      'updated_at': '2026-10-10T00:00:00Z',
      'stale': false,
    };

/// Mock backend: one store, [total] products, honouring limit/offset.
/// [onProducts] can short-circuit a products request (fail / delay).
MockClient _client(
  int total, {
  List<String>? offsets,
  Future<http.Response?> Function(int offset)? onProducts,
}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/stores/nearby')) {
      return http.Response(
        jsonEncode({
          'source': 'osm',
          'stores': [
            {'store_id': 'store-1', 'nama': 'Indomaret Sudirman', 'lat': -6.2088, 'lng': 106.8456, 'jarak_km': 1.2},
          ],
        }),
        200,
      );
    }
    if (path.contains('/stores/') && path.endsWith('/products')) {
      final limit = int.parse(request.url.queryParameters['limit'] ?? '100');
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      offsets?.add('$offset');
      final override = await onProducts?.call(offset);
      if (override != null) return override;
      final end = (offset + limit) > total ? total : offset + limit;
      return http.Response(
        jsonEncode([for (var i = offset; i < end; i++) _item(i)]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.host.contains('openstreetmap.org') || path.endsWith('.png')) {
      return http.Response.bytes(_png, 200, headers: {'content-type': 'image/png'});
    }
    return http.Response('Not Found', 404);
  });
}

Future<void> _openSheet(WidgetTester tester, http.Client client) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NearbyStoresScreen(
        baseUrl: 'http://localhost:8000',
        initialLat: -6.2088,
        initialLng: 106.8456,
        httpClient: client,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Indomaret Sudirman'));
  await tester.pumpAndSettle();
}

Future<void> _scrollSheetToEnd(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(SingleChildScrollView),
  );
  for (var i = 0; i < 3; i++) {
    await tester.fling(scrollable, const Offset(0, -30000), 8000);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('151 store products load fully over two pages', (tester) async {
    final offsets = <String>[];
    await mockNetworkImagesFor(() async {
      await _openSheet(tester, _client(151, offsets: offsets));
      expect(find.text('Produk 99', skipOffstage: false), findsOneWidget);
      expect(find.text('Produk 100', skipOffstage: false), findsNothing);

      await _scrollSheetToEnd(tester);

      expect(find.text('Produk 150', skipOffstage: false), findsOneWidget);
      expect(offsets, ['0', '100']);
    });
  });

  testWidgets('a short or empty next page stops further requests', (tester) async {
    final offsets = <String>[];
    await mockNetworkImagesFor(() async {
      await _openSheet(tester, _client(100, offsets: offsets));
      await _scrollSheetToEnd(tester);
      await _scrollSheetToEnd(tester);

      expect(offsets, ['0', '100']);
      expect(find.text('Produk 99', skipOffstage: false), findsOneWidget);
    });
  });

  testWidgets('repeated scroll events while a page is loading send one request', (tester) async {
    final gate = Completer<void>();
    final offsets = <String>[];
    await mockNetworkImagesFor(() async {
      await _openSheet(
        tester,
        _client(151, offsets: offsets, onProducts: (offset) async {
          if (offset == 100) await gate.future;
          return null;
        }),
      );

      final scrollable = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SingleChildScrollView),
      );
      for (var i = 0; i < 4; i++) {
        await tester.fling(scrollable, const Offset(0, -30000), 8000);
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(offsets.where((o) => o == '100').length, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(offsets.where((o) => o == '100').length, 1);
    });
  });

  testWidgets('failed page 2 keeps page 1, shows a friendly message and retry works', (tester) async {
    var fail = true;
    await mockNetworkImagesFor(() async {
      await _openSheet(
        tester,
        _client(151, onProducts: (offset) async {
          if (offset == 100 && fail) return http.Response('{"detail":"boom internal"}', 500);
          return null;
        }),
      );

      await _scrollSheetToEnd(tester);

      expect(find.text('Produk 99', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text('Coba lagi', skipOffstage: false), findsOneWidget);

      fail = false;
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Coba lagi', skipOffstage: false), findsNothing);
      expect(find.text('Produk 150', skipOffstage: false), findsOneWidget);
    });
  });
}
