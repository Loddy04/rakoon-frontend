import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';
import 'package:url_launcher/url_launcher.dart';

typedef UrlLauncherFn = Future<bool> Function(Uri uri, {LaunchMode mode});

UrlLauncherFn _routeUrlLauncher = launchUrl;

@visibleForTesting
void setMockRouteUrlLauncher(UrlLauncherFn? mock) {
  _routeUrlLauncher = mock ?? launchUrl;
}

/// Helper function to open Google Maps navigation route to a store without origin coordinates.
Future<bool> launchStoreRoute(
  BuildContext context, {
  required double lat,
  required double lng,
  required String storeName,
}) async {
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
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

/// Reusable Standard Route Button with touch target >= 48x48dp and Indonesian semantics.
class StoreRouteButton extends StatelessWidget {
  final VoidCallback onTap;
  final Key? buttonKey;

  const StoreRouteButton({
    super.key,
    required this.onTap,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Rute',
      child: InteractiveScale(
        key: buttonKey,
        onTap: onTap,
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
