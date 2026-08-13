import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';
import 'package:http/http.dart' as http;

class RecommendationScreen extends StatefulWidget {
  final String baseUrl;
  final List<RecommendationCandidate>? initialCandidates;
  final http.Client? httpClient;

  const RecommendationScreen({
    super.key,
    required this.baseUrl,
    this.initialCandidates,
    this.httpClient,
  });

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  RecommendationResponse? _response;

  late List<RecommendationCandidate> _candidates;

  @override
  void initState() {
    super.initState();
    // Use passed candidates if provided, otherwise default to mock candidates for dev testing
    if (widget.initialCandidates != null) {
      _candidates = widget.initialCandidates!;
    } else {
      _candidates = [
        RecommendationCandidate(
          productId: 'product-a',
          namaProduk: 'Ultra Milk 1L',
          harga: 20000,
          ukuran: 1000,
          satuan: 'ml',
          kategori: 'Susu & Olahan',
        ),
        RecommendationCandidate(
          productId: 'product-b',
          namaProduk: 'Indomilk 1L',
          harga: 18000,
          ukuran: 1000,
          satuan: 'ml',
          kategori: 'Susu & Olahan',
        ),
        RecommendationCandidate(
          productId: 'product-c',
          namaProduk: 'Aqua 600ml',
          harga: 5000,
          ukuran: 600,
          satuan: 'ml',
          kategori: 'Minuman',
        ),
        RecommendationCandidate(
          productId: 'product-d',
          namaProduk: 'Teh Botol 350ml',
          harga: 5000,
          ukuran: 350,
          satuan: 'ml',
          kategori: 'Minuman',
        ),
        RecommendationCandidate(
          productId: 'product-e',
          namaProduk: 'Rinso 800ml',
          harga: 15000,
          ukuran: 800,
          satuan: 'ml',
          kategori: 'Produk Rumah Tangga',
        ),
      ];
    }

    _fetchRecommendation();
  }

  Future<void> _fetchRecommendation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await RecommendationService.evaluateRecommendation(
        candidates: _candidates,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );

      setState(() {
        _response = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatRupiah(double amount) {
    return 'Rp ${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Value Recommendation', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRecommendation,
            tooltip: 'Hitung Ulang Rekomendasi',
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menghitung Nilai Ekonomi Terbaik...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          'Gagal Memuat Rekomendasi',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchRecommendation,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        )
                      ],
                    ),
                  ),
                )
              : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_response == null || _response!.categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Tidak ada produk valid yang dapat dibandingkan.'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Global Evaluated Summary Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: AppColors.accent, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Hasil Evaluasi Best Value',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_response!.totalValid} Produk (${_response!.categories.length} kat)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Render each Category section
          ..._response!.categories.map((categoryGroup) {
            return _buildCategorySection(context, categoryGroup, isDark);
          }),

          // Excluded Items (if any)
          if (_response!.excludedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              leading: const Icon(Icons.info_outline, color: AppColors.warning),
              title: Text(
                '${_response!.excludedItems.length} Produk Dikecualikan',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.warning),
              ),
              subtitle: const Text('Produk dengan data harga/ukuran tidak valid'),
              children: _response!.excludedItems.map((ex) {
                return ListTile(
                  dense: true,
                  title: Text(ex.namaProduk ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Alasan: ${ex.reason}'),
                  trailing: Text(
                    ex.harga != null && ex.harga! > 0 ? _formatRupiah(ex.harga!) : 'Harga null',
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    CategoryRecommendationGroup categoryGroup,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header Banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                categoryGroup.kategori,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.ink,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Render each Dimension Group in Category
          ...categoryGroup.dimensionGroups.map((dimGroup) {
            return _buildDimensionGroupSection(context, dimGroup, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildDimensionGroupSection(
    BuildContext context,
    DimensionRecommendationGroup dimGroup,
    bool isDark,
  ) {
    final bool isComparable = dimGroup.isComparable;
    final bestValue = dimGroup.bestValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(
          color: isComparable ? AppColors.accent.withValues(alpha: 0.4) : AppColors.line,
          width: isComparable ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dimension Label Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Kelompok Dimensi: ${dimGroup.dimensionLabel}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!isComparable)
                const StatusBadge(status: 'Single Item'),
            ],
          ),
          const SizedBox(height: 12),

          // 🏆 HERO WINNER CARD if Comparable
          if (isComparable && bestValue != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E3A8A), const Color(0xFF065F46)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFECFDF5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: AppColors.accent, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.emoji_events, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'BEST VALUE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge(status: 'Peringkat #1'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    bestValue.namaProduk,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.ink,
                        ),
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Text(
                        _formatRupiah(bestValue.harga),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '/ ${bestValue.ukuranOriginal} ${bestValue.satuanOriginal}',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      const Spacer(),
                      Text(
                        bestValue.unitPriceLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Explainable Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bestValue.explanation,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: isDark ? Colors.white70 : AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Single Item Warning Banner
          if (!isComparable) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dimGroup.message ?? 'Belum ada produk pembanding yang compatible.',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Ranked Items List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dimGroup.rankedItems.length,
            itemBuilder: (context, index) {
              final item = dimGroup.rankedItems[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  side: BorderSide(
                    color: item.isBestValue ? AppColors.accent : AppColors.line,
                    width: item.isBestValue ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Ranking Circle
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: item.isBestValue ? AppColors.accent : AppColors.card,
                        child: Text(
                          '#${item.rank}',
                          style: TextStyle(
                            color: item.isBestValue ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Product Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.namaProduk,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (item.isBestValue)
                                  const StatusBadge(status: 'Best Value'),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Text(
                              '${_formatRupiah(item.harga)} / ${item.ukuranOriginal} ${item.satuanOriginal}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Harga Satuan: ${item.unitPriceLabel}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: item.isBestValue ? AppColors.accent : AppColors.ink,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Text(
                              item.explanation,
                              style: TextStyle(
                                fontSize: 11,
                                color: item.isBestValue ? AppColors.accent : AppColors.muted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
