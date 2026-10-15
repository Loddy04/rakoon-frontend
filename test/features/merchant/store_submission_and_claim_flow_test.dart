// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_store_claims_page.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key', // ignore: deprecated_member_use
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {}
  });

  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'mock-user-token',
      tokenType: 'bearer',
      user: const User(
        id: 'user-789',
        email: 'user@rakoon.app',
        appMetadata: {},
        userMetadata: {'name': 'Budi Pemohon'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      ),
    );
    AuthService.mockIsAdmin = false;
  });

  tearDown(() {
    AuthService.mockSession = null;
    AuthService.mockIsAdmin = null;
  });

  group('Store Submission & Claim Flow Tests', () {
    test('UserSubmissionData and PendingStoreClaimData model parsing', () {
      final subJson = {
        'id': 'sub-1',
        'submission_type': 'new_store',
        'store_id': null,
        'store_name': 'Warung Buah Segar',
        'store_address': 'Jl. Solo KM 9',
        'store_category': 'Toko Buah & Sayur',
        'business_entity_name': 'CV Segar Selalu',
        'applicant_name': 'Dewi',
        'applicant_phone': '08123456789',
        'applicant_role': 'Pemilik',
        'document_url': '/ads/documents/doc_123.pdf',
        'store_photo_url': 'https://example.com/photo.jpg',
        'status': 'pending',
        'rejection_reason': null,
        'created_at': '2026-10-13T12:00:00Z',
      };
      final sub = UserSubmissionData.fromJson(subJson);
      expect(sub.id, 'sub-1');
      expect(sub.submissionType, 'new_store');
      expect(sub.storeName, 'Warung Buah Segar');
      expect(sub.storeCategory, 'Toko Buah & Sayur');
      expect(sub.applicantRole, 'Pemilik');
      expect(sub.documentUrl, '/ads/documents/doc_123.pdf');

      final claimJson = {
        'user_id': 'user-123',
        'store_id': '',
        'submission_id': 'sub-1',
        'claim_type': 'new_store',
        'store_nama': 'Warung Buah Segar',
        'store_alamat': 'Jl. Solo KM 9',
        'store_category': 'Toko Buah & Sayur',
        'business_entity_name': 'CV Segar Selalu',
        'applicant_name': 'Dewi',
        'applicant_phone': '08123456789',
        'applicant_role': 'Pemilik',
        'document_url': '/ads/documents/doc_123.pdf',
        'store_photo_url': 'https://example.com/photo.jpg',
        'user_nama': 'Dewi',
        'user_email': 'dewi@example.com',
        'status': 'pending',
        'created_at': '2026-10-13T12:00:00Z',
        'has_verified_owner': false,
      };
      final claim = PendingStoreClaimData.fromJson(claimJson);
      expect(claim.submissionId, 'sub-1');
      expect(claim.claimType, 'new_store');
      expect(claim.storeNama, 'Warung Buah Segar');
      expect(claim.applicantName, 'Dewi');
    });

    testWidgets('MerchantDashboardPage displays choice to claim existing store or submit new store', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/my-store')) {
          return http.Response(
            jsonEncode({
              'is_claimed': false,
              'claim_status': null,
              'campaigns': [],
            }),
            200,
          );
        } else if (request.url.path.endsWith('/stores/nearby')) {
          return http.Response(
            jsonEncode({
              'stores': [
                {
                  'store_id': 'store-1',
                  'nama': 'Superindo Kaliurang',
                  'alamat': 'Jl. Kaliurang KM 6',
                  'distance_km': 1.2,
                  'total_products': 450,
                }
              ]
            }),
            200,
          );
        } else if (request.url.path.endsWith('/ads/my-submissions')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pilihan Jalur A: Klaim Toko Terdaftar
      expect(find.text('Klaim & Kelola Toko Ini'), findsOneWidget);

      // Pilihan Jalur B: Tombol pengajuan toko baru
      final newStoreBtn = find.byKey(const Key('btn_submit_new_store'));
      expect(newStoreBtn, findsOneWidget);
      expect(find.text('Toko belum terdaftar? Ajukan toko baru'), findsOneWidget);
    });

    testWidgets('Tapping Ajukan Toko Baru opens form modal without category and submits successfully with file uploads', (tester) async {
      bool submitNewStoreCalled = false;
      bool uploadDocCalled = false;
      bool uploadPhotoCalled = false;
      Map<String, dynamic>? submittedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/my-store')) {
          return http.Response(
            jsonEncode({'is_claimed': false, 'claim_status': null, 'campaigns': []}),
            200,
          );
        } else if (request.url.path.endsWith('/stores/nearby')) {
          return http.Response(
            jsonEncode({'stores': []}),
            200,
          );
        } else if (request.url.path.endsWith('/ads/upload-claim-document') && request.method == 'POST') {
          uploadDocCalled = true;
          return http.Response(
            jsonEncode({'document_path': 'documents/uploaded123.pdf'}),
            200,
          );
        } else if (request.url.path.endsWith('/ads/upload-claim-photo') && request.method == 'POST') {
          uploadPhotoCalled = true;
          return http.Response(
            jsonEncode({'photo_path': 'photos/uploaded456.jpg'}),
            200,
          );
        } else if (request.url.path.endsWith('/ads/my-submissions')) {
          if (submitNewStoreCalled) {
            return http.Response(
              jsonEncode([
                {
                  'id': 'sub-99',
                  'submission_type': 'new_store',
                  'store_name': 'Apotek K-24 Baru',
                  'store_address': 'Jl. Gejayan No. 12',
                  'applicant_name': 'Ahmad',
                  'applicant_phone': '0812334455',
                  'applicant_role': 'Apoteker',
                  'status': 'pending',
                  'created_at': '2026-10-13T14:00:00Z',
                }
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        } else if (request.url.path.endsWith('/ads/submit-new-store') && request.method == 'POST') {
          submitNewStoreCalled = true;
          submittedBody = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'id': 'sub-99',
              'submission_type': 'new_store',
              'store_name': submittedBody?['store_name'],
              'store_address': submittedBody?['store_address'],
              'status': 'pending',
              'created_at': '2026-10-13T14:00:00Z',
            }),
            201,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
            documentPicker: ({required allowedExtensions}) async => PickedFileData(
              name: 'nib_resmi.pdf',
              sizeInBytes: 500 * 1024,
              bytes: Uint8List.fromList([37, 80, 68, 70]), // %PDF
            ),
            photoPicker: ({required allowedExtensions}) async => PickedFileData(
              name: 'tampak_depan.png',
              sizeInBytes: 800 * 1024,
              bytes: Uint8List.fromList([
                0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
                0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
                0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
                0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
                0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
                0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
                0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
                0x42, 0x60, 0x82
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Klik tombol ajukan toko baru
      await tester.tap(find.byKey(const Key('btn_submit_new_store')));
      await tester.pumpAndSettle();

      // Form modal terbuka
      expect(find.text('Ajukan Toko Baru'), findsOneWidget);
      expect(find.byKey(const Key('new_store_name_input')), findsOneWidget);

      // Verifikasi field kategori toko SUDAH DIHAPUS dari UI
      expect(find.byKey(const Key('new_store_category_dropdown')), findsNothing);
      expect(find.text('Kategori Toko *'), findsNothing);

      // Isi form
      await tester.enterText(find.byKey(const Key('new_store_name_input')), 'Apotek K-24 Baru');
      await tester.enterText(find.byKey(const Key('new_store_address_input')), 'Jl. Gejayan No. 12, Sleman');
      await tester.enterText(find.byKey(const Key('new_store_applicant_name_input')), 'Ahmad Sutanto');
      await tester.enterText(find.byKey(const Key('new_store_applicant_phone_input')), '081233445566');

      // Unggah Dokumen Legalitas via File Picker
      final pickDocBtn = find.byKey(const Key('btn_pick_claim_document'));
      await tester.ensureVisible(pickDocBtn);
      await tester.tap(pickDocBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selected_doc_name')), findsOneWidget);
      expect(find.text('nib_resmi.pdf'), findsOneWidget);

      // Unggah Foto Tampak Depan Toko via Image Picker
      final pickPhotoBtn = find.byKey(const Key('btn_pick_store_photo'));
      await tester.ensureVisible(pickPhotoBtn);
      await tester.tap(pickPhotoBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selected_photo_name')), findsOneWidget);
      expect(find.text('tampak_depan.png'), findsOneWidget);

      // Submit form
      // Pilih titik toko di peta (flutter_map menunggu ~250 ms untuk membedakan double tap)
      final locationMap = find.byKey(const Key('new_store_location_map'));
      await tester.ensureVisible(locationMap);
      await tester.tap(locationMap);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final submitConfirmBtn = find.byKey(const Key('btn_confirm_submit_new_store'));
      await tester.ensureVisible(submitConfirmBtn);
      await tester.tap(submitConfirmBtn);
      await tester.pumpAndSettle();

      // Verifikasi file diunggah ke backend
      expect(uploadDocCalled, isTrue);
      expect(uploadPhotoCalled, isTrue);

      // Verifikasi backend submitNewStore dipanggil dengan data yang tepat
      expect(submitNewStoreCalled, isTrue);
      expect(submittedBody?['store_name'], 'Apotek K-24 Baru');
      expect(submittedBody?['applicant_name'], 'Ahmad Sutanto');
      expect(submittedBody?['applicant_phone'], '081233445566');
      expect(submittedBody?['document_url'], 'documents/uploaded123.pdf');
      expect(submittedBody?['store_photo_url'], 'photos/uploaded456.jpg');

      // Verifikasi SnackBar sukses
      expect(find.text('Pengajuan toko baru berhasil dikirim. Menunggu verifikasi admin.'), findsOneWidget);

      // Verifikasi riwayat pengajuan muncul di halaman
      expect(find.text('Riwayat Pengajuan Anda'), findsOneWidget);
      expect(find.text('Apotek K-24 Baru'), findsOneWidget);
      expect(find.text('Menunggu Pemeriksaan'), findsOneWidget);
    });

    testWidgets('MerchantDashboardPage renders submissions history with rejected reason', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/my-store')) {
          return http.Response(
            jsonEncode({'is_claimed': false, 'claim_status': null, 'campaigns': []}),
            200,
          );
        } else if (request.url.path.endsWith('/stores/nearby')) {
          return http.Response(jsonEncode({'stores': []}), 200);
        } else if (request.url.path.endsWith('/ads/my-submissions')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'sub-rej',
                'submission_type': 'new_store',
                'store_name': 'Toko Kurang Bukti',
                'store_address': 'Jl. Magelang KM 4',
                'status': 'rejected',
                'rejection_reason': 'Foto depan toko tidak memperlihatkan papan nama usaha.',
                'created_at': '2026-10-12T09:00:00Z',
              }
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Pengajuan Anda'), findsOneWidget);
      expect(find.text('Toko Kurang Bukti'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);
      expect(find.text('Alasan: Foto depan toko tidak memperlihatkan papan nama usaha.'), findsOneWidget);
    });

    testWidgets('AdminStoreClaimsPage renders both claim types and allows admin verification', (tester) async {
      AuthService.mockIsAdmin = true;
      bool verifyNewStoreCalled = false;
      String? verifiedSubmissionId;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/pending-claims')) {
          return http.Response(
            jsonEncode([
              {
                'user_id': 'u-1',
                'store_id': 's-1',
                'submission_id': 'c-1',
                'claim_type': 'claim',
                'store_nama': 'Indomaret Existing',
                'store_alamat': 'Jl. Kaliurang KM 5',
                'applicant_name': 'Pak Budi',
                'applicant_role': 'Pemilik',
                'user_nama': 'Budi',
                'status': 'pending',
                'created_at': '2026-10-13T08:00:00Z',
                'has_verified_owner': false,
              },
              {
                'user_id': 'u-2',
                'store_id': '',
                'submission_id': 'new-sub-100',
                'claim_type': 'new_store',
                'store_nama': 'Toko Ritel Baru',
                'store_alamat': 'Jl. Wonosari KM 7',
                'store_category': 'Supermarket',
                'latitude': -7.85,
                'longitude': 110.35,
                'applicant_name': 'Siti Rahma',
                'applicant_phone': '0877889900',
                'applicant_role': 'Manajer Cabang',
                'document_url': '/ads/documents/doc_nib.pdf',
                'store_photo_url': 'https://example.com/front.jpg',
                'user_nama': 'Siti',
                'status': 'pending',
                'created_at': '2026-10-13T09:00:00Z',
                'has_verified_owner': false,
              }
            ]),
            200,
          );
        } else if (request.url.path.endsWith('/ads/verify-new-store') && request.method == 'POST') {
          verifyNewStoreCalled = true;
          final b = jsonDecode(request.body);
          verifiedSubmissionId = b['submission_id'];
          return http.Response(
            jsonEncode({'status': 'success', 'message': 'Toko berhasil diverifikasi'}),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminStoreClaimsPage(
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Periksa badge pembeda
      expect(find.text('Klaim Toko Terdaftar'), findsOneWidget);
      expect(find.text('Pengajuan Toko Baru'), findsOneWidget);
      expect(find.text('Toko Ritel Baru'), findsOneWidget);
      expect(find.text('Dokumen Legalitas (NIB)'), findsOneWidget);
      expect(find.text('Foto Depan Toko'), findsOneWidget);

      // Admin menyetujui pengajuan toko baru
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final approveBtn = find.byKey(const Key('approve_claim_new-sub-100'));
      expect(approveBtn, findsOneWidget);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Dialog konfirmasi admin muncul
      expect(find.text('Setujui Toko Baru?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_approve_button')));
      await tester.pumpAndSettle();

      // Verifikasi backend verify-new-store dipanggil
      expect(verifyNewStoreCalled, isTrue);
      expect(verifiedSubmissionId, 'new-sub-100');
    });

    testWidgets('AdminStoreClaimsPage allows admin to reject new store submission with reason', (tester) async {
      AuthService.mockIsAdmin = true;
      bool rejectNewStoreCalled = false;
      String? rejectedSubmissionId;
      String? recordedReason;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/pending-claims')) {
          return http.Response(
            jsonEncode([
              {
                'user_id': 'u-2',
                'store_id': '',
                'submission_id': 'new-sub-200',
                'claim_type': 'new_store',
                'store_nama': 'Toko Belum Lengkap',
                'store_alamat': 'Jl. Parangtritis KM 5',
                'applicant_name': 'Joko',
                'status': 'pending',
                'created_at': '2026-10-13T10:00:00Z',
                'has_verified_owner': false,
              }
            ]),
            200,
          );
        } else if (request.url.path.endsWith('/ads/reject-new-store') && request.method == 'POST') {
          rejectNewStoreCalled = true;
          final b = jsonDecode(request.body);
          rejectedSubmissionId = b['submission_id'];
          recordedReason = b['reason'];
          return http.Response(
            jsonEncode({'status': 'success', 'message': 'Pengajuan ditolak'}),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminStoreClaimsPage(
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rejectBtn = find.byKey(const Key('reject_claim_new-sub-200'));
      expect(rejectBtn, findsOneWidget);
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Dialog tolak muncul
      expect(find.text('Tolak Pengajuan Toko Baru?'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reject_reason_input')), 'Foto papan nama tidak terlihat jelas.');
      await tester.tap(find.byKey(const Key('confirm_reject_button')));
      await tester.pumpAndSettle();

      expect(rejectNewStoreCalled, isTrue);
      expect(rejectedSubmissionId, 'new-sub-200');
      expect(recordedReason, 'Foto papan nama tidak terlihat jelas.');
    });

    testWidgets('Submit new store displays informative error SnackBar when backend returns HTTP 503', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/my-store')) {
          return http.Response(
            jsonEncode({'is_claimed': false, 'claim_status': null, 'campaigns': []}),
            200,
          );
        } else if (request.url.path.endsWith('/stores/nearby')) {
          return http.Response(jsonEncode({'stores': []}), 200);
        } else if (request.url.path.endsWith('/ads/upload-claim-document') && request.method == 'POST') {
          return http.Response(
            jsonEncode({'document_path': 'documents/doc123.pdf'}),
            200,
          );
        } else if (request.url.path.endsWith('/ads/upload-claim-photo') && request.method == 'POST') {
          return http.Response(
            jsonEncode({'photo_path': 'photos/photo123.jpg'}),
            200,
          );
        } else if (request.url.path.endsWith('/ads/my-submissions')) {
          return http.Response(jsonEncode([]), 200);
        } else if (request.url.path.endsWith('/ads/submit-new-store') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'detail': 'Fitur pengajuan toko baru belum tersedia karena skema database belum diperbarui. Silakan hubungi administrator.'
            }),
            503,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
            documentPicker: ({required allowedExtensions}) async => PickedFileData(
              name: 'nib_resmi.pdf',
              sizeInBytes: 500 * 1024,
              bytes: Uint8List.fromList([37, 80, 68, 70]),
            ),
            photoPicker: ({required allowedExtensions}) async => PickedFileData(
              name: 'tampak_depan.png',
              sizeInBytes: 800 * 1024,
              bytes: Uint8List.fromList([
                0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
                0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
                0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
                0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
                0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
                0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
                0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
                0x42, 0x60, 0x82
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_submit_new_store')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('new_store_name_input')), 'Toko Maju Mapan');
      await tester.enterText(find.byKey(const Key('new_store_address_input')), 'Jl. Kaliurang KM 8');
      await tester.enterText(find.byKey(const Key('new_store_applicant_name_input')), 'Budi');
      await tester.enterText(find.byKey(const Key('new_store_applicant_phone_input')), '08123456789');

      final pickDocBtn = find.byKey(const Key('btn_pick_claim_document'));
      await tester.ensureVisible(pickDocBtn);
      await tester.tap(pickDocBtn);
      await tester.pumpAndSettle();

      final pickPhotoBtn = find.byKey(const Key('btn_pick_store_photo'));
      await tester.ensureVisible(pickPhotoBtn);
      await tester.tap(pickPhotoBtn);
      await tester.pumpAndSettle();

      // Pilih titik toko di peta (flutter_map menunggu ~250 ms untuk membedakan double tap)
      final locationMap = find.byKey(const Key('new_store_location_map'));
      await tester.ensureVisible(locationMap);
      await tester.tap(locationMap);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('btn_confirm_submit_new_store'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Memastikan pesan error 503 dari backend ditampilkan secara jelas
      expect(
        find.textContaining('Penyimpanan belum tersedia, coba lagi nanti'),
        findsWidgets,
      );
      // Memastikan pesan sukses TIDAK ditampilkan
      expect(
        find.text('Pengajuan toko baru berhasil dikirim. Menunggu verifikasi admin.'),
        findsNothing,
      );
    });
  });
}
