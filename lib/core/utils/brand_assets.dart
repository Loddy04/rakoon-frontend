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

  /// Returns matching store logo asset path if known, otherwise null.
  static String? getStoreAsset(String? storeName) {
    if (storeName == null || storeName.trim().isEmpty) return null;
    final lower = storeName.toLowerCase();
    if (lower.contains('alfa')) {
      return alfamart;
    }
    if (lower.contains('indo') || lower.contains('idm')) {
      return indomaret;
    }
    return null;
  }

  /// Returns matching product image asset path if known, otherwise null.
  static String? getProductAsset(String? productName, [String? category]) {
    final lowerName = (productName ?? '').toLowerCase();
    final lowerCat = (category ?? '').toLowerCase();

    // 1. Mie Instan
    if (lowerName.contains('indomie') ||
        lowerName.contains('mie') ||
        lowerName.contains('sedaap') ||
        lowerName.contains('sedap') ||
        lowerName.contains('ramen') ||
        lowerName.contains('noodle') ||
        lowerCat.contains('instan')) {
      return indomie;
    }

    // 2. Minyak Goreng
    if (lowerName.contains('bimoli') ||
        lowerName.contains('minyak') ||
        lowerName.contains('sania') ||
        lowerName.contains('filma') ||
        lowerName.contains('tropical') ||
        lowerName.contains('fortune') ||
        lowerCat.contains('minyak')) {
      return bimoli;
    }

    // 3. Susu & Dairy
    if (lowerName.contains('ultra') ||
        lowerName.contains('milk') ||
        lowerName.contains('susu') ||
        lowerName.contains('dancow') ||
        lowerName.contains('dairy') ||
        lowerCat.contains('susu')) {
      return ultramilk;
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
    final asset = getStoreAsset(storeName);

    if (asset != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
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
