import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_history_screen.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_session_detail_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  });
  tearDown(() => AuthService.mockSession = null);

  // A 200 with an unparsable body makes jsonDecode throw a raw FormatException.
  MockClient garbage() => MockClient((_) async => http.Response('<html>FormatException at http://db.internal</html>', 200));

  void expectGeneric() {
    expect(find.text('Terjadi kesalahan, coba lagi'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('http://'), findsNothing);
  }

  testWidgets('scan history shows the generic message, not the exception text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ScanHistoryScreen(baseUrl: 'http://localhost:8000', httpClient: garbage()),
    ));
    await tester.pumpAndSettle();
    expectGeneric();
  });

  testWidgets('scan session detail shows the generic message, not the exception text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ScanSessionDetailScreen(scanSessionId: 's1', baseUrl: 'http://localhost:8000', httpClient: garbage()),
    ));
    await tester.pumpAndSettle();
    expectGeneric();
  });
}
