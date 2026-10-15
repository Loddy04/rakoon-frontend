import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _base = 'https://api.test';
const _docPath = 'documents/0123456789abcdef0123456789abcdef0123456789abcdef.pdf';
const _photoPath = 'photos/0123456789abcdef0123456789abcdef0123456789abcdef.jpg';

Session _session() => Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'u@example.com',
      ),
    );

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(() => AuthService.mockSession = _session());
  tearDown(() => AuthService.mockSession = null);

  group('uploads return object paths', () {
    test('uploadClaimDocument reads document_path', () async {
      late http.BaseRequest seen;
      final client = MockClient((request) async {
        seen = request;
        return _json({'document_path': _docPath}, 200);
      });
      final path = await AdsService.uploadClaimDocument(
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        filename: 'nib.pdf',
        baseUrl: _base,
        client: client,
      );
      expect(path, _docPath);
      expect(seen.url.path, '/ads/upload-claim-document');
      expect(seen.headers['Authorization'], 'Bearer test-token');
    });

    test('uploadClaimPhoto reads photo_path and labels a .png as image/png', () async {
      late String body;
      final client = MockClient((request) async {
        body = utf8.decode(request.bodyBytes, allowMalformed: true).toLowerCase();
        return _json({'photo_path': _photoPath}, 200);
      });
      final path = await AdsService.uploadClaimPhoto(
        bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        filename: 'front.png',
        baseUrl: _base,
        client: client,
      );
      expect(path, _photoPath);
      expect(body, contains('content-type: image/png'));
    });
  });

  group('claim and submit payloads', () {
    test('claimStore sends the evidence paths as document_url / store_photo_url', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'is_claimed': false, 'claim_status': 'pending', 'campaigns': []}, 200);
      });
      await AdsService.claimStore(
        storeId: 'store-1',
        applicantName: 'Budi',
        applicantPhone: '081234567890',
        documentUrl: _docPath,
        storePhotoUrl: _photoPath,
        baseUrl: _base,
        client: client,
      );
      expect(sent['document_url'], _docPath);
      expect(sent['store_photo_url'], _photoPath);
      expect(sent['applicant_name'], 'Budi');
    });

    test('submitNewStore sends latitude/longitude and no store_category', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'id': 's1', 'submission_type': 'new_store', 'store_name': 'Warung', 'status': 'pending', 'created_at': ''}, 201);
      });
      await AdsService.submitNewStore(
        storeName: 'Warung',
        storeAddress: 'Jl. Contoh No. 1',
        applicantName: 'Ani',
        applicantPhone: '081200000000',
        applicantRole: 'Pemilik',
        latitude: 3.5952,
        longitude: 98.6722,
        documentUrl: _docPath,
        storePhotoUrl: _photoPath,
        baseUrl: _base,
        client: client,
      );
      expect(sent['latitude'], 3.5952);
      expect(sent['longitude'], 98.6722);
      expect(sent.containsKey('store_category'), isFalse);
      expect(sent['document_url'], _docPath);
    });
  });

  group('friendly errors without the raw body', () {
    const raw = 'psycopg2 SELECT secret FROM store_owners';

    Future<Object> claimError(int status, Object body) async {
      final client = MockClient((_) async => _json(body, status));
      try {
        await AdsService.claimStore(storeId: 's', baseUrl: _base, client: client);
      } catch (e) {
        return e;
      }
      fail('expected an error');
    }

    Future<Object> uploadError(int status, Object body) async {
      final client = MockClient((_) async => _json(body, status));
      try {
        await AdsService.uploadClaimDocument(bytes: Uint8List.fromList([1]), filename: 'a.pdf', baseUrl: _base, client: client);
      } catch (e) {
        return e;
      }
      fail('expected an error');
    }

    test('409 on claim says the claim already exists', () async {
      final e = await claimError(409, {'detail': 'Klaim Anda untuk toko ini sedang diproses.'});
      expect(e.toString(), contains('Klaim untuk toko ini sudah ada'));
    });

    test('503 says storage is not available yet', () async {
      for (final e in [await claimError(503, {'detail': raw}), await uploadError(503, {'detail': raw})]) {
        expect(e.toString(), contains('Penyimpanan belum tersedia, coba lagi nanti'));
        expect(e.toString(), isNot(contains('psycopg2')));
      }
    });

    test('413 asks for a smaller file', () async {
      final e = await uploadError(413, {'detail': raw});
      expect(e.toString(), contains('terlalu besar'));
      expect(e.toString(), isNot(contains('psycopg2')));
    });

    test('400 shows a plain backend message but never a structured body', () async {
      final plain = await uploadError(400, {'detail': 'Format file tidak valid. Gunakan PDF atau JPEG.'});
      expect(plain.toString(), contains('Format file tidak valid'));

      final structured = await claimError(400, {
        'detail': [
          {'loc': ['body', 'x'], 'msg': raw}
        ]
      });
      expect(structured.toString(), isNot(contains('psycopg2')));
      expect(structured.toString(), isNot(contains('loc')));
    });

    test('422 is a generic incomplete-data message', () async {
      final e = await claimError(422, {
        'detail': [
          {'loc': ['body', 'applicant_name'], 'msg': raw}
        ]
      });
      expect(e.toString(), isNot(contains('applicant_name')));
      expect(e.toString(), contains('belum lengkap'));
    });
  });

  group('getClaimEvidenceUrl', () {
    test('requests the signed url for a path', () async {
      late Uri seen;
      final client = MockClient((request) async {
        seen = request.url;
        return _json({'url': 'https://mock.supabase.co/sign?token=t', 'expires_in': 300}, 200);
      });
      final url = await AdsService.getClaimEvidenceUrl(path: _docPath, baseUrl: _base, client: client);
      expect(url, 'https://mock.supabase.co/sign?token=t');
      expect(seen.path, '/ads/claim-evidence-url');
      expect(seen.queryParameters['path'], _docPath);
    });

    test('403 and 404 map to friendly messages', () async {
      for (final status in [403, 404]) {
        final client = MockClient((_) async => _json({'detail': 'x'}, status));
        await expectLater(
          AdsService.getClaimEvidenceUrl(path: _docPath, baseUrl: _base, client: client),
          throwsA(isA<Exception>()),
        );
      }
    });
  });
}
