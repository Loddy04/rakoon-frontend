import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late File photo;

  setUp(() {
    photo = File('${Directory.systemTemp.createTempSync('scan_offline').path}/shelf.jpg')..writeAsBytesSync([1, 2, 3]);
    AuthService.mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-uuid-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  });
  tearDown(() {
    AuthService.mockSession = null;
    photo.parent.deleteSync(recursive: true);
  });

  final calls = <String, Future<Object?> Function(http.Client)>{
    'scanPhoto': (c) => ScanService.scanPhoto(photo, baseUrl: 'http://localhost:8000', client: c),
    'confirmScan': (c) => ScanService.confirmScan(
          storeId: 'store-1',
          userId: 'user-uuid-123',
          items: [ScanResultItem(namaProduk: 'Beras', harga: 1000, confidence: 'tinggi', needsVerification: false)],
          baseUrl: 'http://localhost:8000',
          client: c,
        ),
    'getRecentScans': (c) => ScanService.getRecentScans(baseUrl: 'http://localhost:8000', client: c),
    'getScanSessionDetail': (c) => ScanService.getScanSessionDetail(sessionId: 's1', baseUrl: 'http://localhost:8000', client: c),
  };
  final failures = <String, Object Function()>{
    'SocketException': () => const SocketException('Failed host lookup: secret.host'),
    'TimeoutException': () => TimeoutException('slow'),
    'ClientException': () => http.ClientException('Connection closed'),
  };

  for (final call in calls.entries) {
    for (final failure in failures.entries) {
      test('${call.key}: ${failure.key} gives appropriate exception', () async {
        final client = MockClient((_) async => throw failure.value());
        final expectedMessage = call.key == 'scanPhoto' && failure.key == 'TimeoutException'
            ? timeoutErrorMessage
            : call.key == 'scanPhoto' && failure.key == 'ClientException'
                ? connectionClosedMessage
                : noConnectionMessage;
        await expectLater(
          call.value(client),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', expectedMessage)),
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
