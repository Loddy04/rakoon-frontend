import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/price_history_item.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';

class ProductHeaderCard extends StatelessWidget {
  final String productName;
  final List<PriceHistoryItem> items;

  const ProductHeaderCard({
    super.key,
    required this.productName,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final prices = items.map((e) => e.price).toList();
    final double currentPrice = prices.isNotEmpty ? prices.last : 0.0;
    final double lowestPrice = prices.isNotEmpty
        ? prices.reduce((a, b) => a < b ? a : b)
        : 0.0;
    final double highestPrice = prices.isNotEmpty
        ? prices.reduce((a, b) => a > b ? a : b)
        : 0.0;

    // Calculate trend from valid prices chronologically
    final validItems = items.where((e) => e.price > 0).toList();
    validItems.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    String trendStatus = 'Belum cukup data';
    IconData trendIcon = Icons.info_outline;

    if (validItems.length >= 2) {
      final double oldestPrice = validItems.first.price;
      final double latestPrice = validItems.last.price;

      if (latestPrice > oldestPrice) {
        trendStatus = 'Harga naik';
        trendIcon = Icons.trending_up;
      } else if (latestPrice < oldestPrice) {
        trendStatus = 'Harga turun';
        trendIcon = Icons.trending_down;
      } else {
        trendStatus = 'Harga stabil';
        trendIcon = Icons.trending_flat;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produk',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            productName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                formatRp(currentPrice),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              StatusBadge(status: trendStatus, icon: trendIcon),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Terendah ',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    TextSpan(
                      text: formatRp(lowestPrice),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tertinggi ',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    TextSpan(
                      text: formatRp(highestPrice),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
