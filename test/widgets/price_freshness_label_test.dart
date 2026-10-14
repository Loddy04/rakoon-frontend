import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/widgets/price_freshness_label.dart';

void main() {
  group('PriceFreshnessLabel Widget & Formatter Tests', () {
    test('formatDate correctly parses ISO strings, DateTimes, and pre-formatted strings', () {
      expect(PriceFreshnessLabel.formatDate('2026-05-10T00:00:00Z'), '10 Mei 2026');
      expect(PriceFreshnessLabel.formatDate(DateTime(2026, 1, 15)), '15 Jan 2026');
      expect(PriceFreshnessLabel.formatDate('12 Jan 2026'), '12 Jan 2026');
      expect(PriceFreshnessLabel.formatDate(''), '');
      expect(PriceFreshnessLabel.formatDate(null), '');
    });

    testWidgets('Renders nothing (SizedBox.shrink) when isStale is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PriceFreshnessLabel(
              isStale: false,
              updatedAt: '2026-05-10T00:00:00Z',
            ),
          ),
        ),
      );

      expect(find.byType(PriceFreshnessLabel), findsOneWidget);
      expect(find.textContaining('Harga per'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('Renders "Harga per <tanggal>" badge when isStale is true with ISO string', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PriceFreshnessLabel(
              isStale: true,
              updatedAt: '2026-05-10T00:00:00Z',
            ),
          ),
        ),
      );

      expect(find.byType(PriceFreshnessLabel), findsOneWidget);
      expect(find.text('Harga per 10 Mei 2026'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('Renders "Harga per <tanggal>" when isStale is true with pre-formatted date string', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PriceFreshnessLabel(
              isStale: true,
              updatedAt: '12 Jan 2026',
            ),
          ),
        ),
      );

      expect(find.text('Harga per 12 Jan 2026'), findsOneWidget);
    });

    testWidgets('Renders fallback label when isStale is true but updatedAt is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PriceFreshnessLabel(
              isStale: true,
              updatedAt: null,
            ),
          ),
        ),
      );

      expect(find.text('Harga lama'), findsOneWidget);
    });

    testWidgets('Renders as plain text when isBadge is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PriceFreshnessLabel(
              isStale: true,
              updatedAt: '2026-05-10T00:00:00Z',
              isBadge: false,
            ),
          ),
        ),
      );

      expect(find.text('Harga per 10 Mei 2026'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsNothing);
    });
  });
}
