import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/create_ad_campaign_page.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  group('Merchant Hub & Hyperlocal Offline Ads Tests', () {
    late MockClient mockClient;

    setUp(() {
      AuthService.mockSession = Session(
        accessToken: 'test-merchant-token',
        tokenType: 'bearer',
        user: User(
          id: 'test-merchant-id',
          appMetadata: {},
          userMetadata: {'full_name': 'Pak Budi'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'merchant@rakoon.id',
        ),
      );
      mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/ads/pricing-packages')) {
          return http.Response(
            jsonEncode([
              {
                "duration_days": 3,
                "name": "Paket Kilat (3 Hari)",
                "price": 15000,
                "description": "Ideal untuk promo akhir pekan JSM"
              },
              {
                "duration_days": 7,
                "name": "Paket Mingguan (7 Hari)",
                "price": 30000,
                "description": "Cocok untuk brosur mingguan"
              },
              {
                "duration_days": 14,
                "name": "Paket 2 Mingguan (14 Hari)",
                "price": 50000,
                "description": "Ekonomis untuk eksposur katalog gajian"
              }
            ]),
            200,
          );
        } else if (path.endsWith('/ads/home-banners')) {
          return http.Response(
            jsonEncode([
              {
                "id": "ad-1",
                "store_id": "store-pamela-6",
                "store_nama": "Pamela 6 Supermarket",
                "store_alamat": "Jl. Raya Condongcatur No. 12, Sleman",
                "store_lat": -7.7589,
                "store_lng": 110.4011,
                "title": "Promo JSM Minyak Goreng & Beras Hemat",
                "banner_url": "https://example.com/flyer1.jpg",
                "duration_days": 7,
                "price_paid": 30000,
                "distance_km": 1.2,
                "expires_at": "2026-10-15T00:00:00Z",
                "days_left": 5
              },
              {
                "id": "ad-2",
                "store_id": "store-mirota",
                "store_nama": "Mirota Kampus Simanjuntak",
                "store_alamat": "Jl. C. Simanjuntak No. 70, Terban, Kota Yogyakarta",
                "store_lat": -7.7788,
                "store_lng": 110.3752,
                "title": "Diskon Spesial Susu Segar & Buah Lokal",
                "banner_url": "https://example.com/flyer2.jpg",
                "duration_days": 3,
                "price_paid": 15000,
                "distance_km": 2.4,
                "expires_at": "2026-10-12T00:00:00Z",
                "days_left": 2
              }
            ]),
            200,
          );
        } else if (path.endsWith('/ads/my-store')) {
          return http.Response(
            jsonEncode({
              "is_claimed": true,
              "store_id": "store-pamela-6",
              "store_nama": "Pamela 6 Supermarket",
              "store_alamat": "Jl. Raya Condongcatur No. 12, Sleman",
              "campaigns": [
                {
                  "id": "ad-1",
                  "store_id": "store-pamela-6",
                  "store_nama": "Pamela 6 Supermarket",
                  "store_alamat": "Jl. Raya Condongcatur No. 12, Sleman",
                  "title": "Promo JSM Minyak Goreng & Beras Hemat",
                  "banner_url": "https://example.com/flyer1.jpg",
                  "duration_days": 7,
                  "price_paid": 30000,
                  "distance_km": 0.0,
                  "expires_at": "2026-10-15T00:00:00Z",
                  "days_left": 5,
                  "status": "active",
                  "payment_status": "paid"
                }
              ]
            }),
            200,
          );
        } else if (path.endsWith('/ads/campaigns')) {
          return http.Response(
            jsonEncode({
              "id": "ad-new-123",
              "store_id": "store-pamela-6",
              "store_nama": "Pamela 6 Supermarket",
              "store_alamat": "Jl. Raya Condongcatur No. 12, Sleman",
              "title": "Promo JSM Akhir Pekan Pamela 6 Supermarket",
              "banner_url": "https://example.com/flyer1.jpg",
              "duration_days": 7,
              "price_paid": 30000,
              "distance_km": 0.0,
              "expires_at": "2026-10-15T00:00:00Z",
              "days_left": 7,
              "status": "pending_payment",
              "payment_status": "unpaid",
              "payment_ref": "INV-20261010-ABCD1234"
            }),
            201,
          );
                } else if (path.endsWith('/pay')) {
          return http.Response(
            jsonEncode({
              "campaign_id": "ad-new-123",
              "external_id": "INV-20261010-ABCD1234",
              "xendit_invoice_id": "xinv-mock-999",
              "amount": 30000,
              "currency": "IDR",
              "status": "PENDING",
              "invoice_url": "https://checkout.xendit.co/inv-mock-999",
            }),
            200,
          );
        } else if (path.endsWith('/payment-status')) {
          return http.Response(
            jsonEncode({
              "campaign_id": "ad-new-123",
              "campaign_status": "pending_payment",
              "payment_status": "unpaid",
              "transaction_status": "PENDING",
              "external_id": "INV-20261010-ABCD1234",
              "xendit_invoice_id": "xinv-mock-999",
              "invoice_url": "https://checkout.xendit.co/inv-mock-999",
              "amount": 30000,
              "currency": "IDR",
            }),
            200,
          );
} else if (path.endsWith('/stores/nearby')) {
          return http.Response(
            jsonEncode({
              "source": "live",
              "stores": [
                {
                  "store_id": "store-pamela-6",
                  "nama": "Pamela 6 Supermarket",
                  "alamat": "Jl. Raya Condongcatur No. 12, Sleman",
                  "lat": -7.7589,
                  "lng": 110.4011,
                  "jarak_km": 1.2
                }
              ],
              "message": null
            }),
            200,
          );
        } else if (path.endsWith('/scan/recent')) {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.endsWith('/recommendation/recommended-products') || path.endsWith('/recommendation/products')) {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.host.contains('openstreetmap.org') || request.url.path.endsWith('.png')) {
          return http.Response.bytes(
            [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82],
            200,
            headers: {'content-type': 'image/png'},
          );
        }

        return http.Response(jsonEncode({}), 200);
      });
    });

    test('AdsService parses pricing packages and home banners properly', () async {
      final packages = await AdsService.getPricingPackages(
        baseUrl: 'https://api.test',
        client: mockClient,
      );
      expect(packages.length, 3);
      expect(packages[0].durationDays, 3);
      expect(packages[0].price, 15000);

      final banners = await AdsService.getHomeBanners(
        baseUrl: 'https://api.test',
        client: mockClient,
      );
      expect(banners.length, 2);
      expect(banners[0].storeNama, 'Pamela 6 Supermarket');
      expect(banners[0].distanceKm, 1.2);
      expect(banners[0].daysLeft, 5);
    });

    testWidgets('MerchantDashboardPage displays store info and active campaigns', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: MerchantDashboardPage(
              baseUrl: 'https://api.test',
              httpClient: mockClient,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Mitra Toko Rakoon'), findsOneWidget);
        expect(find.text('Pamela 6 Supermarket'), findsOneWidget);
        expect(find.text('Toko Terverifikasi'), findsOneWidget);
        expect(find.text('Kelola Foto Produk'), findsOneWidget);
        expect(find.text('Promo JSM Minyak Goreng & Beras Hemat'), findsOneWidget);
        expect(find.textContaining('Sisa 5 Hari'), findsOneWidget);
      });
    });

    testWidgets('MerchantDashboardPage keeps pending claims out of the ad dashboard', (tester) async {
      final pendingClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/my-store')) {
          return http.Response(jsonEncode({
            'is_claimed': false,
            'claim_status': 'pending',
            'store_id': 'store-pamela-6',
            'store_nama': 'Pamela 6 Supermarket',
            'campaigns': [],
          }), 200);
        }
        return http.Response(jsonEncode({}), 404);
      });

      await tester.pumpWidget(MaterialApp(
        home: MerchantDashboardPage(
          baseUrl: 'https://api.test',
          httpClient: pendingClient,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Klaim toko menunggu verifikasi'), findsOneWidget);
      expect(find.text('Periksa Status'), findsOneWidget);
      expect(find.text('Toko Terverifikasi'), findsNothing);
      expect(find.text('Klaim & Kelola Toko Ini'), findsNothing);
    });

    testWidgets('CreateAdCampaignPage renders duration options and payment summary', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: CreateAdCampaignPage(
              storeId: 'store-pamela-6',
              storeName: 'Pamela 6 Supermarket',
              baseUrl: 'https://api.test',
              httpClient: mockClient,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Pasang Iklan Promo'), findsOneWidget);
        expect(find.text('Pamela 6 Supermarket'), findsOneWidget);
        expect(find.text('Paket Kilat (3 Hari)'), findsOneWidget);
        expect(find.text('Paket Mingguan (7 Hari)'), findsOneWidget);
        expect(find.text('Paket 2 Mingguan (14 Hari)'), findsOneWidget);
      });
    });

    testWidgets('CreateAdCampaignPage opens confirmation modal and creates pending payment campaign', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: CreateAdCampaignPage(
              storeId: 'store-pamela-6',
              storeName: 'Pamela 6 Supermarket',
              baseUrl: 'https://api.test',
              httpClient: mockClient,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Scroll and tap Lanjut Pembayaran
        final lanjutBtn = find.widgetWithText(ElevatedButton, 'Lanjut Pembayaran (Rp 30.000)');
        expect(lanjutBtn, findsOneWidget);
        await tester.ensureVisible(lanjutBtn);
        await tester.pumpAndSettle();
        await tester.tap(lanjutBtn);
        await tester.pumpAndSettle();

        // Verify modal content shows honest pending status notice
        expect(find.text('Konfirmasi Kampanye Iklan'), findsOneWidget);
        expect(find.text('Mekanisme Penayangan Iklan'), findsOneWidget);
        expect(find.textContaining('Menunggu Pembayaran'), findsWidgets);
        expect(find.text('STANDAR PEMBAYARAN NASIONAL'), findsNothing);

        // Scroll and tap Buat Kampanye & Terbitkan Invoice
        final submitBtn = find.widgetWithText(ElevatedButton, 'Buat Kampanye & Terbitkan Invoice (Rp 30.000)');
        expect(submitBtn, findsOneWidget);
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Verify Success Invoice View shows pending status honestly
        expect(find.text('Kampanye Iklan Dibuat'), findsOneWidget);
        expect(find.text('Menunggu Pembayaran'), findsWidgets);
        expect(find.text('QRIS Dinamis (Verified)'), findsNothing);
        final finishBtn = find.widgetWithText(ElevatedButton, 'Selesai & Lihat Dasbor Merchant');
        expect(finishBtn, findsOneWidget);

        // Finish
        await tester.ensureVisible(finishBtn);
        await tester.pumpAndSettle();
        await tester.tap(finishBtn);
        await tester.pumpAndSettle();
      });
    });

    testWidgets('HomeScreen renders Promo & Fitur carousel banner', (tester) async {
      await mockNetworkImagesFor(() async {
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: HomeScreen(
                baseUrl: 'https://api.test',
                httpClient: mockClient,
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('Promo & Fitur'), findsOneWidget);
          expect(find.text('✦ Rakoon AI & Mitra'), findsOneWidget);

          // Geser ke slide banner promo (slide 1)
          await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
          await tester.pumpAndSettle();

          expect(find.text('Promo JSM Minyak Goreng & Beras Hemat'), findsOneWidget);
        }, () => mockClient);
      });
    });

    testWidgets('HomeScreen renders Smart Shelf Scan when home-banners response is empty', (tester) async {
      final emptyClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/home-banners')) {
          return http.Response(jsonEncode([]), 200);
        }
        return mockClient.send(request).then(http.Response.fromStream);
      });

      await mockNetworkImagesFor(() async {
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: HomeScreen(
                baseUrl: 'https://api.test',
                httpClient: emptyClient,
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('Promo & Fitur'), findsOneWidget);
          expect(find.text('✦ Rakoon AI & Mitra'), findsNothing);
          expect(find.text('Smart Shelf Scan\nPindai Rak Belanja'), findsOneWidget);
        }, () => emptyClient);
      });
    });

    testWidgets('HomeScreen handles error safely without crashing and does not display Promo kosong', (tester) async {
      final errorClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/home-banners')) {
          return http.Response('Internal Server Error', 500);
        }
        return mockClient.send(request).then(http.Response.fromStream);
      });

      await mockNetworkImagesFor(() async {
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: HomeScreen(
                baseUrl: 'https://api.test',
                httpClient: errorClient,
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('Promo kosong'), findsNothing);
          expect(tester.takeException(), isNull);
        }, () => errorClient);
      });
    });

    test('AdsService.getHomeBanners appends include_demo=true when includeDemo is true', () async {
      bool capturedIncludeDemo = false;
      final checkClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/home-banners')) {
          capturedIncludeDemo = request.url.queryParameters['include_demo'] == 'true';
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('{}', 200);
      });

      await AdsService.getHomeBanners(
        baseUrl: 'https://api.test',
        client: checkClient,
        includeDemo: true,
      );

      expect(capturedIncludeDemo, isTrue);
    });

    testWidgets('HomeScreen with includeDemo: true passes include_demo and renders carousel banner', (tester) async {
      bool forwardedIncludeDemo = false;
      final demoClient = MockClient((request) async {
        if (request.url.path.endsWith('/ads/home-banners')) {
          forwardedIncludeDemo = request.url.queryParameters['include_demo'] == 'true';
          return http.Response(
            jsonEncode([
              {
                "id": "ad-demo-1",
                "store_id": "store-1",
                "store_nama": "Manna Kampus Babarsari",
                "store_alamat": "Jl. Raya Solo - Yogyakarta",
                "store_lat": -7.7831,
                "store_lng": 110.4145,
                "title": "Promo JSM Minyak Goreng & Beras Super Hemat",
                "banner_url": "https://example.com/demo1.jpg",
                "duration_days": 7,
                "price_paid": 30000,
                "distance_km": 0.7,
                "expires_at": "2026-10-18T08:55:33Z",
                "days_left": 7,
                "status": "active",
                "payment_method": "DEMO",
                "payment_status": "demo"
              }
            ]),
            200,
          );
        }
        return mockClient.send(request).then(http.Response.fromStream);
      });

      await mockNetworkImagesFor(() async {
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: HomeScreen(
                baseUrl: 'https://api.test',
                httpClient: demoClient,
                includeDemo: true,
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(forwardedIncludeDemo, isTrue);
          expect(find.text('Promo & Fitur'), findsOneWidget);
          expect(find.text('✦ Rakoon AI & Mitra'), findsOneWidget);

          // Geser ke slide banner promo demo (slide 1)
          await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
          await tester.pumpAndSettle();

          expect(find.text('Promo JSM Minyak Goreng & Beras Super Hemat'), findsOneWidget);
        }, () => demoClient);
      });
    });

    test('AdsService.initiatePayment requests official checkout URL', () async {
      final checkout = await AdsService.initiatePayment(
        campaignId: 'ad-new-123',
        baseUrl: 'https://api.test',
        client: mockClient,
      );

      expect(checkout.campaignId, 'ad-new-123');
      expect(checkout.externalId, 'INV-20261010-ABCD1234');
      expect(checkout.status, 'PENDING');
      expect(checkout.amount, 30000);
      expect(checkout.invoiceUrl, 'https://checkout.xendit.co/inv-mock-999');
    });

    test('AdsService.getPaymentStatus retrieves latest status from server', () async {
      final status = await AdsService.getPaymentStatus(
        campaignId: 'ad-new-123',
        baseUrl: 'https://api.test',
        client: mockClient,
      );

      expect(status.campaignId, 'ad-new-123');
      expect(status.campaignStatus, 'pending_payment');
      expect(status.paymentStatus, 'unpaid');
      expect(status.transactionStatus, 'PENDING');
      expect(status.amount, 30000);
    });

    group('Store Claim Rejection Reason & Re-claim Flow Tests', () {
      test('MyStoreData.fromJson mem-parsing rejection_reason yang ada', () {
        final json = {
          'is_claimed': false,
          'claim_status': 'rejected',
          'store_id': 'store-123',
          'store_nama': 'Toko ABC',
          'rejection_reason': 'Dokumen SIUP tidak terbaca jelas.',
          'campaigns': [],
        };
        final data = MyStoreData.fromJson(json);
        expect(data.isClaimed, false);
        expect(data.claimStatus, 'rejected');
        expect(data.rejectionReason, 'Dokumen SIUP tidak terbaca jelas.');
      });

      test('MyStoreData.fromJson menangani rejection_reason yang null', () {
        final json = {
          'is_claimed': false,
          'claim_status': 'rejected',
          'store_id': 'store-123',
          'rejection_reason': null,
          'campaigns': [],
        };
        final data = MyStoreData.fromJson(json);
        expect(data.rejectionReason, isNull);
      });

      testWidgets('MerchantDashboardPage menampilkan teks alasan penolakan saat rejection_reason tersedia', (tester) async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/my-store')) {
            return http.Response(jsonEncode({
              'is_claimed': false,
              'claim_status': 'rejected',
              'store_id': 'store-pamela-6',
              'store_nama': 'Pamela 6 Supermarket',
              'rejection_reason': 'Toko telah diverifikasi untuk mitra lain.',
              'campaigns': [],
            }), 200);
          } else if (request.url.path.endsWith('/stores/nearby')) {
            return http.Response(jsonEncode({'source': 'live', 'stores': []}), 200);
          }
          return http.Response(jsonEncode({}), 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('rejected_claim_banner')), findsOneWidget);
        expect(find.text('Klaim Ditolak: Toko telah diverifikasi untuk mitra lain.'), findsOneWidget);
      });

      testWidgets('MerchantDashboardPage menampilkan fallback default saat rejection_reason null atau kosong', (tester) async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/my-store')) {
            return http.Response(jsonEncode({
              'is_claimed': false,
              'claim_status': 'rejected',
              'store_id': 'store-pamela-6',
              'store_nama': 'Pamela 6 Supermarket',
              'rejection_reason': null,
              'campaigns': [],
            }), 200);
          } else if (request.url.path.endsWith('/stores/nearby')) {
            return http.Response(jsonEncode({'source': 'live', 'stores': []}), 200);
          }
          return http.Response(jsonEncode({}), 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('rejected_claim_banner')), findsOneWidget);
        expect(find.text('Permohonan klaim toko Anda sebelumnya ditolak oleh admin.'), findsOneWidget);
      });

      testWidgets('MerchantDashboardPage merender tombol klaim ulang saat status rejected', (tester) async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/my-store')) {
            return http.Response(jsonEncode({
              'is_claimed': false,
              'claim_status': 'rejected',
              'rejection_reason': 'Data tidak valid',
              'campaigns': [],
            }), 200);
          } else if (request.url.path.endsWith('/stores/nearby')) {
            return http.Response(jsonEncode({
              'source': 'live',
              'stores': [
                {
                  'store_id': 'store-pamela-6',
                  'nama': 'Pamela 6 Supermarket',
                  'alamat': 'Jl. Raya Condongcatur',
                }
              ]
            }), 200);
          }
          return http.Response(jsonEncode({}), 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Klaim & Kelola Toko Ini'), findsOneWidget);
      });

      testWidgets('Tombol klaim ulang memicu alur klaim ulang yang benar', (tester) async {
        bool claimCalled = false;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/my-store')) {
            return http.Response(jsonEncode({
              'is_claimed': false,
              'claim_status': claimCalled ? 'pending' : 'rejected',
              'rejection_reason': claimCalled ? null : 'Data tidak lengkap',
              'campaigns': [],
            }), 200);
          } else if (request.url.path.endsWith('/stores/nearby')) {
            return http.Response(jsonEncode({
              'source': 'live',
              'stores': [
                {
                  'store_id': 'store-pamela-6',
                  'nama': 'Pamela 6 Supermarket',
                  'alamat': 'Jl. Raya Condongcatur',
                }
              ]
            }), 200);
          } else if (request.url.path.endsWith('/ads/claim-store') && request.method == 'POST') {
            claimCalled = true;
            return http.Response(jsonEncode({
              'status': 'pending',
              'store_id': 'store-pamela-6',
              'message': 'Permohonan klaim berhasil diajukan.',
            }), 200);
          }
          return http.Response(jsonEncode({}), 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        final claimBtn = find.text('Klaim & Kelola Toko Ini');
        expect(claimBtn, findsOneWidget);
        await tester.tap(claimBtn);
        await tester.pumpAndSettle();

        expect(claimCalled, isTrue);
      });
    });

    group('Checkout UX & Launch URL Tests', () {
      test('PaymentCheckoutData.hasValidCheckoutUrl validates HTTPS URLs correctly', () {
        const valid = PaymentCheckoutData(
          campaignId: 'c-1',
          externalId: 'ext-1',
          amount: 15000,
          status: 'PENDING',
          invoiceUrl: 'https://checkout.xendit.co/inv-12345',
        );
        expect(valid.hasValidCheckoutUrl, isTrue);

        const nullUrl = PaymentCheckoutData(
          campaignId: 'c-1',
          externalId: 'ext-1',
          amount: 15000,
          status: 'PENDING',
          invoiceUrl: null,
        );
        expect(nullUrl.hasValidCheckoutUrl, isFalse);

        const emptyUrl = PaymentCheckoutData(
          campaignId: 'c-1',
          externalId: 'ext-1',
          amount: 15000,
          status: 'PENDING',
          invoiceUrl: '   ',
        );
        expect(emptyUrl.hasValidCheckoutUrl, isFalse);

        const insecureUrl = PaymentCheckoutData(
          campaignId: 'c-1',
          externalId: 'ext-1',
          amount: 15000,
          status: 'PENDING',
          invoiceUrl: 'http://insecure-checkout.test/inv-1',
        );
        expect(insecureUrl.hasValidCheckoutUrl, isFalse);

        const badScheme = PaymentCheckoutData(
          campaignId: 'c-1',
          externalId: 'ext-1',
          amount: 15000,
          status: 'PENDING',
          invoiceUrl: 'javascript:alert(1)',
        );
        expect(badScheme.hasValidCheckoutUrl, isFalse);
      });

      test('PaymentStatusData.hasValidCheckoutUrl validates HTTPS URLs correctly', () {
        const valid = PaymentStatusData(
          campaignId: 'c-1',
          campaignStatus: 'pending_payment',
          paymentStatus: 'unpaid',
          invoiceUrl: 'https://checkout.xendit.co/inv-abc',
        );
        expect(valid.hasValidCheckoutUrl, isTrue);

        const invalid = PaymentStatusData(
          campaignId: 'c-1',
          campaignStatus: 'pending_payment',
          paymentStatus: 'unpaid',
          invoiceUrl: 'http://plain.test',
        );
        expect(invalid.hasValidCheckoutUrl, isFalse);
      });

      test('AdsService.launchCheckoutUrl opens HTTPS URL in externalApplication', () async {
        Uri? launchedUri;
        LaunchMode? launchedMode;

        final result = await AdsService.launchCheckoutUrl(
          'https://checkout.xendit.co/inv-valid-999',
          customLauncher: (uri, {mode = LaunchMode.platformDefault}) async {
            launchedUri = uri;
            launchedMode = mode;
            return true;
          },
        );

        expect(result, isTrue);
        expect(launchedUri, Uri.parse('https://checkout.xendit.co/inv-valid-999'));
        expect(launchedMode, LaunchMode.externalApplication);
      });

      test('AdsService.launchCheckoutUrl rejects non-HTTPS or empty URLs safely', () async {
        bool launcherCalled = false;
        Future<bool> mockLauncher(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          launcherCalled = true;
          return true;
        }

        expect(await AdsService.launchCheckoutUrl(null, customLauncher: mockLauncher), isFalse);
        expect(await AdsService.launchCheckoutUrl('', customLauncher: mockLauncher), isFalse);
        expect(await AdsService.launchCheckoutUrl('http://insecure.test', customLauncher: mockLauncher), isFalse);
        expect(await AdsService.launchCheckoutUrl('ftp://example.com', customLauncher: mockLauncher), isFalse);
        expect(launcherCalled, isFalse);
      });

      test('AdsService.launchCheckoutUrl handles launcher exception safely without crash', () async {
        final result = await AdsService.launchCheckoutUrl(
          'https://checkout.xendit.co/inv-fail',
          customLauncher: (uri, {mode = LaunchMode.platformDefault}) async {
            throw Exception('Platform failure');
          },
        );
        expect(result, isFalse);
      });

      testWidgets('CreateAdCampaignPage modal displays Buka Checkout button for valid HTTPS invoice', (tester) async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/pricing-packages')) {
            return http.Response(jsonEncode([
              {'duration_days': 7, 'name': 'Paket Mingguan', 'price': 30000, 'description': '7 hari'}
            ]), 200);
          } else if (request.url.path.endsWith('/ads/campaigns') && request.method == 'POST') {
            return http.Response(jsonEncode({
              'id': 'ad-checkout-1',
              'store_id': 'store-1',
              'store_nama': 'Pamela 6 Supermarket',
              'title': 'Promo Susu Hemat',
              'banner_url': 'https://example.com/banner.jpg',
              'duration_days': 7,
              'price_paid': 30000,
              'distance_km': 0.0,
              'expires_at': '2026-10-18T00:00:00Z',
              'days_left': 7,
              'status': 'pending_payment',
              'payment_status': 'unpaid',
              'payment_ref': 'INV-123',
            }), 201);
          } else if (request.url.path.endsWith('/ads/campaigns/ad-checkout-1/pay') && request.method == 'POST') {
            return http.Response(jsonEncode({
              'campaign_id': 'ad-checkout-1',
              'external_id': 'INV-123',
              'amount': 30000,
              'currency': 'IDR',
              'status': 'PENDING',
              'invoice_url': 'https://checkout.xendit.co/inv-test-checkout',
            }), 200);
          }
          return http.Response('{}', 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: CreateAdCampaignPage(
            storeId: 'store-1',
            storeName: 'Pamela 6 Supermarket',
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        // Fill form
        await tester.enterText(find.byType(TextField).at(0), 'Promo Susu Hemat');
        await tester.enterText(find.byType(TextField).at(1), 'https://example.com/banner.jpg');
        await tester.pumpAndSettle();

        // Tap review button
        final lanjutBtn = find.widgetWithText(ElevatedButton, 'Lanjut Pembayaran (Rp 30.000)');
        expect(lanjutBtn, findsOneWidget);
        await tester.ensureVisible(lanjutBtn);
        await tester.pumpAndSettle();
        await tester.tap(lanjutBtn);
        await tester.pumpAndSettle();

        // Confirm creation
        final submitBtn = find.widgetWithText(ElevatedButton, 'Buat Kampanye & Terbitkan Invoice (Rp 30.000)');
        expect(submitBtn, findsOneWidget);
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // View now shows Buka Checkout Xendit Sandbox button
        final payBtn = find.text('Buka Checkout Xendit Sandbox');
        expect(payBtn, findsOneWidget);
        await tester.ensureVisible(payBtn);
        await tester.pumpAndSettle();
        await tester.tap(payBtn);
        await tester.pumpAndSettle();

        // Checkout Dialog is opened
        expect(find.byKey(const Key('open_checkout_url_button')), findsOneWidget);
        expect(find.byKey(const Key('copy_checkout_url_button')), findsOneWidget);
        expect(find.text('Buka Checkout'), findsOneWidget);
        expect(find.text('Salin Link'), findsOneWidget);

        // Tap copy button
        await tester.tap(find.byKey(const Key('copy_checkout_url_button')));
        await tester.pumpAndSettle();

        // Close dialog
        await tester.tap(find.byKey(const Key('close_checkout_dialog_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('open_checkout_url_button')), findsNothing);
      });

      testWidgets('MerchantDashboardPage Bayar Xendit opens checkout dialog with Buka Checkout button', (tester) async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/my-store')) {
            return http.Response(jsonEncode({
              'is_claimed': true,
              'claim_status': 'verified',
              'store_id': 'store-1',
              'store_nama': 'Pamela 6 Supermarket',
              'campaigns': [
                {
                  'id': 'ad-10',
                  'store_id': 'store-1',
                  'store_nama': 'Pamela 6 Supermarket',
                  'title': 'Promo Minyak Murah',
                  'banner_url': 'https://example.com/oil.jpg',
                  'duration_days': 7,
                  'price_paid': 30000,
                  'distance_km': 0.0,
                  'expires_at': '2026-10-18T00:00:00Z',
                  'days_left': 7,
                  'status': 'pending_payment',
                  'payment_status': 'unpaid',
                  'payment_ref': 'INV-OIL-1',
                }
              ],
            }), 200);
          } else if (request.url.path.endsWith('/ads/campaigns/ad-10/pay') && request.method == 'POST') {
            return http.Response(jsonEncode({
              'campaign_id': 'ad-10',
              'external_id': 'INV-OIL-1',
              'amount': 30000,
              'currency': 'IDR',
              'status': 'PENDING',
              'invoice_url': 'https://checkout.xendit.co/inv-oil-pay',
            }), 200);
          }
          return http.Response('{}', 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        final payBtn = find.text('Bayar Xendit');
        expect(payBtn, findsOneWidget);
        await tester.tap(payBtn);
        await tester.pumpAndSettle();

        // Dialog opens with Buka Checkout and Salin Link
        expect(find.byKey(const Key('open_checkout_url_button')), findsOneWidget);
        expect(find.byKey(const Key('copy_checkout_url_button')), findsOneWidget);
        expect(find.text('Buka Checkout'), findsOneWidget);
        expect(find.text('Salin Link'), findsOneWidget);

        // Closing dialog keeps status pending_payment
        await tester.tap(find.byKey(const Key('close_checkout_dialog_button')));
        await tester.pumpAndSettle();

        expect(find.text('Menunggu Pembayaran'), findsOneWidget);
        expect(find.text('Bayar Xendit'), findsOneWidget);
      });
    });

    group('Store Claim Error Handling & FormatException Prevention Tests', () {
      test('extractErrorMessage handles plain-text 500 without FormatException', () {
        final resp = http.Response('Internal Server Error', 500);
        final msg = AdsService.extractErrorMessage(resp);
        expect(msg, 'Terjadi kesalahan pada server. Silakan coba lagi.');
      });

      test('extractErrorMessage handles HTML 502/503 without FormatException', () {
        final resp = http.Response('<html><body>502 Bad Gateway</body></html>', 502);
        final msg = AdsService.extractErrorMessage(resp);
        expect(msg, 'Terjadi kesalahan pada server. Silakan coba lagi.');
      });

      test('extractErrorMessage extracts detail from structured JSON error', () {
        final resp = http.Response(
          jsonEncode({'detail': 'Toko ini sudah memiliki pemilik terverifikasi.'}),
          409,
        );
        final msg = AdsService.extractErrorMessage(resp);
        expect(msg, 'Toko ini sudah memiliki pemilik terverifikasi.');
      });

      test('extractErrorMessage filters raw internal SQL/traceback leaks', () {
        final resp = http.Response(
          jsonEncode({'detail': 'psycopg2.errors.UndefinedColumn: column store_owners.rejection_reason does not exist'}),
          400,
        );
        final msg = AdsService.extractErrorMessage(resp);
        expect(msg, 'Terjadi kesalahan pada server. Silakan coba lagi.');
      });

      test('AdsService.claimStore throws Exception with friendly server message on 500 without FormatException', () async {
        final mock500Client = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        expect(
          () => AdsService.claimStore(
            storeId: 'store-1',
            baseUrl: 'https://api.test',
            client: mock500Client,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Terjadi kesalahan pada server. Silakan coba lagi.'),
            ),
          ),
        );
      });

      testWidgets('MerchantDashboardPage displays clean error message in SnackBar on 500 plain text without FormatException', (tester) async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/my-store')) {
            return http.Response(jsonEncode({
              'is_claimed': false,
              'campaigns': [],
            }), 200);
          } else if (request.url.path.endsWith('/stores/nearby')) {
            return http.Response(jsonEncode({
              'source': 'live',
              'stores': [
                {
                  'store_id': 'store-pamela-6',
                  'nama': 'Pamela 6 Supermarket',
                  'alamat': 'Jl. Raya Condongcatur',
                }
              ]
            }), 200);
          } else if (request.url.path.endsWith('/ads/claim-store')) {
            return http.Response('Internal Server Error', 500);
          }
          return http.Response('{}', 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        final claimBtn = find.text('Klaim & Kelola Toko Ini');
        expect(claimBtn, findsOneWidget);
        await tester.tap(claimBtn);
        await tester.pumpAndSettle();

        // Must display friendly Indonesian error
        expect(find.text('Gagal mengklaim toko: Terjadi kesalahan pada server. Silakan coba lagi.'), findsOneWidget);
        // Must NOT display FormatException or raw Internal Server Error
        expect(find.textContaining('FormatException'), findsNothing);
      });
    });

    group('Payment Synchronization & App Lifecycle Tests', () {
      testWidgets('MerchantDashboardPage automatically reloads data when app resumes from external browser', (tester) async {
        int getMyStoreCalls = 0;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/my-store')) {
            getMyStoreCalls++;
            return http.Response(jsonEncode({
              'is_claimed': true,
              'claim_status': 'verified',
              'store_id': 'store-1',
              'store_nama': 'Pamela 6 Supermarket',
              'campaigns': [
                {
                  'id': 'ad-10',
                  'store_id': 'store-1',
                  'store_nama': 'Pamela 6 Supermarket',
                  'title': 'Promo Minyak Murah',
                  'banner_url': 'https://example.com/oil.jpg',
                  'duration_days': 7,
                  'price_paid': 30000,
                  'distance_km': 0.0,
                  'expires_at': '2026-10-18T00:00:00Z',
                  'days_left': 7,
                  'status': getMyStoreCalls > 1 ? 'active' : 'pending_payment',
                  'payment_status': getMyStoreCalls > 1 ? 'paid' : 'unpaid',
                  'payment_ref': 'INV-OIL-1',
                }
              ],
            }), 200);
          }
          return http.Response('{}', 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        expect(getMyStoreCalls, 1);
        expect(find.text('Menunggu Pembayaran'), findsOneWidget);

        // Simulate returning to the app from external browser (resumed lifecycle)
        final state = tester.state(find.byType(MerchantDashboardPage)) as WidgetsBindingObserver;
        state.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pumpAndSettle();

        // getMyStore was called again and UI updated
        expect(getMyStoreCalls, 2);
        expect(find.text('Menunggu Pembayaran'), findsNothing);
        expect(find.text('Paket 7 Hari'), findsOneWidget);
      });

      testWidgets('Tapping Cek Status updates pending campaign to active when paid', (tester) async {
        bool isPaid = false;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/my-store')) {
            return http.Response(jsonEncode({
              'is_claimed': true,
              'claim_status': 'verified',
              'store_id': 'store-1',
              'store_nama': 'Pamela 6 Supermarket',
              'campaigns': [
                {
                  'id': 'ad-10',
                  'store_id': 'store-1',
                  'store_nama': 'Pamela 6 Supermarket',
                  'title': 'Promo Minyak Murah',
                  'banner_url': 'https://example.com/oil.jpg',
                  'duration_days': 7,
                  'price_paid': 30000,
                  'distance_km': 0.0,
                  'expires_at': '2026-10-18T00:00:00Z',
                  'days_left': 7,
                  'status': isPaid ? 'active' : 'pending_payment',
                  'payment_status': isPaid ? 'paid' : 'unpaid',
                  'payment_ref': 'INV-OIL-1',
                }
              ],
            }), 200);
          } else if (request.url.path.endsWith('/ads/campaigns/ad-10/payment-status')) {
            isPaid = true;
            return http.Response(jsonEncode({
              'campaign_id': 'ad-10',
              'campaign_status': 'active',
              'payment_status': 'paid',
              'transaction_status': 'PAID',
              'amount': 30000,
            }), 200);
          }
          return http.Response('{}', 200);
        });

        await tester.pumpWidget(MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'https://api.test',
            httpClient: client,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Menunggu Pembayaran'), findsOneWidget);
        final checkBtn = find.text('Cek Status');
        expect(checkBtn, findsOneWidget);

        await tester.tap(checkBtn);
        await tester.pumpAndSettle();

        // Verification SnackBar appears
        expect(find.text('Pembayaran berhasil diverifikasi! Iklan telah aktif.'), findsOneWidget);
        // Status badge updated
        expect(find.text('Menunggu Pembayaran'), findsNothing);
      });
    });
  });
}
