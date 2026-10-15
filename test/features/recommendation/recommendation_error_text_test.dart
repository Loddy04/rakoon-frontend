import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/recommendation/recommendation_screen.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

void main() {
  testWidgets('an unexpected exception shows the generic message with Coba Lagi, never the technical text', (tester) async {
    // A 200 with an unparsable body makes jsonDecode throw a raw FormatException.
    final client = MockClient((_) async => http.Response('<html>FormatException at http://db.internal</html>', 200));
    await tester.pumpWidget(MaterialApp(
      home: RecommendationScreen(
        baseUrl: 'http://localhost:8000',
        httpClient: client,
        initialCandidates: [
          RecommendationCandidate(
            productId: 'item-1',
            namaProduk: 'Minyak Filma 2L',
            harga: 36000.0,
            ukuran: 2.0,
            satuan: 'L',
            kategori: 'Makanan Pokok',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Terjadi kesalahan, coba lagi'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('http://'), findsNothing);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });
}
