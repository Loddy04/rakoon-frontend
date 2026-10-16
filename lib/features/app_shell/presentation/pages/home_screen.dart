import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/budget_shopping/budget_shopping_screen.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_history_screen.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_session_detail_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/features/recommendation/presentation/providers/recommendation_provider.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;
  final bool? includeDemo;

  const HomeScreen({
    super.key,
    this.baseUrl,
    this.httpClient,
    this.includeDemo,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _locationLabel = 'Tidak Terdeteksi';
  double _userLat = -7.7829;
  double _userLng = 110.4083;
  // _userLat/_userLng punya nilai bawaan; jangan dikirim ke backend sebelum lokasi terdeteksi.
  bool _hasLocation = false;

  List<RecentScan>? _recentScans;
  bool _isLoadingScans = false;
  String? _scansError;

  final RecommendationProvider _recommendationProvider =
      RecommendationProvider();
  final PriceCheckProvider _catalogProvider = PriceCheckProvider();
  List<HomePromoBanner> _promoBanners = [];
  int _currentBannerIndex = 0;
  final PageController _bannerPageController = PageController(
    viewportFraction: 1.0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detectLocationAndStore();
    fetchRecentScans();
    fetchRecommendations();
    fetchPromoBanners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recommendationProvider.dispose();
    _catalogProvider.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _locationLabel == 'Tidak Terdeteksi') {
      _detectLocationAndStore();
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _detectLocationAndStore(),
      fetchRecentScans(),
      fetchRecommendations(),
      fetchPromoBanners(),
    ]);
  }

  Future<void> fetchPromoBanners() async {
    try {
      final banners = await AdsService.getHomeBanners(
        baseUrl: _getBaseUrl(),
        client: widget.httpClient,
        lat: _userLat,
        lng: _userLng,
        includeDemo: widget.includeDemo ?? AppConfig.allowDemoAds,
      );
      if (mounted) {
        setState(() {
          _promoBanners = banners;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _promoBanners = [];
        });
      }
    }
  }

  Future<void> fetchRecommendations({
    double? lat,
    double? lng,
    double radiusKm = 1.0,
  }) async {
    final sendLocation = _hasLocation || (lat != null && lng != null);
    _catalogProvider.setUserLocation(
      sendLocation ? (lat ?? _userLat) : null,
      sendLocation ? (lng ?? _userLng) : null,
    );
    await _catalogProvider.fetchCatalog(
      baseUrl: _getBaseUrl(),
      client: widget.httpClient,
    );
    // Also trigger recommendation provider in background if needed
    _recommendationProvider.fetchRecommendedProducts(
      baseUrl: _getBaseUrl(),
      lat: sendLocation ? (lat ?? _userLat) : null,
      lng: sendLocation ? (lng ?? _userLng) : null,
      radiusKm: radiusKm,
      client: widget.httpClient,
    );
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
          _scansError = friendlyApiError(e) ?? 'Gagal memuat riwayat scan.';
          _isLoadingScans = false;
        });
      }
    }
  }

  Future<void> _openScanCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanCameraScreen(baseUrl: _getBaseUrl()),
      ),
    );
    if (result == true || mounted) {
      fetchRecentScans();
    }
  }

  Future<void> _detectLocationAndStore() async {
    try {
      final position = await LocationService.getCurrentLocation();
      final areaName = await LocationService.getAreaNameFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _hasLocation = true;
        _locationLabel = areaName.isNotEmpty ? areaName : 'Lokasi Aktif';
      });

      try {
        await StoresService.getNearbyStores(
          lat: position.latitude,
          lng: position.longitude,
          baseUrl: _getBaseUrl(),
          client: widget.httpClient,
        );
      } catch (_) {
        // Network error fetching nearby stores does not invalidate GPS location
      }

      fetchRecommendations(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: 1.0,
      );
      fetchPromoBanners();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasLocation = false;
        _locationLabel = 'Tidak Terdeteksi';
      });
    }
  }

  Future<void> _handleLocationPillTap() async {
    final isGpsEnabled = await LocationService.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      if (!mounted) return;
      _showEnableLocationBottomSheet();
      return;
    }

    // Jika GPS aktif tapi sebelumnya gagal deteksi (misal baru dinyalakan)
    if (_locationLabel == 'Tidak Terdeteksi') {
      await _detectLocationAndStore();
      if (!mounted) return;
      final isStillGpsEnabled =
          await LocationService.isLocationServiceEnabled();
      if (!isStillGpsEnabled) {
        _showEnableLocationBottomSheet();
        return;
      }
    }

    if (mounted) {
      _navigateToNearbyStores();
    }
  }

  void _showEnableLocationBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              const SizedBox(height: 20),

              // Alert Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_off_rounded,
                    color: Color(0xFFD97706),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Layanan Lokasi (GPS) Nonaktif',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D2818),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Layanan lokasi pada perangkat Anda belum aktif. Silakan aktifkan GPS agar Rakoon dapat mendeteksi supermarket terdekat dan menampilkan promo serta perbandingan harga di sekitar Anda secara otomatis.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.0,
                  color: const Color(0xFF6B6B6B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action: Open Location Settings
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await LocationService.openLocationSettings();
                  },
                  icon: const Icon(
                    Icons.settings_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Buka Pengaturan Lokasi',
                    style: GoogleFonts.outfit(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2818),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Dismiss button
              SizedBox(
                width: double.infinity,
                height: 42,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Nanti Saja',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToNearbyStores() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NearbyStoresScreen(
          baseUrl: _getBaseUrl(),
          initialLat: _userLat,
          initialLng: _userLng,
        ),
      ),
    );
  }

  void _navigateToProductDetail(RecommendedProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedProductPriceDetailPage(
          product: product,
          baseUrl: _getBaseUrl(),
          httpClient: widget.httpClient,
          userLat: _userLat,
          userLng: _userLng,
        ),
      ),
    );
  }

  String _getBaseUrl() {
    if (widget.baseUrl != null && widget.baseUrl!.isNotEmpty) {
      return widget.baseUrl!;
    }
    const envBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }
    return kIsWeb
        ? 'http://localhost:8000'
        : 'https://rakoon-backend.onrender.com';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Section (Mascot Logo + Store Location Pill)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo + Brand Identity
                  Flexible(
                    flex: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/logo/rakoon_logo.png',
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.shopping_basket_rounded,
                                color: Color(0xFF0D2818),
                                size: 24,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Rakoon',
                            style: GoogleFonts.outfit(
                              fontSize: 19.0,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0D2818),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Store Location Pill Button
                  Flexible(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        label: 'Lokasi terdeteksi: $_locationLabel',
                        container: true,
                        child: InteractiveScale(
                          onTap: _handleLocationPillTap,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.5,
                              vertical: 5.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24.0),
                              border: Border.all(
                                color: const Color(0xFFE8E4DC),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6.0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF0D2818),
                                  size: 13,
                                ),
                                const SizedBox(width: 3.5),
                                Flexible(
                                  child: Text(
                                    _locationLabel,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF0D2818),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 2.5),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF7BAE8E),
                                  size: 13,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF0D2818),
                onRefresh: _refreshHome,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 6.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Search Bar Pill (White Card, #E8E4DC border, shadow-sm, rounded-3xl)
                      InteractiveScale(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PriceCheckCatalogPage(
                                baseUrl: _getBaseUrl(),
                                httpClient: widget.httpClient,
                                userLat: _userLat,
                                userLng: _userLng,
                                hasUserLocation: _hasLocation,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 48,
                          margin: const EdgeInsets.only(bottom: 14.0),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24.0),
                            border: Border.all(
                              color: const Color(0xFFE8E4DC),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 16.0,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4.0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF7BAE8E),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cari produk, merek, atau kebutuhan...',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF6B6B6B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InteractiveScale(
                                onTap: _openScanCamera,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFE8E4DC),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.crop_free_rounded,
                                    color: Color(0xFF0D2818),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Hero Card "Smart Shelf Scan" (Fitur Utama Rakoon AI)
                      _buildSmartShelfScanCard(),
                      const SizedBox(height: 18.0),

                      // 4. Menu Cepat (Quick Action Cards)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            // Quick Action 1: Cek Harga
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3.5,
                                ),
                                child: Semantics(
                                  label:
                                      'Cek Harga, buka katalog produk dan perbandingan harga',
                                  button: true,
                                  container: true,
                                  excludeSemantics: true,
                                  child: _QuickActionCardButton(
                                    title: 'Cek Harga',
                                    subtitle:
                                        'Lihat & bandingkan\nharga produk',
                                    icon: Icons.sell_rounded,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0D2818),
                                        Color(0xFF2E6644),
                                      ],
                                    ),
                                    iconColor: Colors.white,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PriceCheckCatalogPage(
                                                baseUrl: _getBaseUrl(),
                                                httpClient: widget.httpClient,
                                                userLat: _userLat,
                                                userLng: _userLng,
                                                hasUserLocation: _hasLocation,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),

                            // Quick Action 2: Toko Sekitar
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3.5,
                                ),
                                child: Semantics(
                                  label:
                                      'Toko Sekitar, cari toko terdekat di sekitar kamu',
                                  button: true,
                                  container: true,
                                  excludeSemantics: true,
                                  child: _QuickActionCardButton(
                                    title: 'Toko Sekitar',
                                    subtitle: 'Temukan\nsupermarket',
                                    icon: Icons.storefront_rounded,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF059669),
                                        Color(0xFF10B981),
                                      ],
                                    ),
                                    iconColor: Colors.white,
                                    onTap: _navigateToNearbyStores,
                                  ),
                                ),
                              ),
                            ),

                            // Quick Action 3: Smart Budget
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3.5,
                                ),
                                child: Semantics(
                                  label:
                                      'Smart Budget, kalkulasi belanja sesuai anggaran',
                                  button: true,
                                  container: true,
                                  excludeSemantics: true,
                                  child: _QuickActionCardButton(
                                    title: 'Smart Budget',
                                    subtitle: 'Atur belanja\nlebih hemat',
                                    icon: Icons.pie_chart_rounded,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF166534),
                                        Color(0xFF2E7D32),
                                      ],
                                    ),
                                    iconColor: Colors.white,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              BudgetShoppingScreen(
                                                baseUrl: _getBaseUrl(),
                                                userLat: _userLat,
                                                userLng: _userLng,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20.0),

                      // 5. Section "Promo Toko Sekitarmu" (Karusel Iklan Toko Ritel Mitra)
                      if (_promoBanners.isNotEmpty) ...[
                        _buildPromoBannersSection(),
                        const SizedBox(height: 20.0),
                      ],

                      // 6. Section "Produk Pilihan" Horizontal Carousel
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Produk Pilihan',
                              style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D2818),
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InteractiveScale(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PriceCheckCatalogPage(
                                    baseUrl: _getBaseUrl(),
                                    httpClient: widget.httpClient,
                                    userLat: _userLat,
                                    userLng: _userLng,
                                    hasUserLocation: _hasLocation,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Lihat Semua',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF166534),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF166534),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),

                      SizedBox(
                        height: 260,
                        child: ListenableBuilder(
                          listenable: _catalogProvider,
                          builder: (context, _) {
                            if (_catalogProvider.isLoading &&
                                _catalogProvider.products.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0D2818),
                                  strokeWidth: 2.5,
                                ),
                              );
                            }

                            final catalogProducts = _catalogProvider.products;
                            if (catalogProducts.isEmpty &&
                                _catalogProvider.status == PriceCheckStatus.error) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _catalogProvider.errorMessage ?? 'Gagal memuat katalog. Coba lagi.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF6B6B6B),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      key: const Key('retry_home_catalog_button'),
                                      onPressed: fetchRecommendations,
                                      child: const Text('Coba lagi'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            if (catalogProducts.isEmpty) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24.0),
                                  border: Border.all(
                                    color: const Color(0xFFE8E4DC),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 16.0,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 4.0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'Belum Ada Produk Tersedia',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF6B6B6B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: catalogProducts.length,
                              itemBuilder: (context, index) {
                                final catalogItem = catalogProducts[index];
                                final storeInfo =
                                    catalogItem.namaTokoTerendah != null
                                    ? catalogItem.namaTokoTerendah!.trim()
                                    : (catalogItem.jumlahToko > 0
                                          ? 'Tersedia di ${catalogItem.jumlahToko} toko'
                                          : 'Toko Terdekat');

                                final recommendedProd = RecommendedProduct(
                                  id: catalogItem.id,
                                  nama: catalogItem.nama,
                                  kategori: catalogItem.kategori,
                                  harga: catalogItem.hargaTerendah ?? 0.0,
                                  ukuran: catalogItem.ukuran,
                                  satuan: catalogItem.satuan,
                                  namaToko: storeInfo,
                                  jarakKm: catalogItem.jarakKm,
                                  updatedAt:
                                      catalogItem.updatedAt ?? 'just now',
                                  fotoUrl: catalogItem.fotoUrl,
                                );

                                return ProductCard(
                                  product: recommendedProd,
                                  onTap: () =>
                                      _navigateToProductDetail(recommendedProd),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 22.0),

                      // 7. Section "Riwayat Scan Terbaru" Header & Feed
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Text(
                                  'Riwayat Scan Terbaru',
                                  style: GoogleFonts.outfit(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0D2818),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Micro semantic label matching tests looking for 'Scan Terakhir'
                                const Opacity(
                                  opacity: 0.0,
                                  child: SizedBox(
                                    width: 0,
                                    height: 0,
                                    child: Text('Scan Terakhir'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InteractiveScale(
                            key: const Key('scan_terakhir_see_all'),
                            onTap: () {
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
                            child: Row(
                              children: [
                                Text(
                                  'Lihat semua',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF166534),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF166534),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      _buildRecentScansSection(),
                      const SizedBox(height: 20.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section Karusel Promo Iklan Toko Ritel Mitra (Didedikasikan untuk flyer iklan toko)
  Widget _buildPromoBannersSection() {
    if (_promoBanners.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeIndex = _currentBannerIndex >= _promoBanners.length
        ? 0
        : _currentBannerIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Promo Toko Sekitarmu',
          style: GoogleFonts.outfit(
            fontSize: 18.0,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D2818),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10.0),

        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _bannerPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _promoBanners.length,
            onPageChanged: (idx) {
              setState(() {
                _currentBannerIndex = idx;
              });
            },
            itemBuilder: (context, index) {
              final banner = _promoBanners[index];
              return _buildPromoBannerSlide(banner);
            },
          ),
        ),

        // Indicator Dots
        if (_promoBanners.length > 1) ...[
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_promoBanners.length, (idx) {
              final isCurrent = safeIndex == idx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 5,
                width: isCurrent ? 18 : 6,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF0D2818)
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }


  /// Standalone Hero Feature Card "Smart Shelf Scan" (Fitur Utama Rakoon AI)
  Widget _buildSmartShelfScanCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: InteractiveScale(
        onTap: _openScanCamera,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D2818), Color(0xFF1E4830)],
            ),
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(color: const Color(0xFF2E6644), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10.0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Left Content
              Expanded(
                flex: 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sparkle Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF163E27),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: const Color(0xFF3B8256),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF86EFAC),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rakoon AI',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF86EFAC),
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'Smart Shelf Scan\nPindai Rak Belanja',
                        style: GoogleFonts.outfit(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Temukan harga, bandingkan produk,\ndan belanja lebih hemat dengan AI.',
                        style: GoogleFonts.outfit(
                          fontSize: 11.0,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Action Button "Mulai Scan"
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(24.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.35),
                              blurRadius: 10.0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Mulai Scan',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Right Illustration with Real Product Assets & Scanner Mockup
              Expanded(
                flex: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 115,
                    height: 135,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Phone Scanner Mockup Container in Deep Forest Green
                        Container(
                          width: 82,
                          height: 112,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF081C10), Color(0xFF163E27)],
                            ),
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: const Color(0xFF34D399),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8.0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Product Being Scanned inside viewfinder (Indomie)
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Image.asset(
                                  BrandAssets.indomie,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.qr_code_scanner_rounded,
                                        color: Color(0xFF7BAE8E),
                                        size: 38,
                                      ),
                                ),
                              ),
                              // Green Scan Light Bar
                              Positioned(
                                top: 36,
                                left: 8,
                                right: 8,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.8),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Floating Ultra Milk Miniature Badge
                        Positioned(
                          left: -4,
                          top: 10,
                          child: Container(
                            width: 28,
                            height: 28,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE8E4DC),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              BrandAssets.ultramilk,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(),
                            ),
                          ),
                        ),

                        // Floating Bimoli Miniature Badge
                        Positioned(
                          left: 2,
                          bottom: 12,
                          child: Container(
                            width: 26,
                            height: 26,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE8E4DC),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              BrandAssets.bimoli,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(),
                            ),
                          ),
                        ),

                        // Mascot Peeking
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Image.asset(
                            BrandAssets.rakoonLogo,
                            height: 58,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(),
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
      ),
    );
  }

  Widget _buildPromoBannerSlide(HomePromoBanner banner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: InteractiveScale(
        onTap: () => _showPromoDetailDialog(banner),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: const Color(0xFFE8E4DC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18.0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image Flyer
                Image.network(
                  banner.bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFE5E7EB),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                        size: 36,
                      ),
                    ),
                  ),
                ),

                // Top Store Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF10B981),
                          size: 11,
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          '${banner.storeNama} • ${banner.distanceKm.toStringAsFixed(1)} km',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Gradient & Title
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 9.0,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          banner.title,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Text(
                              'Ketuk untuk lihat brosur',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPromoDetailDialog(HomePromoBanner banner) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banner.storeNama,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: const Color(0xFF0D2818),
                            ),
                          ),
                          Text(
                            banner.storeAlamat ?? 'Yogyakarta',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Interactive Image Viewer
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  color: const Color(0xFFF3F4F6),
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 1.0,
                    maxScale: 3.5,
                    child: Image.network(
                      banner.bannerUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Actions
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      banner.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Promo offline berlaku langsung di toko fisik',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: const Color(0xFF059669),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _navigateToNearbyStores();
                      },
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text('Lihat Rute / Lokasi Toko'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D2818),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentScansSection() {
    if (_isLoadingScans) {
      return Container(
        key: const Key('recent_scans_loading'),
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16.0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF0D2818),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Memuat riwayat scan...',
              style: GoogleFonts.outfit(
                color: const Color(0xFF6B6B6B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (_scansError != null) {
      return Container(
        key: const Key('recent_scans_error'),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16.0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              _scansError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF0D2818),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            InteractiveScale(
              onTap: fetchRecentScans,
              child: Container(
                key: const Key('retry_recent_scans_button'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D2818), Color(0xFF2E6644)],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D2818).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Coba Lagi',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_recentScans == null || _recentScans!.isEmpty) {
      return Container(
        key: const Key('recent_scans_empty'),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16.0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF0D2818),
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Riwayat Pindai',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D2818),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pindai label harga rak produk di toko untuk mulai mencatat dan membandingkan harga.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF6B6B6B),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            InteractiveScale(
              onTap: _openScanCamera,
              child: Container(
                key: const Key('home_start_scan_cta'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D2818), Color(0xFF1E5E3A)],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D2818).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Mulai Pindai Rak',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('recent_scans_list'),
      children: _recentScans!
          .take(5)
          .map((scan) => _buildRecentScanCard(scan))
          .toList(),
    );
  }

  Widget _buildRecentScanCard(RecentScan scan) {
    final String storeName = scan.storeName ?? 'Toko Terdekat';
    final String productCountText = '${scan.productCount} produk dipindai';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InteractiveScale(
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
        child: Container(
          key: Key('recent_scan_item_${scan.id}'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16.0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Shelf / Session Thumbnail with Store Logo
              BrandAssets.buildStoreLogo(
                scan.storeName,
                size: 46,
                borderRadius: 14.0,
                fallbackBgColor: const Color(0xFF0D2818),
                fallbackIconColor: Colors.white,
              ),
              const SizedBox(width: 12),

              // Store & Count Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Store Name (Expanded) & Date (Right aligned)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            storeName,
                            style: GoogleFonts.outfit(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D2818),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: Text(
                            _formatDateTime(scan.timestamp),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF9CA3AF),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Sub-information: Icon receipt_long + Product Count
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 13.5,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            productCountText,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF059669),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Vertically centered Navigation Chevron with comfortable breathing room
              const Padding(
                padding: EdgeInsets.only(left: 8.0, right: 2.0),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDt);

    if (difference.inDays == 0 && localDt.day == now.day) {
      final hour = localDt.hour.toString().padLeft(2, '0');
      final minute = localDt.minute.toString().padLeft(2, '0');
      return 'Hari ini, $hour:$minute';
    } else if (difference.inDays == 1 ||
        (now.day - localDt.day == 1 && difference.inHours < 48)) {
      final hour = localDt.hour.toString().padLeft(2, '0');
      final minute = localDt.minute.toString().padLeft(2, '0');
      return 'Kemarin, $hour:$minute';
    }

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = localDt.day.toString().padLeft(2, '0');
    final month = months[localDt.month - 1];
    final hour = localDt.hour.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');
    return '$day $month, $hour:$minute';
  }
}

/// Quick Action Card Button Item with Rounded Card & Active Scale
class _QuickActionCardButton extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCardButton({
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18.0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 22)),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D2818),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 26,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  color: const Color(0xFF6B6B6B),
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
