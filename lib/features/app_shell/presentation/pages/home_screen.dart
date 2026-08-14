import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_shopping_screen.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/product_history_list_page.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/features/nearby/price_comparison_screen.dart';
import 'package:rakoon_frontend/features/nearby/presentation/widgets/product_selector_bottom_sheet.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  // TODO: [Temporary] baseUrl is loaded from development dashboard parameters.
  // Replace with dynamic configuration / client settings container during Production migration (Task A6).
  final String? baseUrl;

  const HomeScreen({super.key, this.baseUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationLabel = 'Mencari lokasi...';

  @override
  void initState() {
    super.initState();
    _detectLocationAndStore();
  }

  Future<void> _detectLocationAndStore() async {
    try {
      final position = await LocationService.getCurrentLocation();
      final response = await StoresService.getNearbyStores(
        lat: position.latitude,
        lng: position.longitude,
        baseUrl: _getBaseUrl(),
      );

      if (!mounted) return;

      if (response.stores.isNotEmpty) {
        final nearest = response.stores.first;
        setState(() {
          _locationLabel = '${nearest.nama} · ${nearest.jarakKm.toStringAsFixed(1)} km';
        });
      } else {
        setState(() {
          _locationLabel = 'Lokasi Terdeteksi';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationLabel = 'Lokasi Belum Terdeteksi';
      });
    }
  }

  String _getBaseUrl() {
    if (widget.baseUrl != null && widget.baseUrl!.isNotEmpty) {
      return widget.baseUrl!;
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
            // Header Section with Brand and Location Pill
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.l,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rakoon', style: AppTextStyles.titleLarge),
                  const SizedBox(width: AppSpacing.s),
                  Flexible(
                    child: Semantics(
                      label: 'Lokasi terdeteksi: $_locationLabel',
                      container: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                          vertical: 6.0,
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
                                _locationLabel,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
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

                    // 2. Feature Actions Grid (fixed height & alignment)
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.m,
                      mainAxisSpacing: AppSpacing.m,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.83,
                      children: [
                        // Card 1: Riwayat Harga
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
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.l),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pantau tren harga ritel',
                                  style: AppTextStyles.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Card 2: Toko Terdekat
                        Semantics(
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cari toko di sekitar kamu',
                                    style: AppTextStyles.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Card 3: Bandingkan Harga
                        Semantics(
                          label:
                              'Bandingkan Harga, cari dan bandingkan harga produk',
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Temukan harga terbaik di toko sekitar',
                                    style: AppTextStyles.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Card 4: Smart Budget Shopping
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BudgetShoppingScreen(
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
                              borderRadius: BorderRadius.circular(AppRadius.xl),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),

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
                    // Empty state for recent scans
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.xxl,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.line),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            child: const Icon(
                              Icons.history_toggle_off_outlined,
                              color: AppColors.muted,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.m),
                          Text(
                            'Belum Ada Riwayat Pindai',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Pindai label harga rak produk di toko untuk mulai mencatat dan membandingkan harga.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.l),
                          OutlinedButton.icon(
                            key: const Key('home_start_scan_cta'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ScanCameraScreen(baseUrl: _getBaseUrl()),
                                ),
                              );
                            },
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Mulai Pindai Rak'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.accent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.l),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.l,
                                vertical: AppSpacing.s,
                              ),
                            ),
                          ),
                        ],
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
