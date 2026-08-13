import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_shopping_screen.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/product_history_list_page.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/features/nearby/price_comparison_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  // TODO: [Temporary] baseUrl is loaded from development dashboard parameters.
  // Replace with dynamic configuration / client settings container during Production migration (Task A6).
  final String? baseUrl;

  const HomeScreen({super.key, this.baseUrl});

  String _getBaseUrl() {
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      return baseUrl!;
    }
    return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  }

  void _showProductSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      backgroundColor: AppColors.paper,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ProductSelectorBottomSheet(
            baseUrl: _getBaseUrl(),
            onProductSelected: (prod) {
              Navigator.pop(context); // Close bottom sheet
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PriceComparisonScreen(
                    productId: prod.id,
                    productName: prod.nama,
                    baseUrl: _getBaseUrl(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.l,
              ),
              child: Row(
                children: [
                  Text('Rakoon', style: AppTextStyles.titleLarge),
                  const SizedBox(width: AppSpacing.m),
                  // Location Pill — fills remaining width, clips text on narrow screens
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.s,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.accent,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Indomaret · Jl. Sudirman',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  // Compact logout — avoids 48dp IconButton minimum
                  GestureDetector(
                    key: const Key('logout_button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () async => AuthService.signOut(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.logout, color: AppColors.muted, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.s),

                    // 1. Scan Hero Card
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ScanCameraScreen(baseUrl: _getBaseUrl()),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.line),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Icon Box
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.ink,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xl,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.l),

                            // Info Text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scan Rak Produk',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Arahkan kamera ke rak untuk membandingkan harga',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),

                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),

                    // 2. Feature Actions Sub-Grid
                    Row(
                      children: [
                        // Left Card: Riwayat Harga
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductHistoryListPage(
                                    baseUrl: _getBaseUrl(),
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.l),
                              decoration: BoxDecoration(
                                color: AppColors.paper,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xl,
                                ),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.l,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.history,
                                      color: AppColors.ink,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.m),
                                  Text(
                                    'Riwayat Harga',
                                    style: AppTextStyles.bodyLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pantau tren harga ritel',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),

                        // Right Card: Toko Terdekat
                        Expanded(
                          child: Semantics(
                            label: 'Toko Terdekat, cari toko di sekitar kamu',
                            button: true,
                            container: true,
                            excludeSemantics: true,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NearbyStoresScreen(
                                      baseUrl: _getBaseUrl(),
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.l),
                                decoration: BoxDecoration(
                                  color: AppColors.paper,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xl,
                                  ),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.l,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.storefront_outlined,
                                        color: AppColors.ink,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.m),
                                    Text(
                                      'Toko Terdekat',
                                      style: AppTextStyles.bodyLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cari toko di sekitar kamu',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),

                    Row(
                      children: [
                        // Left Card: Bandingkan Harga
                        Expanded(
                          child: Semantics(
                            label: 'Bandingkan Harga, cari dan bandingkan harga produk',
                            button: true,
                            container: true,
                            excludeSemantics: true,
                            child: InkWell(
                              onTap: () => _showProductSelector(context),
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.l),
                                decoration: BoxDecoration(
                                  color: AppColors.paper,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xl,
                                  ),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.l,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.compare_arrows,
                                        color: AppColors.ink,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.m),
                                    Text(
                                      'Bandingkan Harga',
                                      style: AppTextStyles.bodyLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Temukan harga terbaik di toko sekitar',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),

                        // Right Card: Smart Budget Shopping
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BudgetShoppingScreen(baseUrl: _getBaseUrl()),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.l),
                              decoration: BoxDecoration(
                                color: AppColors.paper,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xl,
                                ),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.l,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: AppColors.ink,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.m),
                                  Text(
                                    'Smart Budget',
                                    style: AppTextStyles.bodyLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Alokasi budget belanja',
                                    style: AppTextStyles.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // 3. Scan Terakhir Feed
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Scan Terakhir',
                            style: AppTextStyles.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductHistoryListPage(
                                  baseUrl: _getBaseUrl(),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            child: Text(
                              'Lihat semua',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),

                    // List of recent items
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _mockScans.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: AppColors.line, height: 1),
                        itemBuilder: (context, index) {
                          final item = _mockScans[index];
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.l,
                                ),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.muted,
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${item.store} · ${item.volume}',
                              style: AppTextStyles.bodySmall,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.price,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: AppColors.ink,
                                  ),
                                ),
                                if (item.isBestValue) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.s,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentSoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.full,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          color: AppColors.accent,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Best Value',
                                          style: AppTextStyles.labelSmall
                                              .copyWith(fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 4),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.muted,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MockProduct {
  final String name;
  final String price;
  final String store;
  final String volume;
  final bool isBestValue;

  const MockProduct({
    required this.name,
    required this.price,
    required this.store,
    required this.volume,
    required this.isBestValue,
  });
}

const List<MockProduct> _mockScans = [
  MockProduct(
    name: 'Minyak Goreng Filma 2L',
    price: 'Rp 34.500',
    store: 'Indomaret',
    volume: '2 Liter',
    isBestValue: true,
  ),
  MockProduct(
    name: 'Susu UHT Ultra Milk 1L',
    price: 'Rp 17.200',
    store: 'Alfamart',
    volume: '1 Liter',
    isBestValue: false,
  ),
  MockProduct(
    name: 'Indomie Goreng Spesial',
    price: 'Rp 3.100',
    store: 'Superindo',
    volume: '85 gram',
    isBestValue: true,
  ),
  MockProduct(
    name: 'Kecap Manis Bango',
    price: 'Rp 21.500',
    store: 'Indomaret',
    volume: '550 mL',
    isBestValue: false,
  ),
];
