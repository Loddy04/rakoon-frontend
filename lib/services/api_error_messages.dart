import 'package:http/http.dart' as http;

const String invalidRequestMessage = 'Lokasi atau jumlah data tidak valid, coba lagi';

/// Thrown for HTTP 422 (lat/lng/radius/limit out of bounds). Never carries the response body.
class InvalidRequestException implements Exception {
  final String message;
  const InvalidRequestException([this.message = invalidRequestMessage]);

  @override
  String toString() => message;
}

void throwIfInvalidRequest(http.Response response) {
  if (response.statusCode == 422) throw const InvalidRequestException();
}
