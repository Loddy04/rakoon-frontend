import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/services/location_service.dart';

void main() {
  group('HomeScreen Location Pill Tests', () {
    testWidgets('Renders header with Rakoon brand and location pill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Verify brand title
      expect(find.text('Rakoon'), findsOneWidget);

      // Verify location icon
      expect(find.byIcon(Icons.location_on), findsOneWidget);

      // Verify pill semantics
      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.startsWith('Lokasi terdeteksi:'),
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('Displays current location name when GPS is active and detected', (
      WidgetTester tester,
    ) async {
      LocationService.testIsLocationServiceEnabled = true;
      addTearDown(() => LocationService.testIsLocationServiceEnabled = null);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Displays the current location name (Babarsari in mock)
      expect(find.text('Babarsari'), findsOneWidget);
    });

    testWidgets('Displays "Tidak Terdeteksi" when GPS is disabled and prompts settings on tap', (
      WidgetTester tester,
    ) async {
      LocationService.testIsLocationServiceEnabled = false;
      bool settingsOpened = false;
      LocationService.onOpenLocationSettings = () {
        settingsOpened = true;
      };
      addTearDown(() {
        LocationService.testIsLocationServiceEnabled = null;
        LocationService.onOpenLocationSettings = null;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify label is "Tidak Terdeteksi" and not "Pilih Lokasi"
      expect(find.text('Tidak Terdeteksi'), findsOneWidget);
      expect(find.text('Pilih Lokasi'), findsNothing);

      // Tap location pill
      await tester.tap(find.text('Tidak Terdeteksi'));
      await tester.pumpAndSettle();

      // Verify bottom sheet modal is displayed
      expect(find.text('Layanan Lokasi (GPS) Nonaktif'), findsOneWidget);
      expect(find.textContaining('Layanan lokasi pada perangkat Anda belum aktif'), findsOneWidget);
      expect(find.text('Buka Pengaturan Lokasi'), findsOneWidget);

      // Tap Buka Pengaturan Lokasi
      await tester.tap(find.text('Buka Pengaturan Lokasi'));
      await tester.pumpAndSettle();

      expect(settingsOpened, isTrue);
    });

    testWidgets('Tapping location pill navigates to NearbyStoresScreen when GPS is active', (
      WidgetTester tester,
    ) async {
      LocationService.testIsLocationServiceEnabled = true;
      addTearDown(() => LocationService.testIsLocationServiceEnabled = null);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Babarsari'), findsOneWidget);

      await tester.tap(find.text('Babarsari'));
      await tester.pumpAndSettle();

      // Verify navigation to NearbyStoresScreen
      expect(find.byType(NearbyStoresScreen), findsOneWidget);
    });

    testWidgets('Header remains responsive at 320dp without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rakoon'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Header remains responsive at 390dp (standard iPhone)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rakoon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Header remains responsive at 430dp (Pro Max)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rakoon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
