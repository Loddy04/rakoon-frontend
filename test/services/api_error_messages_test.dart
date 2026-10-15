import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/services/api_error_messages.dart';

const _offline = 'Tidak ada koneksi internet. Periksa data seluler atau Wi-Fi, lalu coba lagi.';
const _server = 'Server sedang bermasalah, coba lagi nanti';

void main() {
  group('mapNetworkErrors', () {
    for (final entry in <String, Object>{
      'SocketException': const SocketException('Failed host lookup: secret.host'),
      'TimeoutException': TimeoutException('slow'),
      'ClientException': http.ClientException('Connection closed'),
    }.entries) {
      test('${entry.key} becomes NoConnectionException with the friendly message', () async {
        await expectLater(
          mapNetworkErrors<void>(() async => throw entry.value),
          throwsA(isA<NoConnectionException>()
              .having((e) => e.message, 'message', _offline)
              .having((e) => e.toString(), 'toString', _offline)),
        );
      });
    }

    test('other errors and results pass through unchanged', () async {
      expect(await mapNetworkErrors(() async => 7), 7);
      await expectLater(mapNetworkErrors<void>(() async => throw const FormatException('x')), throwsFormatException);
      await expectLater(
        mapNetworkErrors<void>(() async => throw const InvalidRequestException()),
        throwsA(isA<InvalidRequestException>()),
      );
    });
  });

  group('throwIfServerError', () {
    test('5xx and 408 give the server message without the body', () {
      for (final code in [500, 502, 503, 504, 408]) {
        expect(
          () => throwIfServerError(http.Response('psycopg2 secret', code)),
          throwsA(isA<ServerErrorException>().having((e) => e.toString(), 'toString', _server)),
          reason: '$code',
        );
      }
    });

    test('2xx, 4xx do not throw', () {
      for (final code in [200, 404, 422]) {
        expect(() => throwIfServerError(http.Response('', code)), returnsNormally, reason: '$code');
      }
    });
  });

  test('friendlyApiError returns the message only for known exceptions', () {
    expect(friendlyApiError(const NoConnectionException()), _offline);
    expect(friendlyApiError(const ServerErrorException()), _server);
    expect(friendlyApiError(const InvalidRequestException()), invalidRequestMessage);
    expect(friendlyApiError(Exception('raw secret')), isNull);
  });
}
