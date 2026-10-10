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
        expect(find.text('Sisa 5 Hari'), findsOneWidget);
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
        expect(find.text('Menunggu Pembayaran'), findsWidgets);
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

    testWidgets('HomeScreen renders Promo Toko Sekitarmu carousel banner', (tester) async {
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

          expect(find.text('Promo Toko Sekitarmu'), findsOneWidget);
          expect(find.text('Mitra Ritel'), findsOneWidget);
          expect(find.text('Promo JSM Minyak Goreng & Beras Hemat'), findsOneWidget);
        }, () => mockClient);
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
  });
}
