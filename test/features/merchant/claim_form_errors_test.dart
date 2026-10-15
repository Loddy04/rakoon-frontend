import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:rakoon_frontend/features/merchant/presentation/widgets/claim_store_form.dart';

PickedFileData _file(String name) => PickedFileData(name: name, sizeInBytes: 1024, bytes: Uint8List(1024));

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Future<String> Function(PickedFileData)? uploadDocument,
    Future<String> Function(PickedFileData)? uploadPhoto,
    Future<void> Function(ClaimFormValues)? onSubmit,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ClaimStoreForm(
            storeName: 'Toko Berkah',
            pickDocument: () async => _file('nib.pdf'),
            pickPhoto: () async => _file('depan.png'),
            uploadDocument: uploadDocument ?? (_) async => 'documents/d.pdf',
            uploadPhoto: uploadPhoto ?? (_) async => 'photos/p.png',
            onSubmit: onSubmit ?? (_) async {},
          ),
        ),
      ),
    ));
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  void expectNoTechnicalText() {
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining('secret.host'), findsNothing);
    expect(find.text('Terjadi kesalahan, coba lagi'), findsOneWidget);
  }

  testWidgets('document upload failure shows the generic message, not the exception', (tester) async {
    await pump(tester, uploadDocument: (_) async => throw const SocketException('Failed host lookup: secret.host'));
    await tapKey(tester, 'claim_form_pick_document');
    expectNoTechnicalText();
  });

  testWidgets('photo upload failure shows the generic message, not the exception', (tester) async {
    await pump(tester, uploadPhoto: (_) async => throw const SocketException('Failed host lookup: secret.host'));
    await tapKey(tester, 'claim_form_pick_photo');
    expectNoTechnicalText();
  });

  testWidgets('submit failure shows the generic message, not the exception', (tester) async {
    await pump(tester, onSubmit: (_) async => throw const SocketException('Failed host lookup: secret.host'));
    await tester.enterText(find.byKey(const Key('claim_form_name')), 'Ahmad Sutanto');
    await tester.enterText(find.byKey(const Key('claim_form_phone')), '081233445566');
    await tapKey(tester, 'claim_form_pick_document');
    await tapKey(tester, 'claim_form_pick_photo');
    await tapKey(tester, 'claim_form_submit');
    expectNoTechnicalText();
  });

  testWidgets('a readable friendly exception message is kept', (tester) async {
    await pump(tester, uploadDocument: (_) async => throw Exception('Ukuran berkas terlalu besar (maksimum 5 MB).'));
    await tapKey(tester, 'claim_form_pick_document');
    expect(find.text('Ukuran berkas terlalu besar (maksimum 5 MB).'), findsOneWidget);
  });
}
