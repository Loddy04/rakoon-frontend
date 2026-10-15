import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/recommendation/recommendation_screen.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

void main() {
  group('RecommendationScreen UI and Best Value Calculation Tests', () {
    testWidgets('Renders clean AppBar, winner card, real unit size, and zero overflow at 320dp', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/recommendation/evaluate')) {
          return http.Response(
            jsonEncode({
              'categories': [
                {
                  'kategori': 'Makanan Pokok',
                  'dimension_groups': [
                    {
                      'dimension': 'volume',
                      'dimension_label': 'volume (ml)',
                      'is_comparable': true,
                      'best_value': {
                        'product_id': 'item-1',
                        'nama_produk': 'Minyak Filma 2L',
                        'harga': 36000.0,
                        'ukuran_original': 2.0,
                        'satuan_original': 'L',
                        'normalized_ukuran': 2000.0,
                        'base_unit': 'ml',
                        'harga_per_unit': 18.0,
                        'unit_price_label': 'Rp 18/ml',
                        'rank': 1,
                        'is_best_value': true,
                        'badge': 'BEST VALUE',
                        'explanation': 'Pilihan Paling Hemat! Memiliki harga per ml terendah (Rp 18/ml), lebih hemat 10.0% dibanding Minyak Filma 1L.',
                      },
                      'ranked_items': [
                        {
                          'product_id': 'item-1',
                          'nama_produk': 'Minyak Filma 2L',
                          'harga': 36000.0,
                          'ukuran_original': 2.0,
                          'satuan_original': 'L',
                          'normalized_ukuran': 2000.0,
                          'base_unit': 'ml',
                          'harga_per_unit': 18.0,
                          'unit_price_label': 'Rp 18/ml',
                          'rank': 1,
                          'is_best_value': true,
                          'badge': 'BEST VALUE',
                          'explanation': '',
                        },
                        {
                          'product_id': 'item-2',
                          'nama_produk': 'Minyak Filma 1L',
                          'harga': 20000.0,
                          'ukuran_original': 1.0,
                          'satuan_original': 'L',
                          'normalized_ukuran': 1000.0,
                          'base_unit': 'ml',
                          'harga_per_unit': 20.0,
                          'unit_price_label': 'Rp 20/ml',
                          'rank': 2,
                          'is_best_value': false,
                          'badge': null,
                          'explanation': '',
                        },
                      ],
                    },
                  ],
                },
              ],
              'excluded_items': [],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RecommendationScreen(
            baseUrl: 'http://localhost:8000',
            initialCandidates: [
              RecommendationCandidate(
                productId: 'item-1',
                namaProduk: 'Minyak Filma 2L',
                harga: 36000.0,
                ukuran: 2.0,
                satuan: 'L',
                kategori: 'Makanan Pokok',
              ),
              RecommendationCandidate(
                productId: 'item-2',
                namaProduk: 'Minyak Filma 1L',
                harga: 20000.0,
                ukuran: 1.0,
                satuan: 'L',
                kategori: 'Makanan Pokok',
              ),
            ],
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Clean AppBar
      expect(find.text('Analisis Best Value'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);

      // 2. No dummy bottom bar or dummy card
      expect(find.text('Gunakan Pilihan Ini'), findsNothing);
      expect(find.text('Hitung untuk Produk Lain'), findsNothing);

      // 3. No shopping bag thumbnail
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);

      // 4. Real size pill
      expect(find.text('2 L'), findsOneWidget); // winner card pill
      expect(find.text('1 L'), findsOneWidget); // other ranked items pill
      expect(find.text('VOLUME (ML)'), findsNothing);

      // 5. Does not duplicate #1 product card in the list below
      expect(find.text('Perbandingan Pilihan Lainnya'), findsOneWidget);
      // Minyak Filma 2L appears only once (in the winner card)
      expect(find.text('Minyak Filma 2L'), findsOneWidget);
      expect(find.text('Minyak Filma 1L'), findsOneWidget);

      // 6. Real percentage difference (+11.1%)
      expect(find.text('+11.1%'), findsOneWidget);
      expect(find.text('+18%'), findsNothing);

      // 7. Dynamic savings text
      expect(find.textContaining('Lebih hemat 11.1% dibanding pilihan peringkat #2 (Minyak Filma 1L)'), findsOneWidget);

      // 8. Zero overflow on 320dp screen!
      final err = tester.takeException();
      expect(err, isNull);
    });

    testWidgets('Displays "Harga Setara" badge when products have identical unit price', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/recommendation/evaluate')) {
          return http.Response(
            jsonEncode({
              'categories': [
                {
                  'kategori': 'Susu & Olahan',
                  'dimension_groups': [
                    {
                      'dimension': 'volume',
                      'dimension_label': 'volume (ml)',
                      'is_comparable': true,
                      'best_value': {
                        'product_id': 'item-1',
                        'nama_produk': 'Susu Segar A 1L',
                        'harga': 20000.0,
                        'ukuran_original': 1.0,
                        'satuan_original': 'L',
                        'normalized_ukuran': 1000.0,
                        'base_unit': 'ml',
                        'harga_per_unit': 20.0,
                        'unit_price_label': 'Rp 20/ml',
                        'rank': 1,
                        'is_best_value': true,
                        'badge': 'BEST VALUE',
                        'explanation': 'lebih hemat 0.0% dibanding pilihan peringkat #2',
                      },
                      'ranked_items': [
                        {
                          'product_id': 'item-1',
                          'nama_produk': 'Susu Segar A 1L',
                          'harga': 20000.0,
                          'ukuran_original': 1.0,
                          'satuan_original': 'L',
                          'normalized_ukuran': 1000.0,
                          'base_unit': 'ml',
                          'harga_per_unit': 20.0,
                          'unit_price_label': 'Rp 20/ml',
                          'rank': 1,
                          'is_best_value': true,
                          'badge': 'BEST VALUE',
                          'explanation': '',
                        },
                        {
                          'product_id': 'item-2',
                          'nama_produk': 'Susu Segar B 500ml',
                          'harga': 10000.0,
                          'ukuran_original': 500.0,
                          'satuan_original': 'ml',
                          'normalized_ukuran': 500.0,
                          'base_unit': 'ml',
                          'harga_per_unit': 20.0,
                          'unit_price_label': 'Rp 20/ml',
                          'rank': 2,
                          'is_best_value': false,
                          'badge': null,
                          'explanation': '',
                        },
                      ],
                    },
                  ],
                },
              ],
              'excluded_items': [],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RecommendationScreen(
            baseUrl: 'http://localhost:8000',
            initialCandidates: [
              RecommendationCandidate(
                productId: 'item-1',
                namaProduk: 'Susu Segar A 1L',
                harga: 20000.0,
                ukuran: 1.0,
                satuan: 'L',
                kategori: 'Susu & Olahan',
              ),
            ],
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays "Harga Setara" badge
      expect(find.text('Harga Setara'), findsOneWidget);
      expect(find.text('+0%'), findsNothing);
      expect(find.text('+0.0%'), findsNothing);

      // Dynamic savings text indicates equal value
      expect(find.text('Nilai ekonomi setara dengan pilihan lain dalam kelompok ini.'), findsOneWidget);

      // Insight text adapts dynamically and removes "lebih hemat 0.0%"
      expect(find.textContaining('lebih hemat 0.0%'), findsNothing);
      expect(find.textContaining('memiliki harga per ml terendah yang setara'), findsOneWidget);
    });
  });
}
