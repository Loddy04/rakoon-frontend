import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showNavigationPlaceholder(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.accent),
            const SizedBox(width: AppSpacing.s),
            Text('Info Navigasi', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Text(
          'Menu "$featureName" berhasil dibuat!\n\nSesuai instruksi, menu ini masih berupa pratinjau (placeholder) dan akan dihubungkan ke halaman fitur asli pada Task A4.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.ink),
            child: const Text('Tutup'),
          ),
        ],
      ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rakoon', style: AppTextStyles.titleLarge),

                  // Location Pill
                  Container(
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
                        Text(
                          'Indomaret · Jl. Sudirman',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                      onTap: () => _showNavigationPlaceholder(
                        context,
                        'Scan Rak Produk',
                      ),
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
                            onTap: () => _showNavigationPlaceholder(
                              context,
                              'Riwayat Harga',
                            ),
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
                          child: InkWell(
                            onTap: () => _showNavigationPlaceholder(
                              context,
                              'Toko Terdekat',
                            ),
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
                                    'Lihat detail outlet ritel',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Additional Row/Card: Budget Shopping
                    InkWell(
                      onTap: () => _showNavigationPlaceholder(
                        context,
                        'Smart Budget Shopping',
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
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
                            const SizedBox(width: AppSpacing.l),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Smart Budget Shopping',
                                    style: AppTextStyles.bodyLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Optimalkan belanja dengan alokasi budget cerdas',
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
                    const SizedBox(height: AppSpacing.xxl),

                    // 3. Scan Terakhir Feed
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Scan Terakhir', style: AppTextStyles.titleSmall),
                        TextButton(
                          onPressed: () => _showNavigationPlaceholder(
                            context,
                            'Lihat semua scan',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            'Lihat semua',
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 12,
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.price,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                if (item.isBestValue)
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
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.muted,
                                    size: 16,
                                  ),
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
