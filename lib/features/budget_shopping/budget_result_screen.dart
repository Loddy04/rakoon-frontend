import 'package:flutter/material.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';

class BudgetResultScreen extends StatelessWidget {
  final BudgetRecommendResponse result;

  const BudgetResultScreen({
    super.key,
    required this.result,
  });

  String _formatRupiah(double amount) {
    if (amount < 0) {
      return '-${formatRp(amount.abs())}';
    }
    return formatRp(amount);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasStore = result.recommendedStore != null;
    final bool isOverBudget = hasStore && result.remainingBudget < 0;
    final store = result.recommendedStore;

    String statusText = 'Tidak Ditemukan Toko';
    IconData statusIcon = Icons.warning_amber_rounded;

    if (hasStore) {
      if (isOverBudget) {
        statusText = 'Kekurangan Budget';
        statusIcon = Icons.error_outline;
      } else {
        statusText = 'Rekomendasi Utama';
        statusIcon = Icons.emoji_events;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Rekomendasi Belanja',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFF3F4F6), height: 1.0),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HERO RECOMMENDATION CARD
              Container(
                decoration: BoxDecoration(
                  color: isOverBudget
                      ? const Color(0xFFFEF2F2)
                      : (hasStore ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOverBudget
                        ? const Color(0xFFFCA5A5)
                        : (hasStore ? const Color(0xFF6EE7B7) : const Color(0xFFFCD34D)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
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
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (hasStore) ...[
                            BrandAssets.buildStoreLogo(store!.nama, size: 44, borderRadius: 12),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Semantics(
                              label: 'Toko utama: ${hasStore ? store!.nama : "Tidak Ditemukan"}',
                              child: Text(
                                hasStore ? store!.nama : 'Toko Tidak Ditemukan',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasStore) ...[
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            Semantics(
                              label: 'Total biaya: ${_formatRupiah(result.totalCost)}',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Belanja:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatRupiah(result.totalCost),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF059669),
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
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOverBudget
                                        ? _formatRupiah(-result.remainingBudget)
                                        : _formatRupiah(result.remainingBudget),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF059669),
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
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          result.explanation,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF374151),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BrandAssets.buildStoreLogo(store!.nama, size: 36, borderRadius: 10),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                store.nama,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF111827)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF6B7280)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                store.alamat ?? 'Alamat tidak tersedia di database',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                              ),
                            ),
                          ],
                        ),
                        if (store.lat != null && store.lng != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Koordinat: ${store.lat}, ${store.lng}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF4B5563),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: result.items.length,
                  itemBuilder: (context, index) {
                    final item = result.items[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF7F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE8E4DC)),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: BrandAssets.getProductAsset(item.namaProduk) != null
                                  ? Image.asset(BrandAssets.getProductAsset(item.namaProduk)!, fit: BoxFit.contain)
                                  : const Icon(Icons.inventory_2_outlined, color: Color(0xFF059669), size: 20),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.namaProduk,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.qty} x ${_formatRupiah(item.hargaSatuan)}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatRupiah(item.subtotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF059669),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: result.productAvailabilities!.length,
                  itemBuilder: (context, index) {
                    final avail = result.productAvailabilities![index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: avail.isAvailable ? Colors.white : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: avail.isAvailable ? const Color(0xFFE5E7EB) : const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF7F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE8E4DC)),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: BrandAssets.getProductAsset(avail.namaProduk) != null
                                  ? Image.asset(BrandAssets.getProductAsset(avail.namaProduk)!, fit: BoxFit.contain)
                                  : const Icon(Icons.inventory_2_outlined, color: Color(0xFF059669), size: 18),
                            ),
                            Icon(
                              avail.isAvailable ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                              color: avail.isAvailable ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    avail.namaProduk,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    avail.isAvailable
                                        ? 'Tersedia terendah di ${avail.tokoTerendah}'
                                        : 'Tidak tersedia di toko mana pun',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (avail.isAvailable)
                              Text(
                                _formatRupiah(avail.hargaTerendah ?? 0.0),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF059669),
                                ),
                              )
                            else
                              const Text(
                                'Tidak Tersedia',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Color(0xFFDC2626),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
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
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrandAssets.buildStoreLogo(alt.storeInfo.nama, size: 36, borderRadius: 10),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alt.storeInfo.nama,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sisa Budget: ${_formatRupiah(alt.remainingBudget)}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  diffStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: diff >= 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
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
