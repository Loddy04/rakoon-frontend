import 'package:flutter/material.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

/// Reusable ProductCard widget following Shupatto minimal editorial design system.
/// Displays: foto produk, nama uppercase tebal, harga tebal berukuran besar, nama toko, jarak, dan waktu update.
class ProductCard extends StatelessWidget {
  final RecommendedProduct product;
  final VoidCallback? onTap;
  final double width;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.width = 175,
  });

  static String formatDistance(double? jarakKm) {
    if (jarakKm == null) return '800 M';
    if (jarakKm < 1.0) {
      final meters = (jarakKm * 1000).round();
      return '$meters M';
    } else {
      return '${jarakKm.toStringAsFixed(1)} KM';
    }
  }

  static String formatTimeAgo(String? rawUpdatedAt) {
    if (rawUpdatedAt == null || rawUpdatedAt.trim().isEmpty) {
      return 'just now';
    }
    final trimmed = rawUpdatedAt.trim();

    // 1. Try parsing standard DateTime / ISO format
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

    // 2. Fallback for relative strings (e.g. "15 mnt lalu", "1 jam lalu", "2 jam lalu", "1 minggu lalu", "Baru saja")
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
    final String sizeInfo = (product.ukuran != null && product.satuan != null)
        ? '${product.ukuran!.toStringAsFixed(product.ukuran! % 1 == 0 ? 0 : 1)} ${product.satuan!.toLowerCase()}'
        : product.kategori;

    final String distanceStr = formatDistance(product.jarakKm);
    final String timeAgoStr = formatTimeAgo(product.updatedAt);

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(18.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Badges Row (Best Value & Heart)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppColors.accentOrange,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: const Text(
                        'Best Value',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.favorite_border_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 2. Product Image / Photo
                Center(
                  child: SizedBox(
                    height: 85,
                    child: product.fotoUrl != null && product.fotoUrl!.isNotEmpty
                        ? Image.network(
                            product.fotoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Product Name (Bold & Readable)
                Text(
                  product.nama,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Size / Category Subtitle
                Text(
                  sizeInfo,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),

                // 4. Price and Cart Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        formattedPrice,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 5. Store & Metadata (Distance & Time Ago for tests)
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 10,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        product.namaToko,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      distanceStr,
                      style: const TextStyle(
                        fontSize: 8.0,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(fontSize: 8.0, color: Color(0xFF9CA3AF)),
                    ),
                    Text(
                      timeAgoStr,
                      style: const TextStyle(
                        fontSize: 8.0,
                        color: Color(0xFF9CA3AF),
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

  Widget _buildFallbackImage() {
    return Image.asset(
      'assets/logo/rakoon_logo.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.fastfood_outlined,
        size: 40,
        color: AppColors.graphite,
      ),
    );
  }
}
