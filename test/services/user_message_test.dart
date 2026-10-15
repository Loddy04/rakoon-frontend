import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';

const _generic = 'Terjadi kesalahan, coba lagi';

void main() {
  group('userMessage', () {
    test('drops the "Exception: " prefix and keeps a readable message', () {
      expect(userMessage(Exception('Klaim untuk toko ini sudah ada')), 'Klaim untuk toko ini sudah ada');
      expect(userMessage('Exception: Foto terlalu besar'), 'Foto terlalu besar');
    });

    test('keeps the friendly API messages', () {
      expect(userMessage(const NoConnectionException()), noConnectionMessage);
      expect(userMessage(const ServerErrorException()), serverErrorMessage);
      expect(userMessage(const InvalidRequestException()), invalidRequestMessage);
    });

    test('technical text becomes the generic message', () {
      final technical = <Object>[
        const SocketException('Failed host lookup: secret.host'),
        http.ClientException('Connection closed'),
        TimeoutException('slow'),
        Exception('Gagal memuat. Detail: boom'),
        Exception('Failed to connect to http://10.0.2.2:8000/x'),
        Exception('GET https://api.example.com/x failed'),
        Exception('Traceback (most recent call last)'),
        "type 'Null' is not a subtype of type 'String'",
      ];
      for (final e in technical) {
        expect(userMessage(e), _generic, reason: '$e');
      }
    });

    test('an empty message becomes the generic message', () {
      expect(userMessage(Exception('')), _generic);
    });
  });

  group('FriendlyHttpClient', () {
    for (final failure in <String, Object Function()>{
      'SocketException': () => const SocketException('Failed host lookup: secret.host'),
      'TimeoutException': () => TimeoutException('slow'),
      'ClientException': () => http.ClientException('Connection closed'),
    }.entries) {
      test('${failure.key} becomes NoConnectionException', () async {
        final client = FriendlyHttpClient(MockClient((_) async => throw failure.value()));
        await expectLater(client.get(Uri.parse('http://x/y')), throwsA(isA<NoConnectionException>()));
      });
    }

    test('responses pass through untouched', () async {
      final client = FriendlyHttpClient(MockClient((_) async => http.Response('ok', 500)));
      final res = await client.get(Uri.parse('http://x/y'));
      expect((res.statusCode, res.body), (500, 'ok'));
    });
  });
}
