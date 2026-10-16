import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_geolocator.dart';

void main() {
  late FakeGeolocator fake;
  late GeolocatorPlatform original;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = GeolocatorPlatform.instance;
    fake = FakeGeolocator();
    GeolocatorPlatform.instance = fake;
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
  });

  testWidgets('Location permission SocketException shows friendly message without technical details in SnackBar', (tester) async {
    fake.checkError = const SocketException('Failed host lookup: secret.host');

    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();

    expect(find.text('Izinkan'), findsOneWidget);
    await tester.tap(find.text('Izinkan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining('secret.host'), findsNothing);
    expect(find.text('Terjadi kesalahan, coba lagi'), findsOneWidget);
  });
}
