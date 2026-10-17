import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/core/utils/route_launcher.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_result_screen.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  tearDown(() {
    setMockRouteUrlLauncher(null);
  });

  BudgetRecommendResponse createResponse({
    double? lat,
    double? lng,
    double? distanceKm,
  }) {
    return BudgetRecommendResponse(
      budget: 50000.0,
      totalCost: 45000.0,
      remainingBudget: 5000.0,
      isFullMatch: true,
      recommendedStore: StoreInfoOutput(
        storeId: 'store-budget-1',
        nama: 'Super Indo Babarsari',
        alamat: 'Jl. Babarsari No. 12',
        lat: lat,
        lng: lng,
        distanceKm: distanceKm,
      ),
      items: [
        BudgetItemResult(
          productId: 'p1',
          namaProduk: 'Beras Premium 5kg',
          qty: 1,
          hargaSatuan: 45000.0,
          subtotal: 45000.0,
        ),
      ],
      explanation: 'Toko rekomendasi dalam budget.',
    );
  }

  group('BudgetResultScreen - Route Button & Navigation Tests', () {
    testWidgets('displays Rute button when recommendedStore has coordinates with touch target >= 48dp', (
      WidgetTester tester,
    ) async {
      final response = createResponse(lat: -7.7812, lng: 110.4156, distanceKm: 0.8);

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );
      await tester.pumpAndSettle();

      final routeButtonFinder = find.byKey(const Key('budget_store_route_button'));
      expect(routeButtonFinder, findsOneWidget);

      final size = tester.getSize(routeButtonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));

      final semantics = tester.getSemantics(routeButtonFinder);
      expect(semantics.label, contains('Rute'));
    });

    testWidgets('tapping Rute button opens Google Maps with origin, destination, and travelmode', (
      WidgetTester tester,
    ) async {
      Uri? launchedUri;
      LaunchMode? usedMode;

      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        usedMode = mode;
        return true;
      });

      final response = createResponse(lat: -7.7812, lng: 110.4156, distanceKm: 0.8);

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );
      await tester.pumpAndSettle();

      final routeButtonFinder = find.byKey(const Key('budget_store_route_button'));
      await tester.ensureVisible(routeButtonFinder);
      await tester.tap(routeButtonFinder);
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(
        launchedUri.toString(),
        'https://www.google.com/maps/dir/?api=1&origin=-6.2088,106.8456&destination=-7.7812,110.4156&travelmode=driving',
      );
      expect(launchedUri!.queryParameters['origin'], '-6.2088,106.8456');
      expect(launchedUri!.queryParameters['destination'], '-7.7812,110.4156');
      expect(usedMode, equals(LaunchMode.externalApplication));
    });

    testWidgets('hides Rute button when recommendedStore has null coordinates', (
      WidgetTester tester,
    ) async {
      final response = createResponse(lat: null, lng: null, distanceKm: 0.8);

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('budget_store_route_button')), findsNothing);
    });

    testWidgets('shows friendly SnackBar when launcher fails or throws', (
      WidgetTester tester,
    ) async {
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        return false;
      });

      final response = createResponse(lat: -7.7812, lng: 110.4156, distanceKm: 0.8);

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );
      await tester.pumpAndSettle();

      final routeButtonFinder = find.byKey(const Key('budget_store_route_button'));
      await tester.ensureVisible(routeButtonFinder);
      await tester.tap(routeButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Tidak dapat membuka rute ke Super Indo Babarsari'), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow at 320dp width', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final response = createResponse(lat: -7.7812, lng: 110.4156, distanceKm: 0.8);

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('budget_store_route_button')), findsOneWidget);
    });
  });
}
