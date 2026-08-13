import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';

class BudgetResultScreen extends StatelessWidget {
  final BudgetRecommendResponse result;

  const BudgetResultScreen({
    super.key,
    required this.result,
  });

  String _formatRupiah(double amount) {
    final int val = amount.round();
    final isNegative = val < 0;
    final absVal = val.abs();
    final formatted = absVal.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    return '${isNegative ? "-" : ""}Rp $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasStore = result.recommendedStore != null;
    final bool isOverBudget = hasStore && result.remainingBudget < 0;
    final store = result.recommendedStore;

    Color heroBgColor = Colors.amber.shade50;
    Color heroBorderColor = AppColors.warning;
    String statusText = 'Tidak Ditemukan Toko';
    IconData statusIcon = Icons.warning_amber_rounded;

    if (hasStore) {
      if (isOverBudget) {
        heroBgColor = AppColors.errorSoft;
        heroBorderColor = AppColors.error;
        statusText = 'Kekurangan Budget';
        statusIcon = Icons.error_outline;
      } else {
        heroBgColor = AppColors.accentSoft;
        heroBorderColor = AppColors.accent;
        statusText = 'Rekomendasi Utama';
        statusIcon = Icons.emoji_events;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rekomendasi Belanja'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HERO RECOMMENDATION CARD
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  side: BorderSide(
                    color: heroBorderColor,
                    width: 1.5,
                  ),
                ),
                color: heroBgColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatusBadge(
                            status: statusText,
                            icon: statusIcon,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Budget: ${_formatRupiah(result.budget)}',
                              textAlign: Alignment.centerRight == Alignment.centerRight ? TextAlign.end : TextAlign.start,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        label: 'Toko utama: ${hasStore ? store!.nama : "Tidak Ditemukan"}',
                        child: Text(
                          hasStore ? store!.nama : 'Toko Tidak Ditemukan',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (hasStore) ...[
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.line),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            Semantics(
                              label: 'Total biaya: ${_formatRupiah(result.totalCost)}',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Belanja:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatRupiah(result.totalCost),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              label: isOverBudget
                                  ? 'Kekurangan budget sebesar: ${_formatRupiah(-result.remainingBudget)}'
                                  : 'Sisa budget sebesar: ${_formatRupiah(result.remainingBudget)}',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOverBudget ? 'Kekurangan:' : 'Sisa Budget:',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOverBudget
                                        ? _formatRupiah(-result.remainingBudget)
                                        : _formatRupiah(result.remainingBudget),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isOverBudget ? AppColors.error : Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. EXPLANATION CARD
              Card(
                elevation: 1,
                color: AppColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          result.explanation,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. STORE LOCATION INFO CARD
              if (hasStore) ...[
                const Text(
                  '📍 Informasi Lokasi Toko',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 1,
                  color: AppColors.paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store!.nama,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                store.alamat ?? 'Alamat tidak tersedia di database',
                                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                        if (store.lat != null && store.lng != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.my_location, size: 16, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text(
                                'Koordinat: ${store.lat}, ${store.lng}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. RINCIAN ITEM BELANJA
              if (hasStore && result.items.isNotEmpty) ...[
                const Text(
                  '🛒 Rincian Barang Belanja',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: result.items.length,
                  itemBuilder: (context, index) {
                    final item = result.items[index];
                    return Card(
                      color: AppColors.paper,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.namaProduk,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.qty} x ${_formatRupiah(item.hargaSatuan)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatRupiah(item.subtotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],

              // 5. STATUS KETERSEDIAAN BARANG (for no full match)
              if (!hasStore && result.productAvailabilities != null && result.productAvailabilities!.isNotEmpty) ...[
                const Text(
                  '📋 Status Ketersediaan Barang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: result.productAvailabilities!.length,
                  itemBuilder: (context, index) {
                    final avail = result.productAvailabilities![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        side: BorderSide(
                          color: avail.isAvailable ? AppColors.line : AppColors.error,
                        ),
                      ),
                      color: avail.isAvailable ? AppColors.paper : AppColors.errorSoft,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              avail.isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
                              color: avail.isAvailable ? AppColors.accent : AppColors.error,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    avail.namaProduk,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    avail.isAvailable
                                        ? 'Tersedia terendah di ${avail.tokoTerendah}'
                                        : 'Tidak tersedia di toko mana pun',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (avail.isAvailable)
                              Text(
                                _formatRupiah(avail.hargaTerendah ?? 0.0),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.accent,
                                ),
                              )
                            else
                              const Text(
                                'Tidak Tersedia',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],

              // 6. ALTERNATIF TOKO
              if (result.storeAlternatives != null && result.storeAlternatives!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '🏪 Alternatif Toko Lainnya',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: result.storeAlternatives!.length,
                  itemBuilder: (context, index) {
                    final alt = result.storeAlternatives![index];
                    final diff = alt.totalCost - result.totalCost;
                    final diffStr = diff >= 0 ? '+${_formatRupiah(diff)}' : _formatRupiah(diff);
                    return Card(
                      color: AppColors.paper,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alt.storeInfo.nama,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sisa Budget: ${_formatRupiah(alt.remainingBudget)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatRupiah(alt.totalCost),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  diffStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: diff >= 0 ? AppColors.error : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
