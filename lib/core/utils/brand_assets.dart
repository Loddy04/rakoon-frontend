import 'package:flutter/material.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';

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

  static final RegExp _wordHilo = RegExp(r'\bhilo\b');
  static final RegExp _wordMilo = RegExp(r'\bmilo\b');
  static final RegExp _miloExcludedVariants = RegExp(
    r'\b(bar|batangan|bundle|box|sachet|botol|bottled|bottle|drink)\b',
  );
  static final RegExp _wordUltra = RegExp(r'\bultra\b');
  static final RegExp _wordGreenfields = RegExp(r'\bgreenfields?\b');
  static final RegExp _wordIndomie = RegExp(r'\bindomie\b');
  static final RegExp _wordBimoli = RegExp(r'\bbimoli\b');
  static final RegExp _wordPucukHarum = RegExp(r'\b(pucuk\s*harum|teh\s*pucuk|pucuk)\b');
  static final RegExp _wordCitro = RegExp(r'\bcitro\b');
  static final RegExp _wordAirMineral = RegExp(r'\b(air\s*mineral|aqua|le\s*minerale)\b');

  /// Returns matching store logo asset path if known, otherwise null.
  static String? getStoreAsset(String? storeName) {
    if (storeName == null || storeName.trim().isEmpty) return null;
    final lower = storeName.toLowerCase();
    if (lower.contains('superindo') || lower.contains('super indo')) {
      return null;
    }
    if (lower.contains('alfa')) {
      return alfamart;
    }
    if (lower.contains('indomaret') || lower.contains('idm') || lower.contains('indo')) {
      return indomaret;
    }
    return null;
  }

  /// Returns matching product image asset path if known, otherwise null.
  /// Matches on whole brand word boundaries without false positive cross-brand matches.
  static String? getProductAsset(String? productName, [String? category]) {
    if (productName == null || productName.trim().isEmpty) return null;
    final lowerName = productName.trim().toLowerCase();

    // 1. Air Mineral (Air Mineral, Aqua, Le Minerale)
    if (_wordAirMineral.hasMatch(lowerName)) {
      return airMineral;
    }

    // 2. Teh / Pucuk Harum / Citro Green Tea
    if (_wordCitro.hasMatch(lowerName)) {
      return citroGreenTea;
    }
    if (_wordPucukHarum.hasMatch(lowerName)) {
      return pucukHarum;
    }

    // 3. Susu / Dairy (Greenfields, Milo Calcium, Ultra Milk)
    if (_wordGreenfields.hasMatch(lowerName)) {
      return greenfields;
    }
    if (_wordMilo.hasMatch(lowerName) && !_wordHilo.hasMatch(lowerName)) {
      if (!_miloExcludedVariants.hasMatch(lowerName)) {
        return miloCalcium;
      }
      return null;
    }
    if (_wordUltra.hasMatch(lowerName)) {
      return ultramilk;
    }

    // 4. Mie Instan (Indomie)
    if (_wordIndomie.hasMatch(lowerName)) {
      return indomie;
    }

    // 5. Minyak Goreng (Bimoli)
    if (_wordBimoli.hasMatch(lowerName)) {
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

  /// Resolves an image URL (handling relative server upload paths like /static/uploads/...) to an absolute URL.
  static String? resolveImageUrl(String? url, [String? baseUrl]) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final effectiveBase = (baseUrl != null && baseUrl.isNotEmpty)
        ? baseUrl
        : AppConfig.apiBaseUrl;
    final cleanBase = effectiveBase.endsWith('/')
        ? effectiveBase.substring(0, effectiveBase.length - 1)
        : effectiveBase;
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$cleanBase$cleanPath';
  }
}
