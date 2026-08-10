import 'package:flutter/material.dart';
import '../providers/price_history_notifier.dart';
import '../widgets/product_header_card.dart';
import '../widgets/store_history_list_item.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
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
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF059669),
                      ),
                    );
                  }

                  if (widget.notifier.isError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.notifier.errorMessage ??
                                  'Terjadi kesalahan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () =>
                                  widget.notifier.fetchPriceHistory(
                                    productId: widget.productId,
                                  ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (widget.notifier.isEmpty) {
                    return Center(
                      child: Text(
                        'Belum ada data riwayat harga',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    );
                  }

                  final response = widget.notifier.response;
                  if (response == null) {
                    return const SizedBox.shrink();
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
