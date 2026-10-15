import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_shopping_screen.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';

Future<void> _pumpScreen(WidgetTester tester, MockClient client) async {
  await http.runWithClient(() async {
    await tester.pumpWidget(const MaterialApp(home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000')));
    await tester.pump(const Duration(milliseconds: 600));
  }, () => client);
}

void main() {
  for (final failure in <String, Object Function()>{
    'SocketException': () => const SocketException('Failed host lookup: secret.host'),
    'TimeoutException': () => TimeoutException('slow'),
  }.entries) {
    testWidgets('${failure.key}: default products error is the offline message', (tester) async {
      await _pumpScreen(tester, MockClient((_) async => throw failure.value()));
      expect(find.text(noConnectionMessage), findsOneWidget);
      expect(find.textContaining('secret.host'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });
  }

  testWidgets('HTTP 500: default products error is the server message, never the body', (tester) async {
    await _pumpScreen(tester, MockClient((_) async => http.Response('psycopg2 secret', 500)));
    expect(find.text(serverErrorMessage), findsOneWidget);
    expect(find.textContaining('psycopg2'), findsNothing);
  });

  testWidgets('search failure shows the friendly message too', (tester) async {
    final client = MockClient((request) async {
      if (request.url.queryParameters.containsKey('search')) throw const SocketException('Failed host lookup');
      return http.Response('[]', 200);
    });
    await _pumpScreen(tester, client);
    await http.runWithClient(() async {
      await tester.enterText(find.byType(TextField).last, 'susu');
      await tester.pump(const Duration(milliseconds: 600));
    }, () => client);

    expect(find.text(noConnectionMessage), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}
