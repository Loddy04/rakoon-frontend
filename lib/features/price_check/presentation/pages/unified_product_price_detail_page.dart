import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/features/history/data/models/price_history_item.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';
import 'package:rakoon_frontend/widgets/price_freshness_label.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';
import 'package:rakoon_frontend/core/utils/route_launcher.dart';

class UnifiedProductPriceDetailPage extends StatefulWidget {
  final RecommendedProduct product;
  final String? baseUrl;
  final http.Client? httpClient;
  final double? userLat;
  final double? userLng;

  const UnifiedProductPriceDetailPage({
    super.key,
    required this.product,
    this.baseUrl,
    this.httpClient,
    this.userLat,
    this.userLng,
  });

  @override
  State<UnifiedProductPriceDetailPage> createState() => _UnifiedProductPriceDetailPageState();
}

class _UnifiedProductPriceDetailPageState extends State<UnifiedProductPriceDetailPage> {
  late PriceCheckProvider _priceCheckProvider;
  final ScrollController _scrollController = ScrollController();
  String? _currentFotoUrl;
  String? _selectedStoreFilterId;
  bool _showAllStores = false;
  double? _effectiveLat;
  double? _effectiveLng;

  @override
  void initState() {
    super.initState();
    _currentFotoUrl = widget.product.fotoUrl;
    _effectiveLat = widget.userLat;
    _effectiveLng = widget.userLng;
    _priceCheckProvider = PriceCheckProvider();
    _priceCheckProvider.addListener(_onPriceCheckProviderUpdated);
    _loadFreshProductDetails();
    _resolveLocationAndFetch();
  }

  Future<void> _resolveLocationAndFetch() async {
    double? lat = widget.userLat;
    double? lng = widget.userLng;

    if (lat == null || lng == null) {
      final cached = LocationService.cachedPosition;
      if (cached != null) {
        lat = cached.latitude;
        lng = cached.longitude;
      } else {
        final locResult = await LocationService.resolveLocation(askPermission: false);
        if (locResult.outcome == LocationOutcome.granted && locResult.position != null) {
          lat = locResult.position!.latitude;
          lng = locResult.position!.longitude;
        }
      }
    }

    if (mounted) {
      setState(() {
        _effectiveLat = lat;
        _effectiveLng = lng;
      });
    }

    _priceCheckProvider.fetchProductDetail(
      productId: widget.product.id,
      userLat: lat,
      userLng: lng,
      range: '1m',
      baseUrl: widget.baseUrl,
      client: widget.httpClient,
    );
  }

  @override
  void dispose() {
    _priceCheckProvider.removeListener(_onPriceCheckProviderUpdated);
    _scrollController.dispose();
    _priceCheckProvider.dispose();
    super.dispose();
  }

  void _onPriceCheckProviderUpdated() {
    if (!mounted) return;
    final compFoto = _priceCheckProvider.comparisonResponse?.fotoUrl;
    if (compFoto != null && compFoto.isNotEmpty && _currentFotoUrl != compFoto) {
      setState(() {
        _currentFotoUrl = compFoto;
      });
    }
  }

  Future<void> _loadFreshProductDetails() async {
    try {
      final effectiveBase = widget.baseUrl ?? AppConfig.apiBaseUrl;
      final product = await ProductsService.getProductById(
        productId: widget.product.id,
        baseUrl: effectiveBase,
        client: widget.httpClient,
      );
      if (mounted && product?.fotoUrl != null && product!.fotoUrl!.isNotEmpty) {
        if (_currentFotoUrl != product.fotoUrl) {
          setState(() {
            _currentFotoUrl = product.fotoUrl;
          });
        }
      }
    } catch (_) {}
  }

  void _onRangeChanged(String range) {
    _priceCheckProvider.updateRange(
      range,
      productId: widget.product.id,
      userLat: _effectiveLat,
      userLng: _effectiveLng,
      baseUrl: widget.baseUrl,
      client: widget.httpClient,
    );
  }

  Widget _buildTrendBadge(List<PriceTrendPoint>? trendPoints) {
    if (trendPoints == null || trendPoints.length < 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_rounded, size: 14, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(
              'Harga Stabil',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      );
    }

    final firstPrice = trendPoints.first.price;
    final lastPrice = trendPoints.last.price;

    if (lastPrice < firstPrice) {
      final diffPct = (((firstPrice - lastPrice) / firstPrice) * 100).toStringAsFixed(0);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_down_rounded, size: 15, color: Color(0xFF059669)),
            const SizedBox(width: 4),
            Text(
              'Harga Turun $diffPct%',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),
      );
    } else if (lastPrice > firstPrice) {
      final diffPct = (((lastPrice - firstPrice) / firstPrice) * 100).toStringAsFixed(0);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_up_rounded, size: 15, color: Color(0xFFD97706)),
            const SizedBox(width: 4),
            Text(
              'Harga Naik $diffPct%',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB45309),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        'Harga Stabil',
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
  }

  String _formatShortDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        return '${parts[2]}/${parts[1]}';
      }
      return dateStr;
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  Widget _buildProductHeroVisual() {
    final effectiveFoto = _currentFotoUrl ?? widget.product.fotoUrl;
    final resolvedUrl = BrandAssets.resolveImageUrl(effectiveFoto, widget.baseUrl);
    final localAsset = BrandAssets.getProductAsset(widget.product.nama, widget.product.kategori);

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return Container(
        width: 115,
        height: 125,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            resolvedUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                localAsset != null ? _buildLocalAssetVisual(localAsset) : _buildFallbackVisual(),
          ),
        ),
      );
    }

    if (localAsset != null) {
      return _buildLocalAssetVisual(localAsset);
    }

    return _buildFallbackVisual();
  }

  Widget _buildLocalAssetVisual(String assetPath) {
    return Container(
      width: 115,
      height: 125,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackVisual(),
        ),
      ),
    );
  }

  Widget _buildFallbackVisual() {
    return Container(
      width: 115,
      height: 125,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
      ),
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 42,
          color: Color(0xFF059669),
        ),
      ),
    );
  }

  Widget? _buildStoreBadge({
    required PriceCompareItem item,
    required PriceCompareItem? bestStore,
    required PriceCompareItem? lowestPriceStore,
    required PriceCompareItem? closestStore,
    required double diff,
  }) {
    if (bestStore != null && item.storeId == bestStore.storeId) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF5EE),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Pilihan Terbaik',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D2818),
          ),
        ),
      );
    }

    if (lowestPriceStore != null && item.storeId == lowestPriceStore.storeId) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Text(
          'Harga Terendah',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4A4A4A),
          ),
        ),
      );
    }

    if (closestStore != null && item.storeId == closestStore.storeId) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Terdekat',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2B4C6F),
          ),
        ),
      );
    }

    if (diff > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          '+${formatRp(diff)}',
          style: GoogleFonts.outfit(
            color: const Color(0xFF4B5563),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return null;
  }

  Widget _buildStoreFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InteractiveScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF0D2818), Color(0xFF2E6644)],
                  )
                : null,
            color: isSelected ? null : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14.0),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildChart(List<PriceTrendPoint> trendPoints, double currentPrice) {
    List<PriceTrendPoint> displayPoints = trendPoints;
    if (_selectedStoreFilterId != null) {
      final filtered = trendPoints.where((p) => p.storeId == _selectedStoreFilterId).toList();
      if (filtered.isNotEmpty) {
        displayPoints = filtered;
      }
    }

    if (displayPoints.isEmpty) {
      return Container(
        height: 65,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          'Belum ada data riwayat harga',
          style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 12),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < displayPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), displayPoints[i].price.toDouble()));
    }

    final prices = displayPoints.map((e) => e.price.toDouble()).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    final priceDiff = maxPrice - minPrice;
    final paddingY = priceDiff > 0 ? priceDiff * 0.2 : (maxPrice > 0 ? maxPrice * 0.15 : 1000.0);
    final minY = (minPrice - paddingY) > 0 ? (minPrice - paddingY) : 0.0;
    final maxY = maxPrice + paddingY;

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF059669),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Terendah: ',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF6B7280)),
                ),
                Text(
                  formatRp(minPrice),
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatRp(displayPoints.last.price.toDouble()),
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Terakhir',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 165,
          child: Padding(
            padding: const EdgeInsets.only(right: 6, top: 6, bottom: 4),
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: maxPrice,
                      color: const Color(0xFFE5E7EB),
                      strokeWidth: 1.0,
                      dashArray: [4, 4],
                    ),
                    HorizontalLine(
                      y: minPrice,
                      color: const Color(0xFF059669).withValues(alpha: 0.35),
                      strokeWidth: 1.0,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < displayPoints.length) {
                          if (idx == 0 || idx == displayPoints.length - 1 || idx == displayPoints.length ~/ 2) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _formatShortDate(displayPoints[idx].date),
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: const Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF059669),
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) => spot.x == spots.last.x,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4.5,
                        color: const Color(0xFF059669),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF059669).withValues(alpha: 0.25),
                          const Color(0xFF059669).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeInfo = (widget.product.ukuran != null && widget.product.satuan != null)
        ? '${widget.product.ukuran!.toStringAsFixed(widget.product.ukuran! % 1 == 0 ? 0 : 1)} ${widget.product.satuan!.toLowerCase()}'
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D2818),
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0D2818)),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Detail Produk',
          style: GoogleFonts.outfit(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D2818),
          ),
        ),
        actions: const [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE8E4DC), height: 1.0),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _priceCheckProvider,
          builder: (context, child) {
            final comparisonItems = _priceCheckProvider.comparisonResponse?.comparison ?? [];
            final sortedComparison = List<PriceCompareItem>.from(comparisonItems)
              ..sort((a, b) {
                final hA = a.hargaTerbaru ?? 9999999;
                final hB = b.hargaTerbaru ?? 9999999;
                return hA.compareTo(hB);
              });

            // Find best, lowest, and closest stores
            final validPrices = sortedComparison
                .map((e) => e.hargaTerbaru?.toDouble())
                .where((p) => p != null && p > 0)
                .map((p) => p!)
                .toList();

            final String priceRangeText;
            if (validPrices.isNotEmpty) {
              final minP = validPrices.reduce((a, b) => a < b ? a : b);
              final maxP = validPrices.reduce((a, b) => a > b ? a : b);
              if (minP < maxP) {
                priceRangeText = '${formatRp(minP)} - ${formatRp(maxP)}';
              } else {
                priceRangeText = formatRp(minP);
              }
            } else {
              priceRangeText = formatRp(widget.product.harga);
            }

            final cheapestStore = sortedComparison.isNotEmpty ? sortedComparison.first : null;
            final double cheapestPrice = cheapestStore?.hargaTerbaru?.toDouble() ?? widget.product.harga;

            PriceCompareItem? lowestPriceStore;
            final storesWithPrice = sortedComparison.where((s) => s.hargaTerbaru != null && s.hargaTerbaru! > 0).toList();
            if (storesWithPrice.isNotEmpty) {
              lowestPriceStore = storesWithPrice.first;
            }

            PriceCompareItem? closestStore;
            if (sortedComparison.isNotEmpty) {
              final withDistance = sortedComparison.map((s) {
                double? d = s.jarakKm;
                if (d == null &&
                    _effectiveLat != null &&
                    _effectiveLng != null &&
                    s.lat != 0.0 &&
                    s.lng != 0.0) {
                  d = const Distance().as(
                    LengthUnit.Kilometer,
                    LatLng(_effectiveLat!, _effectiveLng!),
                    LatLng(s.lat, s.lng),
                  );
                }
                return (item: s, distance: d);
              }).where((p) => p.distance != null).toList();

              if (withDistance.isNotEmpty) {
                withDistance.sort((a, b) => a.distance!.compareTo(b.distance!));
                closestStore = withDistance.first.item;
              }
            }

            PriceCompareItem? bestStore;
            if (lowestPriceStore != null && closestStore != null && lowestPriceStore.storeId == closestStore.storeId) {
              bestStore = lowestPriceStore;
            } else if (sortedComparison.isNotEmpty) {
              bestStore = sortedComparison.first;
            }

            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. PRODUCT HERO CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProductHeroVisual(),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      widget.product.kategori,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.product.nama.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0D2818),
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (sizeInfo != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      sizeInfo,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Clean Price Range Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8E4DC)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rentang Harga Saat Ini',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      priceRangeText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF059669),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildTrendBadge(_priceCheckProvider.historyResponse?.trend),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. SECTION: RIWAYAT HARGA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.trending_up_rounded,
                                  color: Color(0xFF059669),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Riwayat Harga',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0D2818),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Time range filter pills: "30 Hari" & "3 Bulan"
                        Row(
                          children: [
                            {'label': '30 Hari', 'value': '1m'},
                            {'label': '3 Bulan', 'value': '3m'},
                          ].map((opt) {
                            final isSelected = _priceCheckProvider.selectedRange == opt['value'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InteractiveScale(
                                key: Key('range_button_${opt['value']}'),
                                onTap: () => _onRangeChanged(opt['value']!),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? const LinearGradient(
                                                colors: [Color(0xFF0D2818), Color(0xFF2E6644)],
                                              )
                                            : null,
                                        color: isSelected ? null : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(14.0),
                                      ),
                                      child: Text(
                                        opt['label']!,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (_priceCheckProvider.isAutoSelected3m) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Belum ada pembaruan 30 hari terakhir.',
                            key: const Key('auto_range_fallback_note'),
                            style: GoogleFonts.outfit(
                              fontSize: 11.0,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Store filter chips (Maksimal 4 opsi: Semua Toko + 3 toko terdekat)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildStoreFilterChip(
                                label: 'Semua Toko',
                                isSelected: _selectedStoreFilterId == null,
                                onTap: () {
                                  setState(() {
                                    _selectedStoreFilterId = null;
                                  });
                                },
                              ),
                              ...sortedComparison.take(3).map((store) {
                                final isSelected = _selectedStoreFilterId == store.storeId;
                                return _buildStoreFilterChip(
                                  label: store.namaToko,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedStoreFilterId = store.storeId;
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (_priceCheckProvider.isDetailLoading)
                          const SizedBox(
                            height: 165,
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFF059669)),
                            ),
                          )
                        else
                          _buildChart(
                            _priceCheckProvider.historyResponse?.trend ?? [],
                            cheapestPrice,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. SECTION: TERSEDIA DI TOKO TERDEKAT
                  Text(
                    'Tersedia di Toko Terdekat',
                    style: GoogleFonts.outfit(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D2818),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Store price comparison list
                  if (_priceCheckProvider.isDetailLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28.0),
                        child: CircularProgressIndicator(color: Color(0xFF059669)),
                      ),
                    )
                  else if (_priceCheckProvider.detailStatus == PriceCheckStatus.error)
                    Container(
                      key: const Key('comparison_error_container'),
                      padding: const EdgeInsets.all(20.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.0),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Gagal memuat perbandingan harga',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D2818),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _priceCheckProvider.detailErrorMessage ?? 'Terjadi kesalahan saat memuat data toko. Silakan coba lagi.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            key: const Key('retry_detail_button'),
                            onPressed: () {
                              _priceCheckProvider.fetchProductDetail(
                                productId: widget.product.id,
                                userLat: _effectiveLat,
                                userLng: _effectiveLng,
                                range: _priceCheckProvider.selectedRange,
                                baseUrl: widget.baseUrl,
                                client: widget.httpClient,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D2818),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: Text(
                              'Coba lagi',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (sortedComparison.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.0),
                        border: Border.all(color: const Color(0xFFE8E4DC)),
                      ),
                      child: Center(
                        child: Text(
                          'Belum ada data toko di sekitar lokasi Anda.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (_showAllStores ? sortedComparison : sortedComparison.take(5).toList()).length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final displayed = _showAllStores ? sortedComparison : sortedComparison.take(5).toList();
                        final item = displayed[index];
                        final isCheapest = (index == 0 && item.hargaTerbaru != null);
                        final itemPrice = item.hargaTerbaru?.toDouble() ?? 0.0;
                        final diff = itemPrice - cheapestPrice;

                        final badgeWidget = _buildStoreBadge(
                          item: item,
                          bestStore: bestStore,
                          lowestPriceStore: lowestPriceStore,
                          closestStore: closestStore,
                          diff: diff,
                        );

                        double? effectiveDistance = item.jarakKm;
                        if (effectiveDistance == null &&
                            _effectiveLat != null &&
                            _effectiveLng != null &&
                            item.lat != 0.0 &&
                            item.lng != 0.0) {
                          effectiveDistance = const Distance().as(
                            LengthUnit.Kilometer,
                            LatLng(_effectiveLat!, _effectiveLng!),
                            LatLng(item.lat, item.lng),
                          );
                        }

                        final distanceStr = ProductCard.formatDistance(effectiveDistance);

                        return Container(
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: isCheapest ? const Color(0xFFA7F3D0) : const Color(0xFFE8E4DC),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Rank Number Circle
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isCheapest ? const Color(0xFFEBF5EE) : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isCheapest ? const Color(0xFF0D2818) : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Real Store Logo
                              BrandAssets.buildStoreLogo(item.namaToko, size: 38, borderRadius: 10),
                              const SizedBox(width: 12),

                              // Store Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.namaToko,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0D2818),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (distanceStr != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.place_outlined,
                                            size: 11,
                                            color: Color(0xFF6B7280),
                                          ),
                                          const SizedBox(width: 2),
                                          Flexible(
                                            child: Text(
                                              distanceStr,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF6B7280),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (badgeWidget != null) ...[
                                      const SizedBox(height: 4),
                                      badgeWidget,
                                    ],
                                    if (item.stale) ...[
                                      const SizedBox(height: 4),
                                      PriceFreshnessLabel(isStale: true, updatedAt: item.tanggalUpdate),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Price & Route Button
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item.hargaTerbaru != null ? formatRp(itemPrice) : 'Tidak tersedia',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: isCheapest ? const Color(0xFF059669) : const Color(0xFF0D2818),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  StoreRouteButton(
                                    lat: item.lat,
                                    lng: item.lng,
                                    storeName: item.namaToko,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (sortedComparison.length > 5) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _showAllStores = !_showAllStores;
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _showAllStores
                                    ? 'Tampilkan Lebih Sedikit'
                                    : 'Tampilkan Lebih Banyak',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showAllStores ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
