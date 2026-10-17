import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String invalidRequestMessage = 'Lokasi atau jumlah data tidak valid, coba lagi';
const String noConnectionMessage = 'Tidak ada koneksi internet. Periksa data seluler atau Wi-Fi, lalu coba lagi.';
const String serverErrorMessage = 'Server sedang bermasalah, coba lagi nanti';
const String timeoutErrorMessage = 'Pemrosesan memakan waktu terlalu lama. Coba lagi sebentar lagi.';
const String connectionClosedMessage = 'Koneksi terputus saat mengirim. Coba lagi.';

/// Thrown for HTTP 422 (lat/lng/radius/limit out of bounds). Never carries the response body.
class InvalidRequestException implements Exception {
  final String message;
  const InvalidRequestException([this.message = invalidRequestMessage]);

  @override
  String toString() => message;
}

/// Thrown when the request never got an answer (offline, DNS, no route).
class NoConnectionException implements Exception {
  final String message;
  const NoConnectionException([this.message = noConnectionMessage]);

  @override
  String toString() => message;
}

/// Thrown when an operation exceeds its time limit (not an offline network failure).
class TimeoutApiException implements Exception {
  final String message;
  const TimeoutApiException([this.message = timeoutErrorMessage]);

  @override
  String toString() => message;
}

/// Thrown when the connection is interrupted or closed mid-transfer.
class ConnectionClosedException implements Exception {
  final String message;
  const ConnectionClosedException([this.message = connectionClosedMessage]);

  @override
  String toString() => message;
}

/// Thrown for HTTP 5xx and 408. Never carries the response body.
class ServerErrorException implements Exception {
  final String message;
  const ServerErrorException([this.message = serverErrorMessage]);

  @override
  String toString() => message;
}

void throwIfInvalidRequest(http.Response response) {
  if (response.statusCode == 422) throw const InvalidRequestException();
}

void throwIfServerError(http.Response response) {
  if (response.statusCode >= 500 || response.statusCode == 408) throw const ServerErrorException();
}

/// Runs [body]; network-level failures become user-friendly exceptions, everything else passes through.
/// When [differentiate] is false (default), errors map to [NoConnectionException].
/// When [differentiate] is true, [TimeoutException] maps to [TimeoutApiException],
/// and non-network [http.ClientException] maps to [ConnectionClosedException].
Future<T> mapNetworkErrors<T>(
  Future<T> Function() body, {
  bool differentiate = false,
}) async {
  try {
    return await body();
  } on SocketException catch (e) {
    if (kDebugMode) {
      debugPrint('[mapNetworkErrors] SocketException: ${e.message}');
    }
    throw const NoConnectionException();
  } on TimeoutException catch (e) {
    if (kDebugMode) {
      debugPrint('[mapNetworkErrors] TimeoutException: ${e.message ?? 'timeout'}');
    }
    if (differentiate) {
      throw const TimeoutApiException();
    }
    throw const NoConnectionException();
  } on http.ClientException catch (e) {
    if (kDebugMode) {
      debugPrint('[mapNetworkErrors] ClientException: ${e.message}');
    }
    if (differentiate) {
      final msg = e.message.toLowerCase();
      if (msg.contains('socketexception') ||
          msg.contains('failed host lookup') ||
          msg.contains('network is unreachable')) {
        throw const NoConnectionException();
      }
      throw const ConnectionClosedException();
    }
    throw const NoConnectionException();
  }
}

/// The user-facing message for known API exceptions, or null for anything else (never show raw errors).
String? friendlyApiError(Object error) {
  if (error is NoConnectionException ||
      error is TimeoutApiException ||
      error is ConnectionClosedException ||
      error is ServerErrorException ||
      error is InvalidRequestException) {
    return error.toString();
  }
  return null;
}

const String genericErrorMessage = 'Terjadi kesalahan, coba lagi';

const List<String> _technicalMarkers = [
  'SocketException',
  'ClientException',
  'TimeoutException',
  'FormatException',
  'Detail:',
  'http://',
  'https://',
  'Traceback',
  "type '",
];

/// Text safe to show to a user: strips "Exception: " and swaps anything technical for a generic message.
String userMessage(Object error) {
  if (error is TimeoutApiException) {
    return timeoutErrorMessage;
  }
  if (error is ConnectionClosedException) {
    return connectionClosedMessage;
  }
  if (error is NoConnectionException) {
    return error.message;
  }
  if (error is ServerErrorException || error is InvalidRequestException) {
    return error.toString();
  }
  final raw = error.toString();
  final text = raw.replaceFirst('Exception: ', '').trim();
  if (text.isEmpty || _technicalMarkers.any(raw.contains)) return genericErrorMessage;
  return text;
}

/// Wraps a client so network-level failures surface as [NoConnectionException].
class FriendlyHttpClient extends http.BaseClient {
  final http.Client _inner;
  FriendlyHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => mapNetworkErrors(() => _inner.send(request));

  @override
  void close() => _inner.close();
}
