import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/profile/data/static_legal_content.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/document_viewer_page.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('DocumentViewerPage - Content & Links Rendering Tests', () {
    testWidgets('renders Bantuan with title, first section, developer contact, and two external links', (
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

      final privacyLinkFinder = find.text('Kebijakan Privasi');
      await tester.scrollUntilVisible(privacyLinkFinder, 100);
      expect(privacyLinkFinder, findsOneWidget);

      final termsLinkFinder = find.text('Syarat & Ketentuan');
      await tester.scrollUntilVisible(termsLinkFinder, 100);
      expect(termsLinkFinder, findsOneWidget);
    });

    testWidgets('tapping legal links in Bantuan launches corresponding URLs in external mode', (
      WidgetTester tester,
    ) async {
      Uri? launchedUri;
      LaunchMode? usedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentViewerPage(
            content: helpContent,
            launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
              launchedUri = url;
              usedMode = mode;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final privacyLink = find.text('Kebijakan Privasi');
      await tester.scrollUntilVisible(privacyLink, 100);
      await tester.tap(privacyLink);
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri.toString(), 'https://loddy04.github.io/rakoon-frontend/privacy.html');
      expect(usedMode, LaunchMode.externalApplication);

      final termsLink = find.text('Syarat & Ketentuan');
      await tester.scrollUntilVisible(termsLink, 100);
      await tester.tap(termsLink);
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri.toString(), 'https://loddy04.github.io/rakoon-frontend/terms.html');
      expect(usedMode, LaunchMode.externalApplication);
    });

    testWidgets('shows friendly SnackBar when link launch fails in Bantuan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentViewerPage(
            content: helpContent,
            launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final privacyLink = find.text('Kebijakan Privasi');
      await tester.scrollUntilVisible(privacyLink, 100);
      await tester.tap(privacyLink);
      await tester.pumpAndSettle();

      expect(find.text('Tidak dapat membuka halaman. Periksa koneksi internet.'), findsOneWidget);
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

    testWidgets('document link rows have touch target >= 48dp', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DocumentViewerPage(content: helpContent),
        ),
      );
      await tester.pumpAndSettle();

      final privacyTile = find.byKey(const Key('document_link_kebijakan_privasi'));
      await tester.scrollUntilVisible(privacyTile, 100);
      expect(privacyTile, findsOneWidget);
      final size = tester.getSize(privacyTile);
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
            home: DocumentViewerPage(content: helpContent),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
