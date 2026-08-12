import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';

class RecommendationScreen extends StatefulWidget {
  final String baseUrl;
  final List<RecommendationCandidate>? initialCandidates;
  final String category;

  const RecommendationScreen({
    super.key,
    required this.baseUrl,
    this.initialCandidates,
    this.category = 'Susu UHT',
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
          namaProduk: 'Susu UHT Brand A',
          harga: 20000,
          ukuran: 200,
          satuan: 'ml',
        ),
        RecommendationCandidate(
          productId: 'product-b',
          namaProduk: 'Susu UHT Brand B',
          harga: 25000,
          ukuran: 350,
          satuan: 'ml',
        ),
        RecommendationCandidate(
          productId: 'product-c',
          namaProduk: 'Susu UHT Brand C (Hemat Pack)',
          harga: 30000,
          ukuran: 0.5,
          satuan: 'liter',
        ),
        RecommendationCandidate(
          productId: 'product-d',
          namaProduk: 'Susu UHT Brand D (Harga Buram)',
          harga: 0,
          ukuran: 250,
          satuan: 'ml',
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
        category: widget.category,
        baseUrl: widget.baseUrl,
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
    if (_response == null || _response!.rankedItems.isEmpty) {
      return const Center(
        child: Text('Tidak ada produk valid yang dapat dibandingkan.'),
      );
    }

    final bestValue = _response!.bestValue!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🏆 HERO WINNER CARD (BEST VALUE)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A8A), const Color(0xFF065F46)]
                    : [const Color(0xFFEFF6FF), const Color(0xFFECFDF5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: AppColors.accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.emoji_events, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'BEST VALUE RECOMMENDATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(status: 'Peringkat #1'),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  bestValue.namaProduk,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.ink,
                      ),
                ),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatRupiah(bestValue.harga),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ ${bestValue.ukuranOriginal} ${bestValue.satuanOriginal}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Harga per Unit Highlight
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calculate_outlined, color: AppColors.accent, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Harga Satuan: ',
                        style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        bestValue.unitPriceLabel,
                        style: TextStyle(
                          color: Colors.teal.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Explainable Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bestValue.explanation,
                          style: TextStyle(
                            fontSize: 13,
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
          const SizedBox(height: 24),

          // 📊 DAFTAR PERINGKAT LENGKAP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Perbandingan Nilai Ekonomi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(
                  '${_response!.totalValid} Produk Dibandingkan',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.card,
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _response!.rankedItems.length,
            itemBuilder: (context, index) {
              final item = _response!.rankedItems[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  side: BorderSide(
                    color: item.isBestValue ? AppColors.accent : AppColors.line,
                    width: item.isBestValue ? 2.0 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Ranking Circle
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: item.isBestValue ? AppColors.accent : AppColors.card,
                        child: Text(
                          '#${item.rank}',
                          style: TextStyle(
                            color: item.isBestValue ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Detail Produk
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
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (item.isBestValue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '🏆 Best Value',
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Text(
                              '${_formatRupiah(item.harga)} / ${item.ukuranOriginal} ${item.satuanOriginal}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Harga Satuan: ${item.unitPriceLabel}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: item.isBestValue ? AppColors.accent : AppColors.ink,
                                    fontSize: 13,
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
          const SizedBox(height: 16),

          // ⚠️ EXCLUDED ITEMS (JIKA ADA)
          if (_response!.excludedItems.isNotEmpty) ...[
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
}
