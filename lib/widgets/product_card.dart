import 'package:flutter/material.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/playful_card.dart';

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
        ? '${product.ukuran!.toStringAsFixed(product.ukuran! % 1 == 0 ? 0 : 1)} ${product.satuan!.toUpperCase()}'
        : product.kategori.toUpperCase();

    final String distanceStr = formatDistance(product.jarakKm);
    final String timeAgoStr = formatTimeAgo(product.updatedAt);

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: AppSpacing.s12),
      child: PlayfulCard(
        backgroundColor: AppColors.paper,
        border: Border.all(color: AppColors.graphite, width: 1.0),
        padding: const EdgeInsets.all(12.0),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Product Image / Photo
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
            Container(height: 1.0, color: AppColors.graphite),
            const SizedBox(height: 8),

            // 2. Product Name (Uppercase & Bold)
            Text(
              product.nama.toUpperCase(),
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: AppColors.graphite,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // Size / Category Subtitle
            Text(
              sizeInfo,
              style: AppTextStyles.caption.copyWith(
                fontSize: 9,
                color: AppColors.fog,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // 3. Price (Large & Bold)
            Text(
              formattedPrice,
              style: AppTextStyles.headingLg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.graphite,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // 4. Store Name
            Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 11,
                  color: AppColors.graphite,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    product.namaToko.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.graphite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),

            // 5. Distance & Update Time
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        size: 10,
                        color: AppColors.fog,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          distanceStr,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 8.5,
                            color: AppColors.fog,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        size: 10,
                        color: AppColors.fog,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          timeAgoStr,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 8.5,
                            color: AppColors.fog,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
