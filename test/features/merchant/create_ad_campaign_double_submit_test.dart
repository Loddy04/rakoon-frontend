import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/create_ad_campaign_page.dart';

// Satu aksi "buat iklan" tidak boleh membuat kampanye ganda: tap ganda diabaikan, dan
// kampanye yang sudah ada dipakai ulang (pay ulang) alih-alih create ulang.
void main() {
  late int createCalls;
  late int payCalls;
  late int failPayTimes;
  late MockClient client;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
    );
  });

  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'test-merchant-token',
      tokenType: 'bearer',
      user: User(
        id: 'test-merchant-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'merchant@rakoon.id',
      ),
    );
    createCalls = 0;
    payCalls = 0;
    failPayTimes = 0;
    client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/ads/campaigns') && request.method == 'POST') {
        createCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'id': 'ad-1',
            'store_id': 'store-1',
            'store_nama': 'Toko Uji',
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
          }),
          201,
        );
      }
      if (path.endsWith('/ads/campaigns/ad-1/pay') && request.method == 'POST') {
        payCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (failPayTimes > 0) {
          failPayTimes--;
          return http.Response(jsonEncode({'detail': 'Xendit lambat'}), 502);
        }
        return http.Response(
          jsonEncode({
            'campaign_id': 'ad-1',
            'external_id': 'INV-123',
            'amount': 30000,
            'currency': 'IDR',
            'status': 'PENDING',
            'invoice_url': 'https://checkout.xendit.co/inv-test',
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });
  });

  final reviewBtn = find.widgetWithText(ElevatedButton, 'Lanjut Pembayaran (Rp 30.000)');
  final submitBtn = find.widgetWithText(ElevatedButton, 'Buat Kampanye & Terbitkan Invoice (Rp 30.000)');
  final payBtn = find.text('Buka Checkout Xendit Sandbox');

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateAdCampaignPage(
        storeId: 'store-1',
        storeName: 'Toko Uji',
        baseUrl: 'https://api.test',
        httpClient: client,
        initialBannerUrl: 'https://example.com/banner.jpg',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Promo Susu Hemat');
    await tester.pumpAndSettle();
  }

  Future<void> openConfirmSheet(WidgetTester tester) async {
    await tester.ensureVisible(reviewBtn);
    await tester.pumpAndSettle();
    await tester.tap(reviewBtn);
    await tester.pumpAndSettle();
  }

  group('CreateAdCampaignPage anti kampanye ganda', () {
    testWidgets('dua tap cepat pada tombol buat -> create dipanggil sekali', (tester) async {
      await mockNetworkImagesFor(() async {
        await openPage(tester);
        await openConfirmSheet(tester);
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();

        await tester.tap(submitBtn);
        await tester.tap(submitBtn, warnIfMissed: false); // tanpa pump di antaranya
        await tester.pumpAndSettle();

        expect(createCalls, 1);
        expect(find.text('Kampanye Iklan Dibuat'), findsOneWidget);
      });
    });

    testWidgets('dua tap cepat pada tombol bayar -> pay dipanggil sekali', (tester) async {
      await mockNetworkImagesFor(() async {
        await openPage(tester);
        await openConfirmSheet(tester);
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        await tester.ensureVisible(payBtn);
        await tester.pumpAndSettle();
        await tester.tap(payBtn);
        await tester.tap(payBtn, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(payCalls, 1);
        expect(createCalls, 1);
      });
    });

    testWidgets('pay gagal lalu coba lagi -> create tidak dipanggil ulang', (tester) async {
      await mockNetworkImagesFor(() async {
        failPayTimes = 1;
        await openPage(tester);
        await openConfirmSheet(tester);
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        await tester.ensureVisible(payBtn);
        await tester.pumpAndSettle();
        await tester.tap(payBtn);
        await tester.pumpAndSettle();
        expect(payCalls, 1);

        await tester.tap(payBtn);
        await tester.pumpAndSettle();

        expect(payCalls, 2);
        expect(createCalls, 1);
        expect(find.text('Checkout Xendit'), findsOneWidget);
      });
    });

    testWidgets('tutup sheet setelah create lalu buka lagi -> pakai kampanye yang ada, bukan create ulang',
        (tester) async {
      await mockNetworkImagesFor(() async {
        await openPage(tester);
        await openConfirmSheet(tester);
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(createCalls, 1);

        await tester.tapAt(const Offset(5, 5)); // tutup sheet lewat barrier
        await tester.pumpAndSettle();
        expect(find.text('Kampanye Iklan Dibuat'), findsNothing);

        await openConfirmSheet(tester);
        if (submitBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(submitBtn);
          await tester.pumpAndSettle();
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();
        }

        expect(createCalls, 1);
        expect(find.text('Kampanye Iklan Dibuat'), findsOneWidget);
      });
    });
  });
}
