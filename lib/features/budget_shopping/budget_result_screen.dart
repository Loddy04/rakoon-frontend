import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class BudgetResultScreen extends StatelessWidget {
  final BudgetRecommendResponse result;

  const BudgetResultScreen({
    super.key,
    required this.result,
  });

  String _formatRupiah(double amount) {
    final int val = amount.round();
    return 'Rp ${val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasStore = result.recommendedStore != null;
    final store = result.recommendedStore;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekomendasi Belanja'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HERO RECOMMENDATION CARD
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.l),
                side: BorderSide(
                  color: hasStore ? AppColors.accent : AppColors.warning,
                  width: 1.5,
                ),
              ),
              color: hasStore ? AppColors.accentSoft : Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasStore ? AppColors.accent : AppColors.warning,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasStore ? Icons.emoji_events : Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hasStore ? '100% Full Match' : 'Tidak Ditemukan Toko',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Budget: ${_formatRupiah(result.budget)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasStore ? store!.nama : 'Toko Tidak Ditemukan',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    if (hasStore) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Belanja:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Sisa Budget:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              Text(
                                _formatRupiah(result.remainingBudget),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: result.remainingBudget >= 0 ? Colors.green.shade700 : AppColors.error,
                                ),
                              ),
                            ],
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

            // 3. STORE LOCATION INFO CARD (TEXT ONLY - NO MAPS SDK)
            if (hasStore) ...[
              const Text(
                '📍 Informasi Lokasi Toko',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
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
            if (result.items.isNotEmpty) ...[
              const Text(
                '🛒 Rincian Barang Belanja',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: result.items.length,
                itemBuilder: (context, index) {
                  final item = result.items[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: ListTile(
                      title: Text(
                        item.namaProduk,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${item.qty} x ${_formatRupiah(item.hargaSatuan)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      trailing: Text(
                        _formatRupiah(item.subtotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
