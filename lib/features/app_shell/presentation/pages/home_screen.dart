import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/budget_shopping/budget_shopping_screen.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/product_history_list_page.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/features/nearby/price_comparison_screen.dart';
import 'package:rakoon_frontend/features/nearby/presentation/widgets/product_selector_bottom_sheet.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_history_screen.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_session_detail_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/bouncy_button.dart';
import 'package:rakoon_frontend/widgets/playful_card.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;

  const HomeScreen({super.key, this.baseUrl, this.httpClient});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  String _locationLabel = 'Mencari lokasi...';
  List<RecentScan>? _recentScans;
  bool _isLoadingScans = false;
  String? _scansError;

  @override
  void initState() {
    super.initState();
    _detectLocationAndStore();
    fetchRecentScans();
  }

  Future<void> fetchRecentScans() async {
    if (AuthService.currentSession == null) {
      if (mounted) {
        setState(() {
          _recentScans = [];
          _isLoadingScans = false;
          _scansError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingScans = true;
        _scansError = null;
      });
    }

    try {
      final scans = await ScanService.getRecentScans(
        baseUrl: _getBaseUrl(),
        client: widget.httpClient,
      );
      if (mounted) {
        setState(() {
          _recentScans = scans;
          _isLoadingScans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scansError = 'Gagal memuat riwayat scan.';
          _isLoadingScans = false;
        });
      }
    }
  }

  Future<void> _openScanCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanCameraScreen(
          baseUrl: _getBaseUrl(),
        ),
      ),
    );
    if (result == true || mounted) {
      fetchRecentScans();
    }
  }

  Future<void> _detectLocationAndStore() async {
    try {
      final position = await LocationService.getCurrentLocation();
      final response = await StoresService.getNearbyStores(
        lat: position.latitude,
        lng: position.longitude,
        baseUrl: _getBaseUrl(),
        client: widget.httpClient,
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
    const envBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }
    return kIsWeb ? 'http://localhost:8000' : 'https://rakoon-backend.onrender.com';
  }

  void _showProductSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.cards)),
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
              Navigator.pop(context);
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
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Shupatto Minimalist Header Section (Clean White Canvas)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RAKOON',
                    style: AppTextStyles.headingLg.copyWith(
                      fontSize: 20,
                      letterSpacing: 2.0,
                      color: AppColors.graphite,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Flexible(
                    child: Semantics(
                      label: 'Lokasi terdeteksi: $_locationLabel',
                      container: true,
                      child: StatusBadge(
                        status: _locationLabel,
                        icon: Icons.location_on_outlined,
                        customBackgroundColor: AppColors.paper,
                        customTextColor: AppColors.graphite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.graphite, height: 1.0, thickness: 1.0),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Ramping Compact Hero "Scan Rak Produk" Banner
                    PlayfulCard(
                      onTap: _openScanCamera,
                      backgroundColor: AppColors.paper,
                      border: Border.all(color: AppColors.graphite, width: 1.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: AppColors.graphite, width: 1.0),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: AppColors.graphite,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SCAN RAK PRODUK',
                                  style: AppTextStyles.subheading.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Arahkan kamera ke rak untuk bandingkan harga',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 11,
                                    color: AppColors.fog,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.graphite,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // 2. Ergonomic 1x4 Quick Action Menu Bar (Gojek Style)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Action 1: Riwayat Harga
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.show_chart_rounded,
                            label: 'Riwayat Harga',
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
                          ),
                        ),

                        // Quick Action 2: Toko Terdekat
                        Expanded(
                          child: Semantics(
                            label: 'Toko Terdekat, cari toko di sekitar kamu',
                            button: true,
                            container: true,
                            excludeSemantics: true,
                            child: _QuickActionButton(
                              icon: Icons.storefront_outlined,
                              label: 'Toko Terdekat',
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
                            ),
                          ),
                        ),

                        // Quick Action 3: Bandingkan Harga
                        Expanded(
                          child: Semantics(
                            label: 'Bandingkan Harga, cari dan bandingkan harga produk',
                            button: true,
                            container: true,
                            excludeSemantics: true,
                            child: _QuickActionButton(
                              icon: Icons.compare_arrows,
                              label: 'Bandingkan',
                              onTap: () => _showProductSelector(context),
                            ),
                          ),
                        ),

                        // Quick Action 4: Smart Budget
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Smart Budget',
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // Hairline Divider
                    const Divider(color: AppColors.graphite, height: 1.0, thickness: 1.0),
                    const SizedBox(height: AppSpacing.s16),

                    // 3. Exposed Section "Scan Terakhir" Feed Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'SCAN TERAKHIR',
                            style: AppTextStyles.subheading.copyWith(
                              fontSize: 13,
                              letterSpacing: 1.2,
                              color: AppColors.graphite,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        BouncyButton(
                          key: const Key('scan_terakhir_see_all'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScanHistoryScreen(
                                  baseUrl: _getBaseUrl(),
                                  httpClient: widget.httpClient,
                                ),
                              ),
                            );
                          },
                          variant: BouncyButtonVariant.outlined,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          text: 'Lihat Semua',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _buildRecentScansSection(),
                    const SizedBox(height: AppSpacing.s20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentScansSection() {
    if (_isLoadingScans) {
      return PlayfulCard(
        key: const Key('recent_scans_loading'),
        backgroundColor: AppColors.paper,
        border: Border.all(color: AppColors.graphite, width: 1.0),
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: AppColors.graphite,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'MEMUAT RIWAYAT SCAN...',
              style: AppTextStyles.monoTag.copyWith(color: AppColors.fog, fontSize: 10),
            ),
          ],
        ),
      );
    }

    if (_scansError != null) {
      return PlayfulCard(
        key: const Key('recent_scans_error'),
        backgroundColor: AppColors.paper,
        border: Border.all(color: AppColors.graphite, width: 1.0),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.graphite, size: 28),
            const SizedBox(height: AppSpacing.s),
            Text(
              'GAGAL MEMUAT RIWAYAT SCAN',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.graphite,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            BouncyButton(
              key: const Key('retry_recent_scans_button'),
              onPressed: fetchRecentScans,
              variant: BouncyButtonVariant.primaryPill,
              icon: Icons.refresh,
              text: 'Coba Lagi',
            ),
          ],
        ),
      );
    }

    if (_recentScans == null || _recentScans!.isEmpty) {
      return PlayfulCard(
        key: const Key('recent_scans_empty'),
        backgroundColor: AppColors.paper,
        border: Border.all(color: AppColors.graphite, width: 1.0),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: 28.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppColors.graphite, width: 1.0),
              ),
              child: const Icon(
                Icons.history_toggle_off_outlined,
                color: AppColors.graphite,
                size: 22,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'BELUM ADA RIWAYAT PINDAI',
              style: AppTextStyles.titleSmall.copyWith(
                fontSize: 13,
                letterSpacing: 1.0,
                color: AppColors.graphite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pindai label harga rak produk di toko untuk mulai mencatat dan membandingkan harga.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.fog,
                fontSize: 11,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            BouncyButton(
              key: const Key('home_start_scan_cta'),
              onPressed: _openScanCamera,
              variant: BouncyButtonVariant.accentAction,
              icon: Icons.camera_alt_outlined,
              text: 'Mulai Pindai Rak',
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('recent_scans_list'),
      children: _recentScans!.take(5).map((scan) => _buildRecentScanCard(scan)).toList(),
    );
  }

  Widget _buildRecentScanCard(RecentScan scan) {
    final String storeName = scan.storeName ?? 'Toko Terdekat';
    final String productCountText = '${scan.productCount} Produk';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: PlayfulCard(
        key: Key('recent_scan_item_${scan.id}'),
        backgroundColor: AppColors.paper,
        border: Border.all(color: AppColors.graphite, width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanSessionDetailScreen(
                scanSessionId: scan.id,
                baseUrl: _getBaseUrl(),
                httpClient: widget.httpClient,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    storeName,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 14,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                StatusBadge(
                  status: productCountText,
                  customBackgroundColor: AppColors.periwinkle,
                  customTextColor: AppColors.paper,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 12,
                  color: AppColors.fog,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(scan.timestamp),
                  style: AppTextStyles.monoTag.copyWith(
                    color: AppColors.fog,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final localDt = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = localDt.day.toString().padLeft(2, '0');
    final month = months[localDt.month - 1];
    final year = localDt.year;
    final hour = localDt.hour.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }
}

/// A compact, responsive quick-action button item (Gojek menu pattern) featuring bouncy scale press feedback.
class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppCurves.snappy,
        reverseCurve: AppCurves.bouncy,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: AppColors.graphite, width: 1.0),
              ),
              child: Icon(
                widget.icon,
                color: AppColors.graphite,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                letterSpacing: 0.5,
                color: AppColors.graphite,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
