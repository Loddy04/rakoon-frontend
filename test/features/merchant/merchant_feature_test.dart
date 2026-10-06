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
                  "days_left": 5
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
              "days_left": 7
            }),
            201,
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
        } else if (path.endsWith('/recommendation/products')) {
          return http.Response(
            jsonEncode({
              "category": "General",
              "category_title": "Rekomendasi",
              "products": []
            }),
            200,
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

    testWidgets('CreateAdCampaignPage opens QRIS payment modal and completes payment simulation', (tester) async {
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

        // Verify QRIS modal content
        expect(find.text('Pembayaran Iklan Promo'), findsOneWidget);
        expect(find.text('STANDAR PEMBAYARAN NASIONAL'), findsOneWidget);
        expect(find.text('PAMELA 6 SUPERMARKET'), findsOneWidget);
        expect(find.text('NMID: ID102026RAKOON01  •  YOGYAKARTA'), findsOneWidget);

        // Scroll and tap Selesaikan Pembayaran
        final payBtn = find.widgetWithText(ElevatedButton, 'Selesaikan Pembayaran (Rp 30.000)');
        expect(payBtn, findsOneWidget);
        await tester.ensureVisible(payBtn);
        await tester.pumpAndSettle();
        await tester.tap(payBtn);
        await tester.pumpAndSettle();

        // Verify Success Receipt View
        expect(find.text('Pembayaran Berhasil!'), findsOneWidget);
        expect(find.text('QRIS Dinamis (Verified)'), findsOneWidget);
        expect(find.text('Selesai & Lihat Iklan'), findsOneWidget);

        // Finish
        await tester.tap(find.text('Selesai & Lihat Iklan'));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('HomeScreen renders Promo Toko Sekitarmu carousel banner', (tester) async {
      await mockNetworkImagesFor(() async {
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
      });
    });
  });
}
