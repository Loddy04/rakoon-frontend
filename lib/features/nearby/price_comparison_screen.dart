import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';
import 'package:rakoon_frontend/widgets/rakoon_location_map.dart';


class PriceComparisonScreen extends StatefulWidget {
  final String productId;
  final String? productName;

  const PriceComparisonScreen({
    super.key,
    required this.productId,
    this.productName,
    required this._baseUrl,
  });

  final String _baseUrl;

  @override
  State<PriceComparisonScreen> createState() => _PriceComparisonScreenState();
}

class _PriceComparisonScreenState extends State<PriceComparisonScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  String? _errorMessage;
  PriceCompareResponse? _comparisonResponse;
  int? _minPrice;
  String? _selectedStoreId;
  double? _userLat;
  double? _userLng;


  @override
  void initState() {
    super.initState();
    _fetchPriceComparison();
  }

  /// Fetches GPS location, then calls the backend comparison API.
  Future<void> _fetchPriceComparison() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _minPrice = null;
      _selectedStoreId = null;
    });

    try {
      // 1. Get GPS coordinates
      final position = await LocationService.getCurrentLocation();
      _userLat = position.latitude;
      _userLng = position.longitude;

      // 2. Query price comparison from backend
      final response = await StoresService.getPriceComparison(
        productId: widget.productId,
        lat: position.latitude,
        lng: position.longitude,
        baseUrl: widget._baseUrl,
      );

      // 3. Find the lowest non-null price in the list for badge highlighting
      int? lowestPrice;
      String? cheapestId;
      for (var item in response.comparison) {
        if (item.hargaTerbaru != null) {
          if (lowestPrice == null || item.hargaTerbaru! < lowestPrice) {
            lowestPrice = item.hargaTerbaru;
            cheapestId = item.storeId;
          }
        }
      }

      setState(() {
        _comparisonResponse = response;
        _minPrice = lowestPrice;
        _selectedStoreId = cheapestId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }


  /// Formats price integers as standard Indonesian Rupiah (e.g. Rp 18.500)
  String _formatRp(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    int count = 0;
    
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count == 3 && i > 0) {
        buffer.write('.');
        count = 0;
      }
    }
    
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  /// Formats ISO datetime strings into readable format (e.g. 08 Agt 2026, 13:45)
  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final parsed = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final day = parsed.day.toString().padLeft(2, '0');
      final month = months[parsed.month - 1];
      final year = parsed.year;
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = _comparisonResponse?.namaProduk ?? widget.productName ?? 'Produk #${widget.productId}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Perbandingan Harga'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPriceComparison,
            tooltip: 'Segarkan Perbandingan',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingWidget(productName)
            : _errorMessage != null
                ? _buildErrorWidget()
                : _comparisonResponse != null
                    ? _buildComparisonList(productName)
                    : const SizedBox.shrink(),
      ),
    );
  }

  /// Renders loading state
  Widget _buildLoadingWidget(String productName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3.5,
          ),
          const SizedBox(height: AppSpacing.l),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              'Membandingkan harga untuk "$productName" di toko-toko terdekat...',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders clean error state box using error Soft design token
  Widget _buildErrorWidget() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.errorSoft,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Gagal Memuat Perbandingan',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                _errorMessage ?? 'Gagal memuat data.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: _fetchPriceComparison,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders listing of stores with price details
  Widget _buildComparisonList(String productName) {
    final response = _comparisonResponse!;
    final items = response.comparison;

    // Build MapStoreMarker list with price sublabel
    final mapMarkers = items
        .where((i) => i.lat != 0.0 || i.lng != 0.0)
        .map((i) => MapStoreMarker(
              storeId: i.storeId,
              lat: i.lat,
              lng: i.lng,
              label: i.namaToko,
              sublabel: i.hargaTerbaru != null ? _formatRp(i.hargaTerbaru!) : null,
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Product header card
        Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.l, AppSpacing.l, AppSpacing.l, AppSpacing.s),
          padding: const EdgeInsets.all(AppSpacing.l),
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
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Map context — shows store locations relative to user
        if (_userLat != null && _userLng != null)
          RakoonLocationMap(
            userLat: _userLat!,
            userLng: _userLng!,
            mapController: _mapController,
            heroTag: 'price_compare_recenter',
            height: 220,
            markers: mapMarkers,
            selectedStoreId: _selectedStoreId,
            onMarkerTap: (storeId) {
              setState(() => _selectedStoreId = storeId);
            },
          ),

        // Comparison list header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            'Perbandingan di Toko Terdekat',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // List View
        Expanded(
          child: items.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.s,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isCheapest = item.hargaTerbaru != null && item.hargaTerbaru == _minPrice;
                    final isSelected = _selectedStoreId == item.storeId;
                    final hasPrice = item.hargaTerbaru != null;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedStoreId = item.storeId);
                        if (item.lat != 0.0 || item.lng != 0.0) {
                          _mapController.move(
                            LatLng(item.lat, item.lng),
                            15.0,
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.m),
                        padding: const EdgeInsets.all(AppSpacing.l),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(
                            // cheapest always keeps accent border; selected also gets accent
                            color: (isCheapest || isSelected) ? AppColors.accent : AppColors.line,
                            width: (isCheapest || isSelected) ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(
                                alpha: isCheapest ? 0.05 : 0.02),
                              blurRadius: isCheapest ? 10 : 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top row: Store Name & Status Badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.namaToko,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                if (isCheapest)
                                  const StatusBadge(status: 'Termurah')
                                else if (!hasPrice)
                                  const StatusBadge(status: 'Belum ada data'),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s),

                            // Divider line
                            const Divider(),
                            const SizedBox(height: AppSpacing.s),

                            // Details row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Distance info
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.directions_walk,
                                        size: 14.0,
                                        color: AppColors.muted,
                                      ),
                                      const SizedBox(width: 4.0),
                                      Flexible(
                                        child: Text(
                                          '${item.jarakKm.toStringAsFixed(2)} km',
                                          style: AppTextStyles.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                // Price or Message
                                if (hasPrice)
                                  Flexible(
                                    child: Text(
                                      _formatRp(item.hargaTerbaru!),
                                      textAlign: TextAlign.end,
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        color: isCheapest
                                            ? AppColors.accent
                                            : AppColors.ink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.0,
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: Text(
                                      item.pesan ?? 'Data tidak tersedia',
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.s),

                            // Footer row: Update time & validation status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Update: ${_formatDateTime(item.tanggalUpdate)}',
                                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.statusVerifikasi != null) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Status: ${item.statusVerifikasi}',
                                      textAlign: TextAlign.end,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: item.statusVerifikasi == 'verified'
                                            ? AppColors.accent
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }


  /// Empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 44.0,
            color: AppColors.muted,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Tidak ada data toko terdekat untuk produk ini.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
