import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/profile/data/static_legal_content.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/document_viewer_page.dart';

void main() {
  group('DocumentViewerPage - Content Rendering Tests', () {
    testWidgets('renders Kebijakan Privasi with title, last updated, and first section', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DocumentViewerPage(content: privacyPolicyContent),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kebijakan Privasi'), findsOneWidget);
      expect(find.text('Terakhir diperbarui: 30 September 2026'), findsOneWidget);
      expect(find.text('1. Pendahuluan'), findsOneWidget);
      expect(find.textContaining('Selamat datang di RAKOON'), findsOneWidget);
    });

    testWidgets('renders Syarat & Ketentuan with title, last updated, and first section', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DocumentViewerPage(content: termsOfServiceContent),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Syarat & Ketentuan'), findsOneWidget);
      expect(find.text('Terakhir diperbarui: 30 September 2026'), findsOneWidget);
      expect(find.text('1. Penerimaan Ketentuan'), findsOneWidget);
      expect(find.textContaining('Dengan mengunduh, mengakses, atau menggunakan'), findsOneWidget);
    });

    testWidgets('renders Bantuan with title, first section, and developer contact without last updated header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DocumentViewerPage(content: helpContent),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bantuan'), findsOneWidget);
      expect(find.textContaining('Terakhir diperbarui'), findsNothing);
      expect(find.text('1. Tentang Rakoon'), findsOneWidget);
      expect(find.textContaining('asisten belanja cerdas'), findsOneWidget);

      final distanceNoteFinder = find.textContaining('Jarak dihitung garis lurus dari lokasimu');
      await tester.scrollUntilVisible(distanceNoteFinder, 100);
      expect(distanceNoteFinder, findsOneWidget);

      final emailFinder = find.textContaining('ayyasheufrat2@gmail.com');
      await tester.scrollUntilVisible(emailFinder, 100);
      expect(emailFinder, findsOneWidget);
    });
  });

  group('DocumentViewerPage - Accessibility & Navigation', () {
    testWidgets('back button has touch target >= 48dp and Indonesian tooltip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DocumentViewerPage(content: helpContent),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byTooltip('Kembali');
      expect(backButton, findsOneWidget);

      final size = tester.getSize(backButton);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('DocumentViewerPage - Responsive Layout Verification', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('renders without overflow at ${width.toInt()}dp width', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: DocumentViewerPage(content: privacyPolicyContent),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
