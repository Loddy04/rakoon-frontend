import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/price_history_item.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';

class StoreHistoryListView extends StatelessWidget {
  final List<PriceHistoryItem> items;

  const StoreHistoryListView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort chronologically ascending to ensure later items represent the latest state
    final chronologicalItems = List<PriceHistoryItem>.from(items)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    // Group by storeId to get the latest price entry per store
    final Map<String, PriceHistoryItem> latestStorePrices = {};
    for (final item in chronologicalItems) {
      latestStorePrices[item.storeId] = item;
    }
    final List<PriceHistoryItem> uniqueItems = latestStorePrices.values.toList();

    // Sort by price ascending (cheapest first)
    uniqueItems.sort((a, b) => a.price.compareTo(b.price));

    // Determine the cheapest price and its count among unique stores
    double lowestPrice = 0.0;
    int lowestPriceCount = 0;
    if (uniqueItems.isNotEmpty) {
      lowestPrice = uniqueItems.map((e) => e.price).reduce((a, b) => a < b ? a : b);
      lowestPriceCount = uniqueItems.where((e) => e.price == lowestPrice).length;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.ink : AppColors.card,
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'TOKO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Text(
                  'HARGA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          // Table items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: uniqueItems.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF334155) : AppColors.line,
            ),
            itemBuilder: (context, index) {
              final item = uniqueItems[index];
              final isLowest = item.price == lowestPrice;
              final showTermurah = isLowest && lowestPriceCount == 1;
              final showHargaSama = isLowest && lowestPriceCount > 1;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            item.storeName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.paper
                                  : AppColors.ink,
                            ),
                          ),
                          if (showTermurah)
                            const StatusBadge(status: 'Termurah'),
                          if (showHargaSama)
                            const StatusBadge(status: 'Harga sama'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatRp(item.price),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isLowest
                            ? AppColors.accent
                            : (isDark ? AppColors.paper : AppColors.ink),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

