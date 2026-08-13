import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

/// Lightweight data class representing a store pin on the map.
class MapStoreMarker {
  final String storeId;
  final double lat;
  final double lng;

  /// Primary label shown on the marker (usually store name abbreviation).
  final String? label;

  /// Optional sublabel shown below icon (e.g. price string "Rp 18.500").
  final String? sublabel;

  const MapStoreMarker({
    required this.storeId,
    required this.lat,
    required this.lng,
    this.label,
    this.sublabel,
  });
}

/// Reusable map widget used by both NearbyStoresScreen and PriceComparisonScreen.
///
/// Renders:
/// - User location marker (blue)
/// - Store markers (green accent, animated selection)
/// - Recenter FAB
/// - Empty state (only user marker when [markers] is empty)
///
/// The caller owns the [MapController] and [selectedStoreId] state.
class RakoonLocationMap extends StatelessWidget {
  const RakoonLocationMap({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.mapController,
    this.markers = const [],
    this.selectedStoreId,
    this.onMarkerTap,
    this.height = 260,
    this.heroTag = 'rakoon_map_recenter',
  });

  final double userLat;
  final double userLng;
  final MapController mapController;
  final List<MapStoreMarker> markers;
  final String? selectedStoreId;
  final void Function(String storeId)? onMarkerTap;

  /// Fixed pixel height of the map container. Callers control this to keep
  /// the map from dominating the screen, especially in PriceComparisonScreen.
  final double height;

  /// Hero tag for the FAB — must be unique per page if two maps are on screen.
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(userLat, userLng),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rakoon.rakoon_frontend',
              ),
              MarkerLayer(
                markers: [
                  _buildUserMarker(),
                  ...markers.map(_buildStoreMarker),
                ],
              ),
            ],
          ),

          // Recenter FAB
          Positioned(
            bottom: AppSpacing.m,
            right: AppSpacing.m,
            child: Semantics(
              label: 'Pusatkan peta ke lokasi Anda',
              button: true,
              child: FloatingActionButton.small(
                heroTag: heroTag,
                backgroundColor: AppColors.paper,
                foregroundColor: AppColors.ink,
                onPressed: () {
                  mapController.move(LatLng(userLat, userLng), 14.0);
                },
                child: const Icon(Icons.gps_fixed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // User location marker — blue circle with GPS icon
  // ---------------------------------------------------------------------------
  Marker _buildUserMarker() {
    return Marker(
      point: LatLng(userLat, userLng),
      width: 45.0,
      height: 45.0,
      child: Semantics(
        label: 'Lokasi Anda saat ini',
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF2563EB),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.my_location,
              color: Color(0xFF1D4ED8),
              size: 20.0,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Store marker — accent green, animated when selected
  // ---------------------------------------------------------------------------
  Marker _buildStoreMarker(MapStoreMarker store) {
    final isSelected = selectedStoreId == store.storeId;
    final hasPrice = store.sublabel != null;

    return Marker(
      point: LatLng(store.lat, store.lng),
      width: 56.0,
      height: hasPrice ? 68.0 : 52.0,
      child: Semantics(
        label: [
          'Toko: ${store.label ?? store.storeId}',
          if (store.sublabel != null) store.sublabel!,
          if (isSelected) '(dipilih)',
        ].join(', '),
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onMarkerTap?.call(store.storeId),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 40.0 : 32.0,
                height: isSelected ? 40.0 : 32.0,
                decoration: isSelected
                    ? BoxDecoration(
                        color: AppColors.accentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent,
                          width: 2.0,
                        ),
                      )
                    : const BoxDecoration(),
                child: Icon(
                  Icons.store,
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.accent.withValues(alpha: 0.75),
                  size: isSelected ? 24.0 : 20.0,
                ),
              ),
              // Price sublabel on marker
              if (hasPrice)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.ink.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    store.sublabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
