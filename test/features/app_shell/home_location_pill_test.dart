import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';

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
