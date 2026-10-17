import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/price_check/data/datasources/price_check_service.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
    );
  });

  tearDown(() {
    AppConfig.overrideApiBaseUrl = null;
    AuthService.mockSession = null;
  });

  group('Backend URL Guard & Single Accessor Tests', () {
    test('no hardcoded backend URLs or scattered fromEnvironment(API_BASE_URL) in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final violations = <String>[];
      final excludedFiles = <String>[
        'lib/core/config/app_config.dart',
        'lib/features/debug/integration_dashboard_page.dart',
      ];

      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        if (excludedFiles.any((excluded) => normalizedPath.endsWith(excluded))) {
          continue;
        }

        final lines = file.readAsLinesSync();
        bool inBlockComment = false;

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();

          if (inBlockComment) {
            if (trimmed.contains('*/')) {
              inBlockComment = false;
            }
            continue;
          }

          if (trimmed.startsWith('/*')) {
            if (!trimmed.contains('*/')) {
              inBlockComment = true;
            }
            continue;
          }

          if (trimmed.startsWith('//')) {
            continue;
          }

          // Strip single-line comments if any (not preceded by :)
          String codePart = trimmed;
          final commentIndex = codePart.indexOf('//');
          if (commentIndex != -1 && (commentIndex == 0 || codePart[commentIndex - 1] != ':')) {
            codePart = codePart.substring(0, commentIndex).trim();
          }

          final hasLocalhost = codePart.contains('localhost');
          final has127 = codePart.contains('127.0.0.1');
          final has10 = codePart.contains('10.0.2.2');
          final hasEnvBaseUrl = codePart.contains("String.fromEnvironment('API_BASE_URL'") ||
              codePart.contains('String.fromEnvironment("API_BASE_URL"') ||
              (codePart.contains('String.fromEnvironment') &&
                  i + 1 < lines.length &&
                  lines[i + 1].contains('API_BASE_URL'));

          if (hasLocalhost || has127 || has10 || hasEnvBaseUrl) {
            violations.add('$normalizedPath:${i + 1}: $trimmed');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Violations found (hardcoded localhost/10.0.2.2/127.0.0.1 or scattered API_BASE_URL):\n'
            '${violations.join('\n')}',
      );
    });

    test('ScanService without explicit baseUrl uses AppConfig.backendBaseUrl', () async {
      AppConfig.overrideApiBaseUrl = 'https://example.test';
      AuthService.mockSession = Session(
        accessToken: 'test-token',
        tokenType: 'bearer',
        user: User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      Uri? recordedScanUri;
      final scanClient = MockClient((request) async {
        recordedScanUri = request.url;
        return http.Response(jsonEncode({'detected': []}), 200);
      });

      final tempDir = Directory.systemTemp.createTempSync('guard_test');
      final tempFile = File('${tempDir.path}/test.jpg')..writeAsBytesSync([1, 2, 3]);

      try {
        await ScanService.scanPhoto(tempFile, client: scanClient);
        expect(recordedScanUri?.origin, 'https://example.test');
      } finally {
        tempDir.deleteSync(recursive: true);
      }

      Uri? recordedConfirmUri;
      final confirmClient = MockClient((request) async {
        recordedConfirmUri = request.url;
        return http.Response(jsonEncode({'success': true, 'session_id': 's1'}), 201);
      });

      await ScanService.confirmScan(
        storeId: 'store-1',
        userId: 'user-1',
        items: [
          ScanResultItem(namaProduk: 'Item', harga: 1000, confidence: 'tinggi', needsVerification: false),
        ],
        client: confirmClient,
      );
      expect(recordedConfirmUri?.origin, 'https://example.test');
    });

    test('PriceCheckService and RecommendationService use AppConfig.backendBaseUrl by default', () async {
      AppConfig.overrideApiBaseUrl = 'https://example.test';

      Uri? recordedCatalogUri;
      final catalogClient = MockClient((request) async {
        recordedCatalogUri = request.url;
        return http.Response(jsonEncode([]), 200);
      });

      await PriceCheckService.getCatalogProducts(client: catalogClient);
      expect(recordedCatalogUri?.origin, 'https://example.test');

      Uri? recordedRecUri;
      final recClient = MockClient((request) async {
        recordedRecUri = request.url;
        return http.Response(
          jsonEncode({
            'session_id': 's1',
            'recommendation_mode': 'single_store',
            'recommended_store': {
              'store_id': 'st1',
              'store_name': 'Toko 1',
              'total_price': 10000,
              'missing_items_count': 0,
              'items': [],
            },
            'alternative_stores': [],
          }),
          200,
        );
      });

      await RecommendationService.evaluateRecommendation(
        candidates: [],
        client: recClient,
      );
      expect(recordedRecUri?.origin, 'https://example.test');
    });

    testWidgets('AppShell without explicit baseUrl passes AppConfig.backendBaseUrl to ScanCameraScreen', (tester) async {
      AppConfig.overrideApiBaseUrl = 'https://example.test';

      await tester.pumpWidget(const MaterialApp(
        home: AppShell(),
      ));
      await tester.pumpAndSettle();

      final scanCameraFinder = find.byType(ScanCameraScreen, skipOffstage: false);
      expect(scanCameraFinder, findsOneWidget);

      final scanCamera = tester.widget<ScanCameraScreen>(scanCameraFinder);
      expect(scanCamera.baseUrl, 'https://example.test');
    });
  });
}
