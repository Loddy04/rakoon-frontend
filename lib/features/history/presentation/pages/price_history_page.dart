import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import '../providers/price_history_notifier.dart';
import '../widgets/product_header_card.dart';
import '../widgets/store_history_list_item.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/price_chart.dart';

class PriceHistoryPage extends StatefulWidget {
  final PriceHistoryNotifier notifier;
  final dynamic productId;
  final VoidCallback? onBack;

  const PriceHistoryPage({
    super.key,
    required this.notifier,
    required this.productId,
    this.onBack,
  });

  @override
  State<PriceHistoryPage> createState() => _PriceHistoryPageState();
}

class _PriceHistoryPageState extends State<PriceHistoryPage> {
  List<Map<String, String>> _availableStores = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.notifier.status == PriceHistoryStatus.initial) {
        widget.notifier.fetchPriceHistory(productId: widget.productId);
      }
    });
  }

  @override
  void dispose() {
    widget.notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  InkWell(
                    onTap:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Riwayat Harga',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            // Body Content listening to state
            Expanded(
              child: AnimatedBuilder(
                animation: widget.notifier,
                builder: (context, _) {
                  if (widget.notifier.isLoading) {
                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShimmerPlaceholder(
                            width: double.infinity,
                            height: 120,
                            borderRadius: 16,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: const [
                              ShimmerPlaceholder(
                                width: 60,
                                height: 32,
                                borderRadius: 16,
                              ),
                              SizedBox(width: 8),
                              ShimmerPlaceholder(
                                width: 60,
                                height: 32,
                                borderRadius: 16,
                              ),
                              SizedBox(width: 8),
                              ShimmerPlaceholder(
                                width: 60,
                                height: 32,
                                borderRadius: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const ShimmerPlaceholder(
                            width: double.infinity,
                            height: 172,
                            borderRadius: 16,
                          ),
                          const SizedBox(height: 24),
                          const ShimmerPlaceholder(
                            width: 140,
                            height: 16,
                            borderRadius: 4,
                          ),
                          const SizedBox(height: 12),
                          const ShimmerPlaceholder(
                            width: double.infinity,
                            height: 80,
                            borderRadius: 12,
                          ),
                          const SizedBox(height: 8),
                          const ShimmerPlaceholder(
                            width: double.infinity,
                            height: 80,
                            borderRadius: 12,
                          ),
                        ],
                      ),
                    );
                  }

                  if (widget.notifier.isError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.red.shade100,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal Memuat Data',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.notifier.errorMessage ??
                                    'Terjadi kesalahan eksternal.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    widget.notifier.fetchPriceHistory(
                                      productId: widget.productId,
                                    ),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Coba Lagi'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (widget.notifier.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.analytics_outlined,
                                size: 64,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Wah, Belum Ada Riwayat Harga',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Riwayat perubahan harga untuk produk ini belum tercatat pada server aplikasi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Kembali'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF059669),
                                side: const BorderSide(
                                  color: Color(0xFF059669),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final response = widget.notifier.response;
                  if (response == null) {
                    return const SizedBox.shrink();
                  }

                  // Safely update available store filters when store filter is cleared / showing all
                  if (widget.notifier.selectedStoreId == null && response.items.isNotEmpty) {
                    final seen = <String>{};
                    final List<Map<String, String>> stores = [];
                    for (final item in response.items) {
                      if (!seen.contains(item.storeId)) {
                        seen.add(item.storeId);
                        stores.add({'id': item.storeId, 'name': item.storeName});
                      }
                    }
                    stores.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

                    bool hasChanged = _availableStores.length != stores.length;
                    if (!hasChanged) {
                      for (int i = 0; i < stores.length; i++) {
                        if (_availableStores[i]['id'] != stores[i]['id']) {
                          hasChanged = true;
                          break;
                        }
                      }
                    }

                    if (hasChanged) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _availableStores = stores;
                          });
                        }
                      });
                    }
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Header Card
                        ProductHeaderCard(
                          productName: response.productName,
                          items: response.items,
                        ),
                        const SizedBox(height: 16),
                        // Date Range Selector (Wrapped to prevent overflow on small viewports)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: DateRangeSelector(
                            selectedRange: widget.notifier.selectedRange,
                            onRangeSelected: (range) =>
                                widget.notifier.setRange(widget.productId, range),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Store Filter Control
                        StoreFilterSelector(
                          selectedStoreId: widget.notifier.selectedStoreId,
                          stores: _availableStores,
                          onStoreSelected: (storeId) =>
                              widget.notifier.setStoreId(widget.productId, storeId),
                        ),
                        const SizedBox(height: 12),
                        // Price Chart
                        PriceChart(trendPoints: response.trend),
                        const SizedBox(height: 24),
                        // Store Comparison Title
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Perbandingan Toko',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        // Store History List View
                        StoreHistoryListView(items: response.items),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.65).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class StoreFilterSelector extends StatelessWidget {
  final dynamic selectedStoreId;
  final List<Map<String, String>> stores;
  final Function(String?) onStoreSelected;

  const StoreFilterSelector({
    super.key,
    required this.selectedStoreId,
    required this.stores,
    required this.onStoreSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip(
            context,
            label: 'Semua Toko',
            isSelected: selectedStoreId == null,
            onTap: () => onStoreSelected(null),
            isDark: isDark,
          ),
          ...stores.map((s) {
            final isSelected = selectedStoreId == s['id'];
            return _buildChip(
              context,
              label: s['name'] ?? 'Toko',
              isSelected: isSelected,
              onTap: () => onStoreSelected(s['id']),
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}
