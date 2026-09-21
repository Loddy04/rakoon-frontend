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

  @override
  Widget build(BuildContext context) {
    final String formattedPrice = formatRp(product.harga);
    final String sizeInfo = (product.ukuran != null && product.satuan != null)
        ? '${product.ukuran!.toStringAsFixed(product.ukuran! % 1 == 0 ? 0 : 1)} ${product.satuan!.toUpperCase()}'
        : product.kategori.toUpperCase();

    final String distanceStr = product.jarakKm != null
        ? '${product.jarakKm!.toStringAsFixed(1)} KM'
        : '0.8 KM';

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
                          product.updatedAt.toUpperCase(),
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
