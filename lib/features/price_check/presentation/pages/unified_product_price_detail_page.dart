import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/features/history/data/models/price_history_item.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/bouncy_button.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';
import 'package:rakoon_frontend/widgets/rakoon_location_map.dart';

class UnifiedProductPriceDetailPage extends StatefulWidget {
  final RecommendedProduct product;
  final String? baseUrl;
  final http.Client? httpClient;
  final double userLat;
  final double userLng;

  const UnifiedProductPriceDetailPage({
    super.key,
    required this.product,
    this.baseUrl,
    this.httpClient,
    this.userLat = -7.7829,
    this.userLng = 110.4083,
  });

  @override
  State<UnifiedProductPriceDetailPage> createState() => _UnifiedProductPriceDetailPageState();
}

class _UnifiedProductPriceDetailPageState extends State<UnifiedProductPriceDetailPage> {
  late PriceCheckProvider _priceCheckProvider;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _priceCheckProvider = PriceCheckProvider();
    _priceCheckProvider.fetchProductDetail(
      productId: widget.product.id,
      userLat: widget.userLat,
      userLng: widget.userLng,
      range: '1m',
      baseUrl: widget.baseUrl,
      client: widget.httpClient,
    );
  }

  @override
  void dispose() {
    _priceCheckProvider.dispose();
    super.dispose();
  }

  void _onRangeChanged(String range) {
    _priceCheckProvider.updateRange(
      range,
      productId: widget.product.id,
      userLat: widget.userLat,
      userLng: widget.userLng,
      baseUrl: widget.baseUrl,
      client: widget.httpClient,
    );
  }

  Widget _buildTrendBadge(List<PriceTrendPoint>? trendPoints) {
    if (trendPoints == null || trendPoints.length < 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          borderRadius: BorderRadius.circular(AppRadius.cards),
          border: Border.all(color: AppColors.graphite.withValues(alpha: 0.2)),
        ),
        child: Text(
          'STABIL',
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.graphite,
          ),
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
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(AppRadius.cards),
          border: Border.all(color: const Color(0xFF4CAF50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_down, size: 14, color: Color(0xFF2E7D32)),
            const SizedBox(width: 4),
            Text(
              'TURUN $diffPct%',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2E7D32),
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
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(AppRadius.cards),
          border: Border.all(color: const Color(0xFFE53935)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_up, size: 14, color: Color(0xFFC62828)),
            const SizedBox(width: 4),
            Text(
              'NAIK $diffPct%',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFC62828),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(AppRadius.cards),
        border: Border.all(color: AppColors.graphite.withValues(alpha: 0.2)),
      ),
      child: Text(
        'STABIL',
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.graphite,
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

  Widget _buildChart(List<PriceTrendPoint> trendPoints) {
    if (trendPoints.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Text(
          'Belum ada data grafik tren historis',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.fog),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < trendPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), trendPoints[i].price.toDouble()));
    }

    final prices = trendPoints.map((e) => e.price.toDouble()).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    final priceDiff = maxPrice - minPrice;
    final paddingY = priceDiff > 0 ? priceDiff * 0.15 : (maxPrice > 0 ? maxPrice * 0.1 : 1000.0);
    final minY = (minPrice - paddingY) > 0 ? (minPrice - paddingY) : 0.0;
    final maxY = maxPrice + paddingY;

    return Column(
      children: [
        // Dynamic price summary row (Terendah & Tertinggi calculated dynamically)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.graphite,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Terendah: ',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.fog),
                  ),
                  Text(
                    formatRp(minPrice),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.graphite,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Tertinggi: ',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.fog),
                  ),
                  Text(
                    formatRp(maxPrice),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.graphite,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: maxPrice,
                      color: AppColors.graphite.withValues(alpha: 0.35),
                      strokeWidth: 1.2,
                      dashArray: [5, 5],
                    ),
                    HorizontalLine(
                      y: minPrice,
                      color: AppColors.graphite.withValues(alpha: 0.35),
                      strokeWidth: 1.2,
                      dashArray: [5, 5],
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
                        if (idx >= 0 && idx < trendPoints.length) {
                          if (idx == 0 || idx == trendPoints.length - 1 || idx == trendPoints.length ~/ 2) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _formatShortDate(trendPoints[idx].date),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 10,
                                  color: AppColors.fog,
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
                    isCurved: false,
                    color: AppColors.graphite,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.graphite.withValues(alpha: 0.10),
                          AppColors.graphite.withValues(alpha: 0.0),
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
        ? '${widget.product.ukuran!.toStringAsFixed(widget.product.ukuran! % 1 == 0 ? 0 : 1)} ${widget.product.satuan!.toUpperCase()}'
        : null;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          'DETAIL HARGA PRODUK',
          style: AppTextStyles.subheading.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.graphite,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.graphite,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Section: Product Summary Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.softWhite,
                  borderRadius: BorderRadius.circular(AppRadius.cards),
                  border: Border.all(color: AppColors.graphite, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(AppRadius.cards),
                            border: Border.all(color: AppColors.graphite.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            sizeInfo != null ? '$sizeInfo · ${widget.product.kategori}' : widget.product.kategori,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.graphite,
                            ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: _priceCheckProvider,
                          builder: (context, child) {
                            return _buildTrendBadge(_priceCheckProvider.historyResponse?.trend);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      widget.product.nama.toUpperCase(),
                      style: AppTextStyles.headingSm.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.graphite,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatRp(widget.product.harga),
                          style: AppTextStyles.headingLg.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.graphite,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Text(
                          'harga terendah',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            color: AppColors.fog,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s20),

              // 2. Middle Section: Price History Chart Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppRadius.cards),
                  border: Border.all(color: AppColors.graphite, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TREN FLUKTUASI HARGA',
                          style: AppTextStyles.subheading.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: AppColors.graphite,
                          ),
                        ),
                        const Icon(Icons.show_chart_rounded, color: AppColors.periwinkle, size: 20),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Time range filter chips (1M, 3M, 6M, Semua)
                    ListenableBuilder(
                      listenable: _priceCheckProvider,
                      builder: (context, child) {
                        final rangeOptions = [
                          {'label': '1M', 'value': '1m'},
                          {'label': '3M', 'value': '3m'},
                          {'label': '6M', 'value': '6m'},
                          {'label': 'Semua', 'value': 'all'},
                        ];

                        return Row(
                          children: rangeOptions.map((opt) {
                            final isSelected = _priceCheckProvider.selectedRange == opt['value'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: BouncyButton(
                                onPressed: () => _onRangeChanged(opt['value']!),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                borderRadius: BorderRadius.circular(AppRadius.cards),
                                variant: isSelected ? BouncyButtonVariant.accentAction : BouncyButtonVariant.primaryPill,
                                child: Text(
                                  opt['label']!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? AppColors.paper : AppColors.graphite,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    ListenableBuilder(
                      listenable: _priceCheckProvider,
                      builder: (context, child) {
                        if (_priceCheckProvider.isDetailLoading) {
                          return const SizedBox(
                            height: 180,
                            child: Center(
                              child: CircularProgressIndicator(color: AppColors.periwinkle),
                            ),
                          );
                        }

                        final trend = _priceCheckProvider.historyResponse?.trend ?? [];
                        return _buildChart(trend);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s20),

              // 3. Bottom Section: Mini Map & Store Price Comparison List
              Text(
                'PERBANDINGAN DI TOKO TERDEKAT',
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.graphite,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              // Compact Interactive Mini Map (Gesture collision safe)
              ListenableBuilder(
                listenable: _priceCheckProvider,
                builder: (context, child) {
                  final comparisonItems = _priceCheckProvider.comparisonResponse?.comparison ?? [];
                  final storeMarkers = <MapStoreMarker>[];

                  for (final item in comparisonItems) {
                    storeMarkers.add(
                      MapStoreMarker(
                        storeId: item.storeId,
                        lat: item.lat,
                        lng: item.lng,
                        label: item.namaToko,
                      ),
                    );
                  }

                  return RakoonLocationMap(
                    userLat: widget.userLat,
                    userLng: widget.userLng,
                    mapController: _mapController,
                    markers: storeMarkers,
                    height: 160,
                    margin: EdgeInsets.zero,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s16),

              // Store Price Comparison List
              ListenableBuilder(
                listenable: _priceCheckProvider,
                builder: (context, child) {
                  if (_priceCheckProvider.isDetailLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.cardPadding),
                        child: CircularProgressIndicator(color: AppColors.periwinkle),
                      ),
                    );
                  }

                  final comparisonItems = _priceCheckProvider.comparisonResponse?.comparison ?? [];

                  if (comparisonItems.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.cardPadding),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius: BorderRadius.circular(AppRadius.cards),
                        border: Border.all(color: AppColors.graphite.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          'Belum ada data perbandingan harga toko di sekitar lokasi Anda.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.fog),
                        ),
                      ),
                    );
                  }

                  // Sort lowest price first
                  final sortedList = List.from(comparisonItems)
                    ..sort((a, b) {
                      final hA = a.hargaTerbaru ?? 9999999;
                      final hB = b.hargaTerbaru ?? 9999999;
                      return hA.compareTo(hB);
                    });

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s12),
                    itemBuilder: (context, index) {
                      final item = sortedList[index];
                      final isCheapest = (index == 0 && item.hargaTerbaru != null);

                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        decoration: BoxDecoration(
                          color: isCheapest ? AppColors.softWhite : AppColors.paper,
                          borderRadius: BorderRadius.circular(AppRadius.cards),
                          border: Border.all(
                            color: isCheapest ? AppColors.graphite : AppColors.graphite.withValues(alpha: 0.2),
                            width: isCheapest ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.namaToko,
                                    style: AppTextStyles.subheading.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.graphite,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCheapest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.graphite,
                                      borderRadius: BorderRadius.circular(AppRadius.cards),
                                    ),
                                    child: Text(
                                      'TERMURAH',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.paper,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            const Divider(height: 1, color: AppColors.line),
                            const SizedBox(height: AppSpacing.s12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.directions_walk_rounded, size: 16, color: AppColors.fog),
                                    const SizedBox(width: 4),
                                    Text(
                                      ProductCard.formatDistance(item.jarakKm),
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.fog),
                                    ),
                                  ],
                                ),
                                Text(
                                  item.hargaTerbaru != null ? formatRp(item.hargaTerbaru!.toDouble()) : 'N/A',
                                  style: AppTextStyles.subheading.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.graphite,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Update: ${ProductCard.formatTimeAgo(item.tanggalUpdate)}',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppColors.fog,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
