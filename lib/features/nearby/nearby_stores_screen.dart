import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';
import 'package:rakoon_frontend/widgets/rakoon_location_map.dart';


class NearbyStoresScreen extends StatefulWidget {
  final String baseUrl;

  const NearbyStoresScreen({
    super.key,
    required this.baseUrl,
  });

  @override
  State<NearbyStoresScreen> createState() => _NearbyStoresScreenState();
}

class _NearbyStoresScreenState extends State<NearbyStoresScreen> {
  final MapController _mapController = MapController();

  void _showStoreDetail(BuildContext context, StoreNearby store) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      backgroundColor: AppColors.paper,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      store.nama,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Icon(
                    Icons.storefront,
                    color: AppColors.accent,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              const Divider(color: AppColors.line),
              const SizedBox(height: AppSpacing.m),
              _buildDetailRow(Icons.pin_drop_outlined, 'Koordinat', 'Lat: ${store.lat.toStringAsFixed(6)}, Lng: ${store.lng.toStringAsFixed(6)}'),
              const SizedBox(height: AppSpacing.s),
              _buildDetailRow(Icons.directions_walk, 'Jarak dari lokasi Anda', '${store.jarakKm.toStringAsFixed(2)} km'),
              const SizedBox(height: AppSpacing.s),
              _buildDetailRow(Icons.cloud_queue_outlined, 'Sumber Data POI', store.source == 'osm' ? 'OpenStreetMap' : 'Database Lokal'),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.paper,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  bool _isLoading = true;
  String? _errorMessage;
  
  Position? _userPosition;
  NearbyStoresResponse? _storesResponse;
  StoreNearby? _selectedStore;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndStores();
  }

  /// Gets location and queries the backend for stores.
  Future<void> _fetchLocationAndStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedStore = null;
    });

    try {
      // 1. Get GPS coordinates
      final position = await LocationService.getCurrentLocation();
      _userPosition = position;

      // 2. Fetch stores using GPS coordinates
      final response = await StoresService.getNearbyStores(
        lat: position.latitude,
        lng: position.longitude,
        baseUrl: widget.baseUrl,
      );

      setState(() {
        _storesResponse = response;
        if (response.stores.isNotEmpty) {
          _selectedStore = response.stores.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = !_isLoading && _userPosition != null && _storesResponse != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Toko Terdekat'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLocationAndStores,
            tooltip: 'Segarkan Data',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingWidget()
            : _errorMessage != null
                ? _buildErrorWidget()
                : hasData
                    ? _buildMainLayout()
                    : const SizedBox.shrink(),
      ),
    );
  }

  /// Renders loading spinner and message
  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3.5,
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'Mencari koordinat & toko terdekat...',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
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
                'Terjadi Kesalahan',
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
                onPressed: _fetchLocationAndStores,
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

  /// Renders main screen split between OSM Map and Store Info list
  Widget _buildMainLayout() {
    final response = _storesResponse!;
    final stores = response.stores;
    final isFallback = response.source == 'local_fallback';
    final hasWarningMsg = response.message != null && response.message!.isNotEmpty;

    // Check if we should display warning banner
    final showWarning = hasWarningMsg;
    final warningText = hasWarningMsg ? response.message! : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Map Section — via shared RakoonLocationMap
        Expanded(
          flex: 4,
          child: RakoonLocationMap(
            userLat: _userPosition!.latitude,
            userLng: _userPosition!.longitude,
            mapController: _mapController,
            heroTag: 'nearby_stores_recenter',
            selectedStoreId: _selectedStore?.storeId,
            onMarkerTap: (storeId) {
              final store = stores.firstWhere(
                (s) => s.storeId == storeId,
                orElse: () => stores.first,
              );
              setState(() => _selectedStore = store);
              _mapController.move(
                LatLng(store.lat, store.lng),
                _mapController.camera.zoom,
              );
            },
            markers: stores
                .map((s) => MapStoreMarker(
                      storeId: s.storeId,
                      lat: s.lat,
                      lng: s.lng,
                      label: s.nama,
                    ))
                .toList(),
          ),
        ),

        // 2. Warning Status Badge Banner
        if (showWarning)
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.xs,
            ),
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const StatusBadge(status: 'Warning'),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    warningText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 3. Info List Section
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.s,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toko Terdekat (${stores.length})',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isFallback)
                      const StatusBadge(status: 'Offline'),
                  ],
                ),
              ),
              Expanded(
                child: stores.isEmpty
                    ? _buildEmptyStoresState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.l,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: stores.length,
                        itemBuilder: (context, index) {
                          final store = stores[index];
                          final isSelected = _selectedStore?.storeId == store.storeId;
                          
                          return _buildStoreCard(store, isSelected);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Renders individual premium store visual card
  Widget _buildStoreCard(StoreNearby store, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStore = store;
        });
        _mapController.move(
          LatLng(store.lat, store.lng),
          _mapController.camera.zoom,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: MediaQuery.of(context).size.width * 0.72,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.s,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.line,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: isSelected ? 0.06 : 0.03),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        store.nama,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.storefront,
                      color: isSelected ? AppColors.accent : AppColors.muted,
                      size: 20.0,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ID: ${store.storeId.length > 8 ? store.storeId.substring(0, 8) : store.storeId}...',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk,
                      size: 14.0,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '${store.jarakKm.toStringAsFixed(2)} km',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                StatusBadge(
                  status: store.source == 'osm' ? 'OSM' : 'Lokal',
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showStoreDetail(context, store),
                icon: const Icon(Icons.info_outline, size: 14.0),
                label: const Text(
                  'Detail Toko',
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  backgroundColor: AppColors.accentSoft,
                  foregroundColor: AppColors.accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders state if no stores are found nearby
  Widget _buildEmptyStoresState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 40.0,
            color: AppColors.muted,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Tidak ada toko terdeteksi di sekitar Anda.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

