import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  tearDown(() {
    Supabase.instance.client.auth.stopAutoRefresh();
  });

  group('Camera Lifecycle & AppShell Active-Tab Tests', () {
    testWidgets('Initial AppShell launch starts on Home (Scan tab is inactive)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Home is visible and active
      expect(find.text('Rakoon'), findsOneWidget);

      // Verify ScanCameraScreen is mounted with isActive: false (offstage)
      final scanFinder = find.byType(ScanCameraScreen, skipOffstage: false);
      expect(scanFinder, findsOneWidget);

      final ScanCameraScreen scanWidget = tester.widget(scanFinder);
      expect(scanWidget.isActive, isFalse);
    });

    testWidgets('Switching Home -> Scan tab sets isActive to true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Scan tab (Index 1)
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();

      // Verify ScanCameraScreen is on stage and has isActive: true
      final scanFinder = find.byType(ScanCameraScreen);
      expect(scanFinder, findsOneWidget);

      final ScanCameraScreen scanWidget = tester.widget(scanFinder);
      expect(scanWidget.isActive, isTrue);

      // Bottom nav is hidden when Scan tab is active
      expect(find.byKey(const Key('nav_tab_0')), findsNothing);
    });

    testWidgets('Closing Scan tab returns to Home and sets isActive to false (Releases camera)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Scan
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();

      expect(tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen)).isActive, isTrue);

      // Tap close button in ScanCameraScreen
      await tester.tap(find.byKey(const Key('scan_close_button')));
      await tester.pumpAndSettle();

      // Verify Home is back
      expect(find.text('Rakoon'), findsOneWidget);

      // Verify ScanCameraScreen is now inactive (offstage)
      expect(
        tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen, skipOffstage: false)).isActive,
        isFalse,
      );
    });

    testWidgets('Switching Scan -> Profile tab sets isActive to false and releases camera', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Profile tab (Index 2)
      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pumpAndSettle();

      // Verify Profile is active
      expect(find.text('Profil'), findsWidgets);

      // Verify Scan is inactive (offstage)
      expect(
        tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen, skipOffstage: false)).isActive,
        isFalse,
      );
    });

    testWidgets('Returning Profile -> Scan sets isActive to true (Recreates camera)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Profile
      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen, skipOffstage: false)).isActive,
        isFalse,
      );

      // Go to Scan
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();
      expect(tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen)).isActive, isTrue);
    });

    testWidgets('Standalone ScanCameraScreen defaults to isActive: true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanCameraScreen(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      final ScanCameraScreen widget = tester.widget(find.byType(ScanCameraScreen));
      expect(widget.isActive, isTrue);
    });

    testWidgets('Rapid tab switching does not throw or cause race condition exceptions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pump();

      // Rapidly trigger tab switches without settling
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('scan_close_button')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('scan_close_button')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Rakoon'), findsOneWidget);
    });

    testWidgets('App backgrounding and foregrounding respects isActive state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Background while on Home (isActive == false)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen, skipOffstage: false)).isActive,
        isFalse,
      );
      expect(tester.takeException(), isNull);

      // 2. Switch to Scan (isActive == true) and background
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();
      expect(tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen)).isActive, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen)).isActive, isTrue);
      expect(tester.takeException(), isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      Supabase.instance.client.auth.stopAutoRefresh();
      await tester.pumpAndSettle();
    });

    testWidgets('Disposing ScanCameraScreen while inactive safely disposes without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            isActive: false,
          ),
        ),
      );
      await tester.pump();

      // Replace screen
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('ScanCameraScreen source preserves 3:4 viewfinder aspect ratio logic and contracts', () {
      final file = File('lib/features/scan/scan_camera_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('isActive'), isTrue);
      expect(content.contains('_deinitializeCamera'), isTrue);
      expect(content.contains('_initializeCamera'), isTrue);
      expect(content.contains('_cameraController!.value.aspectRatio > 1.0'), isTrue);
      expect(content.contains('1.0 / _cameraController!.value.aspectRatio'), isTrue);
    });
  });
}
