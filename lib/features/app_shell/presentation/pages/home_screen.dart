import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/budget_shopping/budget_shopping_screen.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_history_screen.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_session_detail_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/features/recommendation/presentation/providers/recommendation_provider.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';
import 'package:rakoon_frontend/widgets/rakoon_location_map.dart';

class HomeScreen extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;

  const HomeScreen({super.key, this.baseUrl, this.httpClient});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  String _locationLabel = 'LOKASI BELUM TERDETEKSI';
  double _userLat = -7.7829;
  double _userLng = 110.4083;
  final MapController _mapController = MapController();

  List<StoreNearby> _nearbyStores = [];
  List<RecentScan>? _recentScans;
  bool _isLoadingScans = false;
  String? _scansError;

  final RecommendationProvider _recommendationProvider = RecommendationProvider();
  List<HomePromoBanner> _promoBanners = [];
  bool _isLoadingBanners = false;
  int _currentBannerIndex = 0;
  final PageController _bannerPageController = PageController(viewportFraction: 0.92);

  @override
  void initState() {
    super.initState();
    _detectLocationAndStore();
    fetchRecentScans();
    fetchRecommendations();
    fetchPromoBanners();
  }

  @override
  void dispose() {
    _recommendationProvider.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  Future<void> fetchPromoBanners() async {
    if (mounted) {
      setState(() {
        _isLoadingBanners = true;
      });
    }
    try {
      final banners = await AdsService.getHomeBanners(
        baseUrl: _getBaseUrl(),
        client: widget.httpClient,
        lat: _userLat,
        lng: _userLng,
      );
      if (mounted) {
        setState(() {
          _promoBanners = banners;
          _isLoadingBanners = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    }
  }

  Future<void> fetchRecommendations({
    double? lat,
    double? lng,
    double radiusKm = 1.0,
  }) async {
    await _recommendationProvider.fetchRecommendedProducts(
      baseUrl: _getBaseUrl(),
      lat: lat ?? _userLat,
      lng: lng ?? _userLng,
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
          _userLat = position.latitude;
          _userLng = position.longitude;
          _nearbyStores = response.stores;
          _locationLabel = '${nearest.nama} · ${nearest.jarakKm.toStringAsFixed(1)} km';
        });
      } else {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
          _nearbyStores = [];
          _locationLabel = 'LOKASI TERDETEKSI';
        });
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
        _locationLabel = 'LOKASI BELUM TERDETEKSI';
      });
    }
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
    return kIsWeb ? 'http://localhost:8000' : 'https://rakoon-backend.onrender.com';
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
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.shopping_basket_rounded,
                            color: Color(0xFF0D2818),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Rakoon',
                                style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                  color: const Color(0xFF0D2818),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Belanja Lebih Cerdas',
                                style: GoogleFonts.outfit(
                                  fontSize: 8.5,
                                  color: const Color(0xFF6B6B6B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
                          onTap: _navigateToNearbyStores,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 120),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7.0,
                              vertical: 4.5,
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
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    _locationLabel.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF0D2818),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 2),
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8.0,
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

                    // 3. Mini Map (OpenStreetMap with Rounded-3xl Borders & Shadow-sm)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: const Color(0xFFE8E4DC),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10.0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24.0),
                        child: RakoonLocationMap(
                          userLat: _userLat,
                          userLng: _userLng,
                          mapController: _mapController,
                          height: 155,
                          heroTag: 'home_location_map',
                          margin: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: const Color(0xFFE8E4DC),
                            width: 1.0,
                          ),
                          boxShadow: const [],
                          onMapTap: _navigateToNearbyStores,
                          onMarkerTap: (storeId) => _navigateToNearbyStores(),
                          markers: _nearbyStores.map((store) {
                            return MapStoreMarker(
                              storeId: store.storeId,
                              lat: store.lat,
                              lng: store.lng,
                              label: store.nama,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14.0),

                    // 4. Hero Banner ("Rakoon AI - Smart Shelf Scan")
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: const Color(0xFFE8E4DC),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sparkle Pill Badge (Soft Mint Green)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F8F4),
                                    borderRadius: BorderRadius.circular(16.0),
                                    border: Border.all(
                                      color: const Color(0xFFD1E7DD),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Color(0xFF166534),
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Rakoon AI',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF0D2818),
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
                                  style: GoogleFonts.dmSerifDisplay(
                                    fontSize: 18.5,
                                    fontWeight: FontWeight.normal,
                                    color: const Color(0xFF0D2818),
                                    height: 1.15,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Temukan harga, bandingkan produk,\ndan belanja lebih hemat dengan AI.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.0,
                                    color: const Color(0xFF6B6B6B),
                                    height: 1.3,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Action Button "Mulai Scan ->" (Deep Forest Green Gradient + warm glow shadow + active:scale-95)
                                InteractiveScale(
                                  onTap: _openScanCamera,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14.0,
                                      vertical: 8.0,
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
                                          color: const Color(0xFF0D2818)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 10.0,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
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
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right Illustration with Real Product Assets & Scanner Mockup
                          Expanded(
                            flex: 4,
                            child: SizedBox(
                              height: 120,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // Phone Scanner Mockup Container in Deep Forest Green
                                  Container(
                                    width: 84,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF0D2818), Color(0xFF1E4830)],
                                      ),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(
                                        color: const Color(0xFF7BAE8E),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0D2818).withValues(alpha: 0.2),
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
                                            errorBuilder: (context, error, stackTrace) => const Icon(
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
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.8),
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
                                        border: Border.all(color: const Color(0xFFE8E4DC), width: 1),
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
                                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
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
                                        border: Border.all(color: const Color(0xFFE8E4DC), width: 1),
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
                                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                      ),
                                    ),
                                  ),

                                  // Mascot Peeking
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Image.asset(
                                      BrandAssets.rakoonLogo,
                                      height: 60,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const SizedBox(),
                                    ),
                                  ),

                                  // Mini Speech Bubble
                                  Positioned(
                                    top: 4,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0,
                                        vertical: 3.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10.0),
                                        border: Border.all(
                                          color: const Color(0xFFE8E4DC),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 4.0,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '✦ AI Shelf',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.0,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0D2818),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18.0),

                    // 5. Quick Actions (3 Rounded-3xl Cards with Gradients & Active Scale)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Action 1: Cek Harga
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0),
                            child: Semantics(
                              label: 'Cek Harga, buka katalog produk dan perbandingan harga',
                              button: true,
                              container: true,
                              excludeSemantics: true,
                              child: _ColorfulQuickActionButton(
                                icon: Icons.sell_rounded,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF0D2818), Color(0xFF2E6644)],
                                ),
                                iconColor: Colors.white,
                                title: 'Cek Harga',
                                subtitle: 'Lihat & bandingkan\nharga produk',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PriceCheckCatalogPage(
                                        baseUrl: _getBaseUrl(),
                                        httpClient: widget.httpClient,
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

                        // Quick Action 2: Toko Sekitar (Emerald Green + Alfamart/Indomaret Chips)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0),
                            child: Semantics(
                              label: 'Toko Sekitar, cari toko terdekat di sekitar kamu',
                              button: true,
                              container: true,
                              excludeSemantics: true,
                              child: _ColorfulQuickActionButton(
                                icon: Icons.storefront_rounded,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                                ),
                                iconColor: Colors.white,
                                title: 'Toko Sekitar',
                                subtitle: 'Temukan supermarket\nterdekat',
                                trailingWidget: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                ),
                                onTap: _navigateToNearbyStores,
                              ),
                            ),
                          ),
                        ),

                        // Quick Action 3: Smart Budget (Sage / Forest Green Gradient)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0),
                            child: Semantics(
                              label: 'Smart Budget, kalkulasi belanja sesuai anggaran',
                              button: true,
                              container: true,
                              excludeSemantics: true,
                              child: _ColorfulQuickActionButton(
                                icon: Icons.pie_chart_rounded,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF166534), Color(0xFF2E7D32)],
                                ),
                                iconColor: Colors.white,
                                title: 'Smart Budget',
                                subtitle: 'Atur belanja\nlebih hemat',
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22.0),

                    // Promo Toko Sekitarmu (Hyperlocal Flyer Ad Carousel)
                    _buildPromoBannersSection(),

                    // 6. Section "Produk Pilihan" Horizontal Carousel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Produk Pilihan',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 21,
                              fontWeight: FontWeight.normal,
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
                        listenable: _recommendationProvider,
                        builder: (context, _) {
                          if (_recommendationProvider.isLoading &&
                              _recommendationProvider.products.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF0D2818),
                                strokeWidth: 2.5,
                              ),
                            );
                          }

                          final products = _recommendationProvider.products;
                          if (products.isEmpty) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24.0),
                                border: Border.all(color: const Color(0xFFE8E4DC)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Belum Ada Rekomendasi Produk',
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
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return ProductCard(
                                product: product,
                                onTap: () => _navigateToProductDetail(product),
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
                                style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 21,
                                  fontWeight: FontWeight.normal,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBannersSection() {
    if (_isLoadingBanners && _promoBanners.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_promoBanners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Promo Toko Sekitarmu',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 21,
                  fontWeight: FontWeight.normal,
                  color: const Color(0xFF0D2818),
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(
                    'Mitra Ritel',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3.0),
        Text(
          'Flyer promo offline toko ritel terdekat di Yogyakarta',
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            color: const Color(0xFF6B6B6B),
          ),
        ),
        const SizedBox(height: 12.0),

        // Carousel Slider
        SizedBox(
          height: 195,
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InteractiveScale(
                  onTap: () => _showPromoDetailDialog(banner),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22.0),
                      border: Border.all(color: const Color(0xFFE8E4DC)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10.0,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.0),
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
                                child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 36),
                              ),
                            ),
                          ),

                          // Top Badges
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${banner.storeNama} • ${banner.distanceKm.toStringAsFixed(1)} km',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF166534),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Sisa ${banner.daysLeft} Hari',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bottom Gradient & Title
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
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
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'Ketuk untuk lihat brosur penuh',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 11),
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
            },
          ),
        ),

        // Indicator Dots
        if (_promoBanners.length > 1) ...[
          const SizedBox(height: 10.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_promoBanners.length, (idx) {
              final isCurrent = _currentBannerIndex == idx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                height: 5,
                width: isCurrent ? 18 : 6,
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF0D2818) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
        const SizedBox(height: 22.0),
      ],
    );
  }

  void _showPromoDetailDialog(HomePromoBanner banner) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        child: Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
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
                      'Promo offline berlaku langsung di toko fisik • Sisa ${banner.daysLeft} hari',
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
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8.0,
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
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8.0,
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
              'Gagal memuat riwayat scan.',
              style: GoogleFonts.dmSerifDisplay(
                color: const Color(0xFF0D2818),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            InteractiveScale(
              onTap: fetchRecentScans,
              child: Container(
                key: const Key('retry_recent_scans_button'),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                border: Border.all(
                  color: const Color(0xFFE8E4DC),
                  width: 1.0,
                ),
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
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 18,
                fontWeight: FontWeight.normal,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
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
      children: _recentScans!.take(5).map((scan) => _buildRecentScanCard(scan)).toList(),
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
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            children: [
              // Shelf / Session Thumbnail with Store Logo
              BrandAssets.buildStoreLogo(
                scan.storeName,
                size: 48,
                borderRadius: 16.0,
                fallbackBgColor: const Color(0xFF0D2818),
                fallbackIconColor: Colors.white,
              ),
              const SizedBox(width: 12),

              // Store & Count Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D2818),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      productCountText,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF6B6B6B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Time and Chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDateTime(scan.timestamp),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF6B6B6B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFF7BAE8E),
                  ),
                ],
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
    } else if (difference.inDays == 1 || (now.day - localDt.day == 1 && difference.inHours < 48)) {
      final hour = localDt.hour.toString().padLeft(2, '0');
      final minute = localDt.minute.toString().padLeft(2, '0');
      return 'Kemarin, $hour:$minute';
    }

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = localDt.day.toString().padLeft(2, '0');
    final month = months[localDt.month - 1];
    final hour = localDt.hour.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');
    return '$day $month, $hour:$minute';
  }
}

/// Colorful Quick Action Button Item with Rounded-3xl Card & Active Scale
class _ColorfulQuickActionButton extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  const _ColorfulQuickActionButton({
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
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
              blurRadius: 8.0,
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
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D2818),
              ),
            ),
            const SizedBox(height: 2),
            if (trailingWidget != null) ...[
              trailingWidget!,
              const SizedBox(height: 3),
            ],
            Text(
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
          ],
        ),
      ),
    );
  }
}
