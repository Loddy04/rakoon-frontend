import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/services/ads_service.dart';

void main() {
  group('HomePromoBanner without payment fields (public response)', () {
    final publicJson = {
      'id': 'b1',
      'store_id': 's1',
      'store_nama': 'Toko Jogja',
      'title': 'Promo',
      'banner_url': 'https://example.com/b.jpg',
      'duration_days': 7,
      'distance_km': 1.2,
      'expires_at': '2026-10-20T00:00:00Z',
      'days_left': 5,
      'status': 'active',
      'payment_method': 'QRIS',
      'payment_status': 'paid',
    };

    test('fromJson parses a response with no price_paid and no payment_ref', () {
      final banner = HomePromoBanner.fromJson(publicJson);
      expect(banner.title, 'Promo');
      expect(banner.pricePaid, 0);
      expect(banner.paymentRef, isNull);
      expect(banner.paymentStatus, 'paid');
    });

    test('owner responses that still carry the fields keep them', () {
      final banner = HomePromoBanner.fromJson({...publicJson, 'price_paid': 30000, 'payment_ref': 'inv-1'});
      expect(banner.pricePaid, 30000);
      expect(banner.paymentRef, 'inv-1');
    });

    test('constructor no longer requires pricePaid', () {
      const banner = HomePromoBanner(
        id: 'b1',
        storeId: 's1',
        storeNama: 'Toko',
        title: 'Promo',
        bannerUrl: 'https://example.com/b.jpg',
        durationDays: 3,
        distanceKm: 0.5,
        expiresAt: '2026-10-20T00:00:00Z',
        daysLeft: 2,
      );
      expect(banner.pricePaid, 0);
      expect(banner.paymentRef, isNull);
    });
  });

  group('PendingStoreClaimData coordinates (admin queue)', () {
    final base = {
      'user_id': 'u1',
      'store_nama': 'Warung Baru',
      'status': 'pending',
      'created_at': '2026-10-15T00:00:00Z',
      'claim_type': 'new_store',
    };

    test('parses latitude and longitude of a new-store submission', () {
      final claim = PendingStoreClaimData.fromJson({...base, 'latitude': 3.5952, 'longitude': 98.6722});
      expect(claim.latitude, 3.5952);
      expect(claim.longitude, 98.6722);
    });

    test('integer-valued coordinates parse as double', () {
      final claim = PendingStoreClaimData.fromJson({...base, 'latitude': 3, 'longitude': 98});
      expect(claim.latitude, 3.0);
      expect(claim.longitude, 98.0);
    });

    test('missing or null coordinates are null (legacy rows and existing-store claims)', () {
      expect(PendingStoreClaimData.fromJson(base).latitude, isNull);
      final nulls = PendingStoreClaimData.fromJson({...base, 'latitude': null, 'longitude': null});
      expect(nulls.latitude, isNull);
      expect(nulls.longitude, isNull);
    });
  });
}
