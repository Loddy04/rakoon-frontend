import 'package:flutter/material.dart';

/// Helper utility for managing local brand and product assets.
class BrandAssets {
  BrandAssets._();

  static const String rakoonLogo = 'assets/logo/rakoon_logo.png';
  static const String alfamart = 'assets/logo/img/alfamart.png';
  static const String indomaret = 'assets/logo/img/indomaret.png';
  static const String indomie = 'assets/logo/img/indomie.png';
  static const String bimoli = 'assets/logo/img/bimoli.png';
  static const String ultramilk = 'assets/logo/img/ultramilk.png';
  static const String airMineral = 'assets/logo/img/Air Mineral.png';
  static const String citroGreenTea = 'assets/logo/img/Citro Green Tea.png';
  static const String greenfields = 'assets/logo/img/Greenfields.png';
  static const String miloCalcium = 'assets/logo/img/Milo Calcium.png';
  static const String pucukHarum = 'assets/logo/img/Pucuk Harum.png';

  /// Returns matching store logo asset path if known, otherwise null.
  static String? getStoreAsset(String? storeName) {
    if (storeName == null || storeName.trim().isEmpty) return null;
    final lower = storeName.toLowerCase();
    if (lower.contains('alfa')) {
      return alfamart;
    }
    if ((lower.contains('indo') && !lower.contains('superindo')) || lower.contains('idm')) {
      return indomaret;
    }
    return null;
  }

  /// Returns matching product image asset path if known, otherwise null.
  static String? getProductAsset(String? productName, [String? category]) {
    final lowerName = (productName ?? '').toLowerCase();
    final lowerCat = (category ?? '').toLowerCase();

    // 1. Air Mineral / Minuman Botol
    if (lowerName.contains('mineral') ||
        lowerName.contains('air ') ||
        lowerName.contains('air mineral') ||
        lowerName.contains('aqua') ||
        lowerName.contains('le minerale') ||
        lowerName.contains('pocari')) {
      return airMineral;
    }

    // 2. Teh / Pucuk Harum / Citro Green Tea
    if (lowerName.contains('citro') || lowerName.contains('green tea')) {
      return citroGreenTea;
    }
    if (lowerName.contains('pucuk') ||
        lowerName.contains('teh ') ||
        lowerName.contains('tea') ||
        lowerName.contains('harum') ||
        lowerName.contains('botol teh')) {
      return pucukHarum;
    }

    // 3. Susu / Dairy (Greenfields, Milo, Ultra Milk)
    if (lowerName.contains('greenfield')) {
      return greenfields;
    }
    if (lowerName.contains('milo') || lowerName.contains('cokelat') || lowerName.contains('calcium')) {
      return miloCalcium;
    }
    if (lowerName.contains('ultra') ||
        lowerName.contains('milk') ||
        lowerName.contains('susu') ||
        lowerName.contains('dancow') ||
        lowerName.contains('dairy') ||
        lowerCat.contains('susu')) {
      return ultramilk;
    }

    // 4. Mie Instan
    if (lowerName.contains('indomie') ||
        lowerName.contains('mie') ||
        lowerName.contains('sedaap') ||
        lowerName.contains('sedap') ||
        lowerName.contains('ramen') ||
        lowerName.contains('noodle') ||
        lowerCat.contains('instan')) {
      return indomie;
    }

    // 5. Minyak Goreng / Makanan Pokok
    if (lowerName.contains('bimoli') ||
        lowerName.contains('minyak') ||
        lowerName.contains('sania') ||
        lowerName.contains('filma') ||
        lowerName.contains('sunco') ||
        lowerName.contains('fortune') ||
        lowerName.contains('tropical') ||
        lowerCat.contains('minyak')) {
      return bimoli;
    }

    return null;
  }

  /// Builds a clean store logo widget with circular/rounded container.
  static Widget buildStoreLogo(
    String? storeName, {
    double size = 28.0,
    double borderRadius = 8.0,
    Color fallbackBgColor = const Color(0xFFF1F8F4),
    Color fallbackIconColor = const Color(0xFF166534),
  }) {
    final lower = (storeName ?? '').toLowerCase();
    final asset = getStoreAsset(storeName);

    if (asset != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.1),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFE8E4DC), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.storefront_rounded,
            size: size * 0.65,
            color: fallbackIconColor,
          ),
        ),
      );
    }

    // Superindo stylized badge
    if (lower.contains('superindo') || lower.contains('super indo')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE11919),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFB91C1C), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE11919).withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_rounded,
                size: size * 0.44,
                color: Colors.white,
              ),
              Text(
                'SUPERINDO',
                style: TextStyle(
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                  height: 0.9,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Hypermart stylized badge
    if (lower.contains('hypermart')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD200),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFF1E40AF), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'h',
            style: TextStyle(
              fontSize: size * 0.65,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E40AF),
              fontFamily: 'sans-serif',
              height: 1.0,
            ),
          ),
        ),
      );
    }

    // Fallback store icon
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackBgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE8E4DC), width: 0.8),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: size * 0.62,
          color: fallbackIconColor,
        ),
      ),
    );
  }
}
