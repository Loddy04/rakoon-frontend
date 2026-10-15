import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/history/data/models/price_history_item.dart';
import 'package:rakoon_frontend/features/history/data/repositories/price_history_repository.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/price_history_page.dart';
import 'package:rakoon_frontend/features/history/presentation/providers/price_history_notifier.dart';

Map<String, dynamic> _entry(int i) => {
      'store_id': '10',
      'store_name': 'Indomaret',
      'price': 10000 + i,
      'recorded_at': DateTime.utc(2026, 1, 1).add(Duration(hours: i)).toIso8601String(),
    };

Future<void> _pump(WidgetTester tester, Map<String, dynamic> body) async {
  final client = MockClient((_) async => http.Response(jsonEncode(body), 200));
  final notifier = PriceHistoryNotifier(repository: PriceHistoryRepository(client: client));
  await tester.pumpWidget(MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)));
  await tester.pumpAndSettle();
}

void main() {
  group('PriceHistoryResponse total', () {
    test('parses total and never assumes it equals items.length', () {
      final res = PriceHistoryResponse.fromJson({
        'product_id': 1,
        'total': 250,
        'items': [_entry(0), _entry(1)],
        'trend': [],
      });
      expect(res.items.length, 2);
      expect(res.totalEntries, 250);
    });

    test('missing total falls back to items.length', () {
      final res = PriceHistoryResponse.fromJson({
        'product_id': 1,
        'items': [_entry(0), _entry(1)],
        'trend': [],
      });
      expect(res.totalEntries, 2);
    });
  });

  group('PriceHistoryPage truncation note', () {
    testWidgets('total 250 with 100 items shows the "newest entries" note', (tester) async {
      await _pump(tester, {
        'product_id': 1,
        'product_name': 'Susu UHT 1L',
        'total': 250,
        'items': [for (var i = 0; i < 100; i++) _entry(i)],
        'trend': [
          {'date': '2026-01-01', 'store_id': '10', 'price': 9000},
          {'date': '2026-01-05', 'store_id': '10', 'price': 10099},
        ],
      });
      expect(find.text('Menampilkan 100 entri terbaru dari 250', skipOffstage: false), findsOneWidget);
    });

    testWidgets('total equal to items hides the note', (tester) async {
      await _pump(tester, {
        'product_id': 1,
        'product_name': 'Susu UHT 1L',
        'total': 2,
        'items': [_entry(0), _entry(1)],
        'trend': [],
      });
      expect(find.textContaining('Menampilkan', skipOffstage: false), findsNothing);
    });

    testWidgets('missing total hides the note', (tester) async {
      await _pump(tester, {
        'product_id': 1,
        'product_name': 'Susu UHT 1L',
        'items': [_entry(0), _entry(1)],
        'trend': [],
      });
      expect(find.textContaining('Menampilkan', skipOffstage: false), findsNothing);
    });
  });

  group('ProductHeaderCard trend', () {
    testWidgets('direction comes from backend trend, not from the visible items', (tester) async {
      // Items rise (10000 -> 12000) but the backend trend over ALL entries falls.
      await _pump(tester, {
        'product_id': 1,
        'product_name': 'Susu UHT 1L',
        'total': 250,
        'items': [_entry(0), _entry(2000)],
        'trend': [
          {'date': '2025-06-01', 'store_id': '10', 'price': 15000},
          {'date': '2026-01-05', 'store_id': '10', 'price': 12000},
        ],
      });
      expect(find.text('Harga turun'), findsOneWidget);
      expect(find.text('Harga naik'), findsNothing);
    });
  });
}
