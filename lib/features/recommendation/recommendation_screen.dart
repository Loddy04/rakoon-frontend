import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';

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
    _candidates = widget.initialCandidates ?? [];
    if (_candidates.isNotEmpty) {
      _fetchRecommendation();
    } else {
      _isLoading = false;
    }
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

      if (!mounted) return;
      setState(() {
        _response = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatRupiah(double amount) {
    return formatRp(amount);
  }

  String _formatUkuran(double ukuran, String satuan) {
    final formattedNum = ukuran % 1 == 0 ? ukuran.toInt().toString() : ukuran.toString();
    return '$formattedNum $satuan'.trim();
  }

  Widget _buildDiffBadge(double diffPct, {bool isSingle = false}) {
    if (isSingle) {
      return const StatusBadge(status: 'Single Item');
    }
    if (diffPct.abs() < 0.05) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Harga Setara',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4B5563),
          ),
        ),
      );
    }

    final diffString = diffPct.toStringAsFixed(diffPct % 1 == 0 ? 0 : 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFFDC2626)),
          const SizedBox(width: 2),
          Text(
            '+$diffString%',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0D2818)),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analisis Best Value',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D2818),
          ),
        ),
        centerTitle: false,
        actions: const [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE8E4DC), height: 1.0),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Color(0xFF0D2818),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Menghitung Nilai Ekonomi Terbaik...',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D2818),
                      ),
                    ),
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
                          const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFDC2626)),
                          const SizedBox(height: 16),
                          Text(
                            'Gagal Memuat Rekomendasi',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D2818),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: const Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _fetchRecommendation,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text('Coba Lagi', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D2818),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_response == null || _response!.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF059669), size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada produk valid yang dapat dibandingkan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Info Ringkas
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.track_changes_rounded, color: Color(0xFF059669), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nilai ekonomi dihitung berdasarkan perbandingan harga per satuan ukuran riil produk.',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF065F46),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Render each Category section
          ..._response!.categories.map((categoryGroup) {
            return _buildCategorySection(context, categoryGroup);
          }),

          // Excluded Items (if any)
          if (_response!.excludedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8E4DC)),
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
                title: Text(
                  '${_response!.excludedItems.length} Produk Dikecualikan',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFFB45309)),
                ),
                subtitle: Text(
                  'Produk dengan data harga/ukuran tidak valid',
                  style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280)),
                ),
                children: _response!.excludedItems.map((ex) {
                  return ListTile(
                    dense: true,
                    title: Text(ex.namaProduk ?? 'Tanpa Nama', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text('Alasan: ${ex.reason}', style: GoogleFonts.outfit(fontSize: 11)),
                    trailing: Text(
                      ex.harga != null && ex.harga! > 0 ? _formatRupiah(ex.harga!) : 'Harga null',
                      style: GoogleFonts.outfit(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    CategoryRecommendationGroup categoryGroup,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2818),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  categoryGroup.kategori,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D2818),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Render each Dimension Group in Category
          ...categoryGroup.dimensionGroups.map((dimGroup) {
            return _buildDimensionGroupSection(context, dimGroup);
          }),
        ],
      ),
    );
  }

  Widget _buildDimensionGroupSection(
    BuildContext context,
    DimensionRecommendationGroup dimGroup,
  ) {
    final bool isComparable = dimGroup.isComparable;
    final bestValue = dimGroup.bestValue;
    final double bestUnitPrice = bestValue?.hargaPerUnit ??
        (dimGroup.rankedItems.isNotEmpty ? dimGroup.rankedItems.first.hargaPerUnit : 0.0);

    // Filter items to show: if bestValue exists and comparable, exclude #1 from the list below to avoid duplication
    final List<RankedProductItem> itemsToShow = (isComparable && bestValue != null)
        ? dimGroup.rankedItems.where((it) => it.productId != bestValue.productId).toList()
        : dimGroup.rankedItems;

    // Calculate dynamic savings text for Winner card
    String savingsText;
    if (itemsToShow.isNotEmpty && bestValue != null) {
      final runnerUp = itemsToShow.first;
      final double runnerUpDiff = bestUnitPrice > 0
          ? ((runnerUp.hargaPerUnit - bestUnitPrice) / bestUnitPrice) * 100
          : 0.0;

      if (runnerUpDiff.abs() < 0.05) {
        savingsText = 'Nilai ekonomi setara dengan pilihan lain dalam kelompok ini.';
      } else {
        final pctString = runnerUpDiff.toStringAsFixed(runnerUpDiff % 1 == 0 ? 0 : 1);
        savingsText = 'Lebih hemat $pctString% dibanding pilihan peringkat #2 (${runnerUp.namaProduk})';
      }
    } else {
      savingsText = 'Nilai ekonomi terbaik untuk produk ini.';
    }

    // Dynamic insight explanation
    String insightText = bestValue?.explanation ?? '';
    if (itemsToShow.isNotEmpty && bestValue != null) {
      final runnerUp = itemsToShow.first;
      final double runnerUpDiff = bestUnitPrice > 0
          ? ((runnerUp.hargaPerUnit - bestUnitPrice) / bestUnitPrice) * 100
          : 0.0;
      if (runnerUpDiff.abs() < 0.05 || insightText.contains('lebih hemat 0.0%') || insightText.contains('lebih hemat 0%')) {
        insightText = 'Produk ini dan ${runnerUp.namaProduk} memiliki harga per ${bestValue.baseUnit} terendah yang setara (${bestValue.unitPriceLabel}). Keduanya menawarkan nilai ekonomi terbaik.';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Item or Non-comparable message
          if (!isComparable) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E4DC)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Kelompok: ${dimGroup.dimensionLabel}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D2818),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const StatusBadge(status: 'Single Item'),
                ],
              ),
            ),
          ],

          // 🏆 1. BEST VALUE WINNER CARD
          if (isComparable && bestValue != null) ...[
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFBEB), Colors.white],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold Winner Ribbon Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 14),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Best Value',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  ' · WINNER',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Size Pill (Ukuran & Satuan Riil)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatUkuran(bestValue.ukuranOriginal, bestValue.satuanOriginal),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Product Name
                        Text(
                          bestValue.namaProduk,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: const Color(0xFF0D2818),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Price, Unit Price, and Paling Hemat badge in Wrap
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              _formatRupiah(bestValue.harga),
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF059669),
                              ),
                            ),
                            Text(
                              bestValue.unitPriceLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Paling Hemat',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF059669),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Savings Callout Box (Dynamic based on real data)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.monetization_on_rounded, color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  savingsText,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. OTHER RANKED ITEMS LIST (Bebas duplikasi produk #1)
          if (itemsToShow.isNotEmpty) ...[
            if (isComparable && bestValue != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Text(
                  'Perbandingan Pilihan Lainnya',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemsToShow.length,
              itemBuilder: (context, index) {
                final item = itemsToShow[index];
                final double diffPct = bestUnitPrice > 0
                    ? ((item.hargaPerUnit - bestUnitPrice) / bestUnitPrice) * 100
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE8E4DC),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Medal Circle
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: item.rank == 2 ? const Color(0xFFE5E7EB) : const Color(0xFFFED7AA),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.rank == 2 ? const Color(0xFF9CA3AF) : const Color(0xFFF97316),
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${item.rank}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: item.rank == 2 ? const Color(0xFF374151) : const Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Product Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatUkuran(item.ukuranOriginal, item.satuanOriginal),
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.namaProduk,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: const Color(0xFF0D2818),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  _formatRupiah(item.harga),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0D2818),
                                  ),
                                ),
                                Text(
                                  item.unitPriceLabel,
                                  style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Difference Badge: "Harga Setara" vs "+X%"
                      _buildDiffBadge(diffPct, isSingle: !isComparable),
                    ],
                  ),
                );
              },
            ),
          ],

          // 3. "Insight dari Rakoon" Card
          if (bestValue != null && insightText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insight dari Rakoon',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          insightText,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: const Color(0xFF78350F),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
