import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';
import 'package:rakoon_frontend/widgets/rakoon_location_map.dart';


class NearbyStoresScreen extends StatefulWidget {
  final String baseUrl;
  final double? initialLat;
  final double? initialLng;

  const NearbyStoresScreen({
    super.key,
    required this.baseUrl,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<NearbyStoresScreen> createState() => _NearbyStoresScreenState();
}

class _NearbyStoresScreenState extends State<NearbyStoresScreen> {
  final MapController _mapController = MapController();

  void _showStoreDetail(BuildContext context, StoreNearby store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18.0,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      BrandAssets.buildStoreLogo(store.nama, size: 44, borderRadius: 12),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.pin_drop_outlined, 'Koordinat', 'Lat: ${store.lat.toStringAsFixed(6)}, Lng: ${store.lng.toStringAsFixed(6)}'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.directions_walk, 'Jarak dari lokasi Anda', '${store.jarakKm.toStringAsFixed(2)} km'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.cloud_queue_outlined, 'Sumber Data POI', store.source == 'osm' ? 'OpenStreetMap' : 'Database Lokal'),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
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
      Position position;
      if (widget.initialLat != null && widget.initialLng != null) {
        position = Position(
          latitude: widget.initialLat!,
          longitude: widget.initialLng!,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 0.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 0.0,
          speedAccuracy: 1.0,
        );
      } else {
        position = await LocationService.getCurrentLocation();
      }
      _userPosition = position;

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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Toko Terdekat',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
            color: Color(0xFF111827),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFF1F5F9), height: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF059669)),
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

  /// Renders individual store card
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
          horizontal: 6.0,
          vertical: 6.0,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14.0,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 3),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BrandAssets.buildStoreLogo(store.nama, size: 36, borderRadius: 10),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'ID: ${store.storeId.length > 8 ? store.storeId.substring(0, 8) : store.storeId}...',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      size: 15.0,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '${store.jarakKm.toStringAsFixed(2)} km',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
                StatusBadge(
                  status: store.source == 'osm' ? 'OSM' : 'Lokal',
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showStoreDetail(context, store),
                icon: const Icon(Icons.info_outline_rounded, size: 14.0),
                label: const Text(
                  'Detail Toko',
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  backgroundColor: isSelected ? const Color(0xFF059669) : const Color(0xFFECFDF5),
                  foregroundColor: isSelected ? Colors.white : const Color(0xFF059669),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
