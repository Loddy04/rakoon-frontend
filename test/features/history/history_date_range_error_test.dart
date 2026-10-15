import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/history/data/repositories/price_history_repository.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/price_history_page.dart';
import 'package:rakoon_frontend/features/history/presentation/providers/price_history_notifier.dart';

const _friendly = 'Rentang tanggal tidak valid, pastikan tanggal mulai sebelum tanggal akhir';
const _rawBody = '{"detail":"start_date must be on or before end_date"}';

void main() {
  test('repository maps 400 to a friendly message without the raw body', () async {
    final repo = PriceHistoryRepository(
      client: MockClient((_) async => http.Response(_rawBody, 400)),
    );

    await expectLater(
      repo.getPriceHistory(productId: 1, range: 'all'),
      throwsA(
        isA<PriceHistoryApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', _friendly),
      ),
    );
  });

  testWidgets('page shows the friendly range message and never the raw body', (tester) async {
    final notifier = PriceHistoryNotifier(
      repository: PriceHistoryRepository(
        client: MockClient((_) async => http.Response(_rawBody, 400)),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)));
    await tester.pumpAndSettle();

    expect(find.text(_friendly), findsOneWidget);
    expect(find.textContaining('start_date'), findsNothing);
  });
}
