import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

/// Reusable ProductCard widget complying with UI_RULES.md.
/// - InkWell root interaction for product detail navigation.
/// - Smooth rounded corners (16px), white background, soft shadow.
/// - Fixed-height 2-line title container to prevent uneven grid heights.
/// - No green (+) add button.
/// - Store logo (16x16), store name, separator dot, and distance with lowercase unit (m/km).
/// - No upload/update timestamps displayed.
class ProductCard extends StatelessWidget {
  final RecommendedProduct product;
  final VoidCallback? onTap;
  final double width;
  final EdgeInsetsGeometry? margin;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.width = 175,
    this.margin,
  });

  /// Format distance to lowercase units: 'm' and 'km' (per UI_RULES.md).
  static String formatDistance(double? jarakKm) {
    if (jarakKm == null) return '800 m';
    if (jarakKm < 1.0) {
      final meters = (jarakKm * 1000).round();
      return '$meters m';
    } else {
      return '${jarakKm.toStringAsFixed(1)} km';
    }
  }

  /// Utility to format time ago (preserved for backward compatibility).
  static String formatTimeAgo(String? rawUpdatedAt) {
    if (rawUpdatedAt == null || rawUpdatedAt.trim().isEmpty) {
      return 'just now';
    }
    final trimmed = rawUpdatedAt.trim();

    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final now = DateTime.now();
      final diff = now.difference(parsed.toLocal());
      if (diff.isNegative || diff.inSeconds < 60) {
        return 'just now';
      }
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      }
      if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      }
      final weeks = diff.inDays ~/ 7;
      return '${weeks}w ago';
    }

    final lower = trimmed.toLowerCase();
    if (lower.contains('baru saja') || lower.contains('just now')) {
      return 'just now';
    }

    final regWeeks = RegExp(r'(\d+)\s*(minggu|w|week|wk)\b');
    final matchWeek = regWeeks.firstMatch(lower);
    if (matchWeek != null) {
      return '${matchWeek.group(1)}w ago';
    }

    final regDays = RegExp(r'(\d+)\s*(hari|d|day)\b');
    final matchDay = regDays.firstMatch(lower);
    if (matchDay != null) {
      return '${matchDay.group(1)}d ago';
    }

    final regHours = RegExp(r'(\d+)\s*(jam|h|hr)\b');
    final matchHour = regHours.firstMatch(lower);
    if (matchHour != null) {
      return '${matchHour.group(1)}h ago';
    }

    final regMinutes = RegExp(r'(\d+)\s*(mnt|menit|m)\b');
    final matchMin = regMinutes.firstMatch(lower);
    if (matchMin != null) {
      return '${matchMin.group(1)}m ago';
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final String formattedPrice = formatRp(product.harga);
    final String sizeInfo = (product.ukuran != null &&
            product.satuan != null &&
            product.satuan!.isNotEmpty)
        ? '${product.ukuran!.toStringAsFixed(product.ukuran! % 1 == 0 ? 0 : 1)} ${product.satuan!.toLowerCase()}'
        : (product.satuan != null && product.satuan!.isNotEmpty)
            ? product.satuan!
            : product.kategori;

    final String distanceStr = formatDistance(product.jarakKm);

    final effectiveMargin = margin ??
        (width == double.infinity
            ? EdgeInsets.zero
            : const EdgeInsets.only(right: 12.0));

    return Container(
      width: width,
      margin: effectiveMargin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Container Gambar Produk + Badges
                _buildImageContainer(),
                const SizedBox(height: 8.0),

                // 2. Nama Produk (SizedBox fixed height 40.0, maxLines: 2)
                SizedBox(
                  height: 40.0,
                  child: Text(
                    product.nama,
                    style: GoogleFonts.outfit(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D2818),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2.0),

                // 3. Satuan / Varian Produk (Text abu-abu, maxLines: 1)
                Text(
                  sizeInfo,
                  style: GoogleFonts.outfit(
                    fontSize: 11.0,
                    color: const Color(0xFF6B6B6B),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // 4. Harga Produk (Tebal & Jelas, tanpa tombol +)
                Text(
                  formattedPrice,
                  style: GoogleFonts.outfit(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D2818),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6.0),

                // 5. Metadata Toko & Jarak (Baris Paling Bawah)
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: BrandAssets.buildStoreLogo(
                        product.namaToko,
                        size: 16,
                        borderRadius: 3,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Expanded(
                      child: Text(
                        product.namaToko,
                        style: GoogleFonts.outfit(
                          fontSize: 10.0,
                          color: const Color(0xFF6B6B6B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      ' · ',
                      style: GoogleFonts.outfit(
                        fontSize: 10.0,
                        color: const Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      distanceStr,
                      style: GoogleFonts.outfit(
                        fontSize: 10.0,
                        color: const Color(0xFF6B6B6B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Container gambar produk dengan background netral (#F8F9FA),
  /// badge "Best Value" di pojok kiri atas, dan ikon bookmark di kanan atas.
  Widget _buildImageContainer() {
    return Container(
      width: double.infinity,
      height: 98,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 0.8,
        ),
      ),
      child: Stack(
        children: [
          // Gambar Produk proporsional dengan BoxFit.contain
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: _buildProductDisplay(),
              ),
            ),
          ),

          // Badge "Best Value" di pojok kiri atas
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D2818), Color(0xFF2E6644)],
                ),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D2818).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'Best Value',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          // Ikon bookmark/favorite di pojok kanan atas
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 15,
                color: Color(0xFF2E6644),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDisplay() {
    final assetPath = BrandAssets.getProductAsset(product.nama, product.kategori);
    final resolvedUrl = BrandAssets.resolveImageUrl(product.fotoUrl);

    if (resolvedUrl != null) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            assetPath != null ? _buildAssetImage(assetPath) : _buildFallbackImage(),
      );
    }

    if (assetPath != null) {
      return _buildAssetImage(assetPath);
    }

    return _buildFallbackImage();
  }

  Widget _buildAssetImage(String assetPath) {
    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
    );
  }

  Widget _buildFallbackImage() {
    final style = _getProductCategoryStyle(product.kategori, product.nama);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.bgStart, style.bgEnd],
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: style.iconColor.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            style.icon,
            size: 24,
            color: style.iconColor,
          ),
        ),
      ),
    );
  }

  static _ProductCategoryStyle _getProductCategoryStyle(String category, String name) {
    final lowerName = name.toLowerCase();
    final lowerCat = category.toLowerCase();

    // 1. Makanan Instan / Mie
    if (lowerName.contains('mie') ||
        lowerName.contains('indomie') ||
        lowerName.contains('sedaap') ||
        lowerName.contains('sedap') ||
        lowerName.contains('ramen') ||
        lowerName.contains('noodle') ||
        lowerCat.contains('instan')) {
      return const _ProductCategoryStyle(
        icon: Icons.ramen_dining_rounded,
        badgeIcon: Icons.local_fire_department_rounded,
        shortTag: 'MIE INSTAN',
        iconColor: Color(0xFFEA580C),
        bgStart: Color(0xFFFFF7ED),
        bgEnd: Color(0xFFFFEDD5),
        borderColor: Color(0xFFFED7AA),
      );
    }

    // 2. Minyak Goreng
    if (lowerName.contains('minyak') ||
        lowerName.contains('oil') ||
        lowerName.contains('bimoli') ||
        lowerName.contains('sania') ||
        lowerName.contains('filma') ||
        lowerName.contains('tropical') ||
        lowerName.contains('fortune')) {
      return const _ProductCategoryStyle(
        icon: Icons.opacity_rounded,
        badgeIcon: Icons.verified_rounded,
        shortTag: 'MINYAK',
        iconColor: Color(0xFFD97706),
        bgStart: Color(0xFFFFFBEB),
        bgEnd: Color(0xFFFEF3C7),
        borderColor: Color(0xFFFDE68A),
      );
    }

    // 3. Susu & Olahan / Dairy
    if (lowerName.contains('susu') ||
        lowerName.contains('milk') ||
        lowerName.contains('ultra') ||
        lowerName.contains('dancow') ||
        lowerName.contains('keju') ||
        lowerName.contains('cheese') ||
        lowerName.contains('yogurt') ||
        lowerCat.contains('susu')) {
      return const _ProductCategoryStyle(
        icon: Icons.coffee_rounded,
        badgeIcon: Icons.eco_rounded,
        shortTag: 'SUSU & DAIRY',
        iconColor: Color(0xFF0284C7),
        bgStart: Color(0xFFF0F9FF),
        bgEnd: Color(0xFFE0F2FE),
        borderColor: Color(0xFFBAE6FD),
      );
    }

    // 4. Beras / Gula / Tepung / Makanan Pokok
    if (lowerName.contains('beras') ||
        lowerName.contains('rice') ||
        lowerName.contains('gula') ||
        lowerName.contains('tepung') ||
        lowerCat.contains('pokok')) {
      return const _ProductCategoryStyle(
        icon: Icons.grain_rounded,
        badgeIcon: Icons.stars_rounded,
        shortTag: 'SEMBAKO',
        iconColor: Color(0xFFB45309),
        bgStart: Color(0xFFFFFDF5),
        bgEnd: Color(0xFFFEF3C7),
        borderColor: Color(0xFFFDE68A),
      );
    }

    // 5. Telur
    if (lowerName.contains('telur') || lowerName.contains('egg')) {
      return const _ProductCategoryStyle(
        icon: Icons.egg_rounded,
        badgeIcon: Icons.thumb_up_rounded,
        shortTag: 'TELUR',
        iconColor: Color(0xFFCA8A04),
        bgStart: Color(0xFFFEFCE8),
        bgEnd: Color(0xFFFEF08A),
        borderColor: Color(0xFFFDE047),
      );
    }

    // 6. Teh / Kopi / Minuman
    if (lowerName.contains('kopi') ||
        lowerName.contains('coffee') ||
        lowerName.contains('teh') ||
        lowerName.contains('tea') ||
        lowerName.contains('jus') ||
        lowerName.contains('juice') ||
        lowerName.contains('air') ||
        lowerCat.contains('minuman')) {
      return const _ProductCategoryStyle(
        icon: Icons.emoji_food_beverage_rounded,
        badgeIcon: Icons.bolt_rounded,
        shortTag: 'MINUMAN',
        iconColor: Color(0xFF0D9488),
        bgStart: Color(0xFFF0FDFA),
        bgEnd: Color(0xFFCCFBF1),
        borderColor: Color(0xFF99F6E4),
      );
    }

    // 7. Camilan / Biskuit / Snack
    if (lowerName.contains('snack') ||
        lowerName.contains('biskuit') ||
        lowerName.contains('oreo') ||
        lowerName.contains('wafer') ||
        lowerName.contains('chitato') ||
        lowerName.contains('roti') ||
        lowerName.contains('cokelat') ||
        lowerCat.contains('camilan')) {
      return const _ProductCategoryStyle(
        icon: Icons.cookie_rounded,
        badgeIcon: Icons.celebration_rounded,
        shortTag: 'CAMILAN',
        iconColor: Color(0xFFDB2777),
        bgStart: Color(0xFFFDF2F8),
        bgEnd: Color(0xFFFCE7F3),
        borderColor: Color(0xFFFBCFE8),
      );
    }

    // 8. Bumbu & Saus
    if (lowerName.contains('kecap') ||
        lowerName.contains('saus') ||
        lowerName.contains('bumbu') ||
        lowerName.contains('garam') ||
        lowerName.contains('sambal') ||
        lowerCat.contains('bumbu')) {
      return const _ProductCategoryStyle(
        icon: Icons.soup_kitchen_rounded,
        badgeIcon: Icons.restaurant_rounded,
        shortTag: 'BUMBU',
        iconColor: Color(0xFFC2410C),
        bgStart: Color(0xFFFFF7ED),
        bgEnd: Color(0xFFFFEDD5),
        borderColor: Color(0xFFFED7AA),
      );
    }

    // 9. Perawatan Diri
    if (lowerName.contains('sabun') ||
        lowerName.contains('shampoo') ||
        lowerName.contains('odol') ||
        lowerName.contains('pasta gigi') ||
        lowerName.contains('body wash') ||
        lowerCat.contains('perawatan')) {
      return const _ProductCategoryStyle(
        icon: Icons.spa_rounded,
        badgeIcon: Icons.auto_awesome_rounded,
        shortTag: 'PERAWATAN',
        iconColor: Color(0xFF4F46E5),
        bgStart: Color(0xFFEEF2FF),
        bgEnd: Color(0xFFE0E7FF),
        borderColor: Color(0xFFC7D2FE),
      );
    }

    // 10. Rumah Tangga / Kebersihan
    if (lowerName.contains('deterjen') ||
        lowerName.contains('rinso') ||
        lowerName.contains('molto') ||
        lowerName.contains('pembersih') ||
        lowerCat.contains('rumah')) {
      return const _ProductCategoryStyle(
        icon: Icons.cleaning_services_rounded,
        badgeIcon: Icons.sanitizer_rounded,
        shortTag: 'KEBERSIHAN',
        iconColor: Color(0xFF0891B2),
        bgStart: Color(0xFFECFEFF),
        bgEnd: Color(0xFFCFFAFE),
        borderColor: Color(0xFFA5F3FC),
      );
    }

    // 11. Kesehatan
    if (lowerCat.contains('kesehatan') ||
        lowerName.contains('vitamin') ||
        lowerName.contains('obat') ||
        lowerName.contains('masker')) {
      return const _ProductCategoryStyle(
        icon: Icons.medication_rounded,
        badgeIcon: Icons.health_and_safety_rounded,
        shortTag: 'KESEHATAN',
        iconColor: Color(0xFFE11D48),
        bgStart: Color(0xFFFFF1F2),
        bgEnd: Color(0xFFFFE4E6),
        borderColor: Color(0xFFFECDD3),
      );
    }

    // 12. Bayi
    if (lowerCat.contains('bayi') ||
        lowerName.contains('popok') ||
        lowerName.contains('pampers')) {
      return const _ProductCategoryStyle(
        icon: Icons.child_care_rounded,
        badgeIcon: Icons.favorite_rounded,
        shortTag: 'BAYI',
        iconColor: Color(0xFF8B5CF6),
        bgStart: Color(0xFFF5F3FF),
        bgEnd: Color(0xFFEDE9FE),
        borderColor: Color(0xFFDDD6FE),
      );
    }

    // Default
    return const _ProductCategoryStyle(
      icon: Icons.shopping_basket_rounded,
      badgeIcon: Icons.local_offer_rounded,
      shortTag: 'PRODUK',
      iconColor: Color(0xFF059669),
      bgStart: Color(0xFFF0FDF4),
      bgEnd: Color(0xFFDCFCE7),
      borderColor: Color(0xFFA7F3D0),
    );
  }
}

class _ProductCategoryStyle {
  final IconData icon;
  final IconData badgeIcon;
  final String shortTag;
  final Color iconColor;
  final Color bgStart;
  final Color bgEnd;
  final Color borderColor;

  const _ProductCategoryStyle({
    required this.icon,
    required this.badgeIcon,
    required this.shortTag,
    required this.iconColor,
    required this.bgStart,
    required this.bgEnd,
    required this.borderColor,
  });
}
