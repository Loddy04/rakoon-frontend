import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';
import 'package:url_launcher/url_launcher.dart';

typedef UrlLauncherFn = Future<bool> Function(Uri uri, {LaunchMode mode});

UrlLauncherFn _routeUrlLauncher = launchUrl;

@visibleForTesting
void setMockRouteUrlLauncher(UrlLauncherFn? mock) {
  _routeUrlLauncher = mock ?? launchUrl;
}

/// Helper function to open Google Maps navigation route to a store with optional origin coordinates.
Future<bool> launchStoreRoute(
  BuildContext context, {
  required double lat,
  required double lng,
  required String storeName,
  Position? origin,
  double? originLat,
  double? originLng,
}) async {
  final Uri uri;
  final oLat = origin?.latitude ?? originLat;
  final oLng = origin?.longitude ?? originLng;

  if (oLat != null && oLng != null) {
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$oLat,$oLng&destination=$lat,$lng&travelmode=driving',
    );
  } else {
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
  }

  if (kDebugMode) {
    debugPrint(uri.toString());
  }

  try {
    final launched = await _routeUrlLauncher(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka rute ke $storeName', style: GoogleFonts.outfit()),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return launched;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka aplikasi navigasi', style: GoogleFonts.outfit()),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return false;
  }
}

/// Reusable Standard Route Button with touch target >= 48x48dp, Indonesian semantics,
/// progress indicator while fetching fresh location, and double-tap prevention.
class StoreRouteButton extends StatefulWidget {
  final VoidCallback? onTap;
  final double? lat;
  final double? lng;
  final String? storeName;
  final Key? buttonKey;
  final Future<Position?> Function({Duration timeout})? getFreshPosition;

  const StoreRouteButton({
    super.key,
    this.onTap,
    this.lat,
    this.lng,
    this.storeName,
    this.buttonKey,
    this.getFreshPosition,
  });

  @override
  State<StoreRouteButton> createState() => _StoreRouteButtonState();
}

class _StoreRouteButtonState extends State<StoreRouteButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading) return;

    if (widget.lat != null && widget.lng != null && widget.storeName != null) {
      setState(() => _isLoading = true);
      try {
        final getPos = widget.getFreshPosition ?? LocationService.getFreshPosition;
        final freshPos = await getPos();
        if (mounted) {
          await launchStoreRoute(
            context,
            lat: widget.lat!,
            lng: widget.lng!,
            storeName: widget.storeName!,
            origin: freshPos,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (widget.onTap != null) {
      setState(() => _isLoading = true);
      try {
        widget.onTap!();
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Rute',
      child: InteractiveScale(
        key: widget.buttonKey,
        onTap: _isLoading ? () {} : _handlePress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF5EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                      ),
                    )
                  else
                    const Icon(
                      Icons.near_me_rounded,
                      size: 15,
                      color: Color(0xFF059669),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    'Rute',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
