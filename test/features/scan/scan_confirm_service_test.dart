import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ScanResultItem _item() => ScanResultItem(
      namaProduk: 'Beras Premium 5kg',
      harga: 72000.0,
      ukuran: 5.0,
      satuan: 'kg',
      kategori: 'Makanan Pokok',
      confidence: 'tinggi',
      needsVerification: false,
    );

void main() {
  setUp(() {
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

  tearDown(() => AuthService.mockSession = null);

  Future<ConfirmScanResult> confirmWith(Map<String, dynamic> body) {
    final client = MockClient((request) async => http.Response(jsonEncode(body), 201));
    return ScanService.confirmScan(
      storeId: 'store-1',
      userId: 'user-uuid-123',
      items: [_item()],
      baseUrl: 'http://localhost:8000',
      client: client,
    );
  }

  group('ConfirmScanResult.fromJson', () {
    test('items_pending_review defaults to 0 when the backend does not send it', () {
      final result = ConfirmScanResult.fromJson({
        'items_saved': 3,
        'products_created': 1,
        'message': 'ok',
      });
      expect(result.itemsSaved, 3);
      expect(result.productsCreated, 1);
      expect(result.itemsPendingReview, 0);
      expect(result.message, 'ok');
    });

    test('reads items_pending_review when present', () {
      final result = ConfirmScanResult.fromJson({
        'items_saved': 3,
        'products_created': 0,
        'items_pending_review': 2,
        'message': 'ok',
      });
      expect(result.itemsPendingReview, 2);
    });

    test('tolerates null or missing fields without throwing', () {
      final result = ConfirmScanResult.fromJson({'items_pending_review': null});
      expect(result.itemsSaved, 0);
      expect(result.productsCreated, 0);
      expect(result.itemsPendingReview, 0);
      expect(result.message, isNull);
    });
  });

  group('ScanService.confirmScan friendly errors (no raw body)', () {
    Future<void> confirmWithStatus(int status, String body) {
      final client = MockClient((request) async => http.Response(body, status));
      return ScanService.confirmScan(
        storeId: 'store-1',
        userId: 'user-uuid-123',
        items: [_item()],
        baseUrl: 'http://localhost:8000',
        client: client,
      );
    }

    Future<String> messageOf(int status, String body) async {
      try {
        await confirmWithStatus(status, body);
      } catch (e) {
        return e.toString().replaceFirst('Exception: ', '');
      }
      fail('seharusnya melempar exception untuk status $status');
    }

    const rawBodies = {
      'detail string': '{"detail":"Toko tidak ditemukan."}',
      'pydantic list': '{"detail":[{"type":"greater_than","loc":["body","items",0,"harga"],"msg":"Input should be greater than 0"}]}',
      'html': '<html><body>Not Found</body></html>',
      'empty': '',
    };

    test('404 -> "Toko tidak ditemukan, pilih toko lagi" for any body', () async {
      for (final entry in rawBodies.entries) {
        expect(await messageOf(404, entry.value), 'Toko tidak ditemukan, pilih toko lagi', reason: entry.key);
      }
    });

    test('422 -> "Ada harga atau jumlah item yang tidak valid" without leaking validation details', () async {
      for (final entry in rawBodies.entries) {
        final message = await messageOf(422, entry.value);
        expect(message, 'Ada harga atau jumlah item yang tidak valid', reason: entry.key);
        expect(message, isNot(contains('loc')));
        expect(message, isNot(contains('greater_than')));
      }
    });

    test('429 -> "Batas konfirmasi harian tercapai, coba lagi besok" for any body', () async {
      for (final entry in rawBodies.entries) {
        expect(await messageOf(429, entry.value), 'Batas konfirmasi harian tercapai, coba lagi besok', reason: entry.key);
      }
    });

    test('other errors keep a readable server detail or a generic fallback, never a parse crash', () async {
      expect(await messageOf(500, '{"detail":"Terjadi kesalahan saat menyimpan konfirmasi scan."}'),
          'Terjadi kesalahan saat menyimpan konfirmasi scan.');
      expect(await messageOf(500, '<html>boom</html>'), 'Gagal menyimpan konfirmasi');
      expect(await messageOf(500, '{"detail":[{"msg":"x"}]}'), 'Gagal menyimpan konfirmasi');
    });
  });

  group('ScanService.confirmScan response model', () {
    test('returns a model with itemsPendingReview 0 for an old-style response', () async {
      final result = await confirmWith({'items_saved': 1, 'products_created': 0, 'message': 'Berhasil'});
      expect(result.itemsSaved, 1);
      expect(result.itemsPendingReview, 0);
    });

    test('returns itemsPendingReview from the backend response', () async {
      final result = await confirmWith({
        'items_saved': 2,
        'products_created': 1,
        'items_pending_review': 1,
        'message': 'Berhasil',
      });
      expect(result.itemsSaved, 2);
      expect(result.productsCreated, 1);
      expect(result.itemsPendingReview, 1);
    });
  });
}
