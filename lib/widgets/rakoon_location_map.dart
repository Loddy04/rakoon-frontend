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

/// Reusable map widget used by NearbyStoresScreen, PriceComparisonScreen, and HomeScreen.
class RakoonLocationMap extends StatelessWidget {
  const RakoonLocationMap({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.mapController,
    this.markers = const [],
    this.selectedStoreId,
    this.onMarkerTap,
    this.onMapTap,
    this.height = 260,
    this.heroTag = 'rakoon_map_recenter',
    this.margin,
    this.borderRadius,
    this.border,
    this.boxShadow,
  });

  final double userLat;
  final double userLng;
  final MapController mapController;
  final List<MapStoreMarker> markers;
  final String? selectedStoreId;
  final void Function(String storeId)? onMarkerTap;
  final VoidCallback? onMapTap;

  /// Fixed pixel height of the map container.
  final double height;

  /// Hero tag for the FAB — must be unique per page.
  final String heroTag;

  /// Optional custom outer margin. Defaults to standard screen margin if null.
  final EdgeInsetsGeometry? margin;

  /// Optional custom border radius.
  final BorderRadiusGeometry? borderRadius;

  /// Optional custom border.
  final Border? border;

  /// Optional custom box shadow.
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final effectiveMargin = margin ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.s,
        );
    final effectiveRadius = borderRadius ?? BorderRadius.circular(3.0);
    final effectiveBorder =
        border ?? Border.all(color: AppColors.graphite, width: 1.0);

    return Container(
      height: height,
      margin: effectiveMargin,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: effectiveRadius,
        border: effectiveBorder,
        boxShadow: boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onMapTap,
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: LatLng(userLat, userLng),
                initialZoom: 14.0,
                onTap: (tapPosition, point) {
                  onMapTap?.call();
                },
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
                  foregroundColor: AppColors.graphite,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.0),
                    side: const BorderSide(color: AppColors.graphite, width: 1.0),
                  ),
                  onPressed: () {
                    mapController.move(LatLng(userLat, userLng), 14.0);
                  },
                  child: const Icon(Icons.gps_fixed, size: 16),
                ),
              ),
            ),
          ],
        ),
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
            color: AppColors.periwinkle.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.periwinkle,
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.my_location,
              color: AppColors.periwinkle,
              size: 20.0,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Store marker — minimal pin icon
  // ---------------------------------------------------------------------------
  Marker _buildStoreMarker(MapStoreMarker store) {
    final isSelected = selectedStoreId == store.storeId;

    return Marker(
      point: LatLng(store.lat, store.lng),
      width: 44.0,
      height: 44.0,
      child: Semantics(
        label: 'Toko: ${store.label ?? store.storeId}',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (onMarkerTap != null) {
              onMarkerTap!(store.storeId);
            } else if (onMapTap != null) {
              onMapTap!();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.periwinkle : AppColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.graphite,
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: isSelected ? AppColors.paper : AppColors.graphite,
                  size: 18.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
