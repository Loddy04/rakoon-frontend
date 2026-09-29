import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';
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

  Widget _buildProductThumbnail(String productName, {double size = 68}) {
    final assetPath = BrandAssets.getProductAsset(productName);
    if (assetPath != null) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E4DC)),
        ),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(size),
        ),
      );
    }
    return _buildFallbackThumbnail(size);
  }

  Widget _buildFallbackThumbnail(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: const Color(0xFF059669),
          size: size * 0.45,
        ),
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
        leading: const BackButton(color: Color(0xFF0D2818)),
        title: Text(
          'Best Value Recommendation',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D2818),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0D2818), size: 22),
            onPressed: _fetchRecommendation,
            tooltip: 'Hitung Ulang Rekomendasi',
          ),
        ],
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
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0D2818)),
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
                            style: GoogleFonts.dmSerifDisplay(fontSize: 18, fontWeight: FontWeight.bold),
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

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mascot Brand Header (Ref UI 3)
                Row(
                  children: [
                    Image.asset(
                      BrandAssets.rakoonLogo,
                      height: 28,
                      errorBuilder: (c, e, s) => const Icon(Icons.shopping_basket_rounded, color: Color(0xFF059669), size: 24),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rakoon',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: const Color(0xFF0D2818),
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Belanja Lebih Cerdas',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Header Titles (Ref UI 3)
                Text(
                  'Rekomendasi Nilai Terbaik',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D2818),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Dihitung berdasarkan harga per gram/ml produk sejenis di rak',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 14),

                // Green Info Banner (Ref UI 3)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(18),
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
                          'Produk ini memiliki beberapa pilihan kemasan. Kami urutkan dari nilai terbaik berdasarkan harga per ml.',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF065F46),
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Render each Category section
                ..._response!.categories.map((categoryGroup) {
                  return _buildCategorySection(context, categoryGroup);
                }),

                // "Hitung untuk Produk Lain" Banner (Ref UI 3)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.calculate_outlined, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hitung untuk Produk Lain',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0D2818),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bandingkan ukuran dan kemasan produk sejenis',
                              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF059669)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Pilih Produk',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF059669)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Excluded Items (if any)
                if (_response!.excludedItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Sticky Bottom CTA Button (Ref UI 3)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFE8E4DC), width: 1.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: InteractiveScale(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pilihan Best Value ditambahkan ke daftar belanja!', style: GoogleFonts.outfit()),
                  backgroundColor: const Color(0xFF0D2818),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D2818), Color(0xFF2E6644)],
                ),
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D2818).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_cart_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Gunakan Pilihan Ini',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Tambah ke daftar belanja Anda',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
              Text(
                categoryGroup.kategori,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D2818),
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DC)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kelompok: ${dimGroup.dimensionLabel}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D2818),
                    ),
                  ),
                  const StatusBadge(status: 'Single Item'),
                ],
              ),
            ),
          ],

          // 🏆 1. BEST VALUE WINNER CARD (Ref UI 3)
          if (isComparable && bestValue != null) ...[
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFBEB), Colors.white],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                            Text(
                              ' · WINNER',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProductThumbnail(bestValue.namaProduk, size: 84),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dimGroup.dimensionLabel.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    bestValue.namaProduk,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: const Color(0xFF0D2818),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        _formatRupiah(bestValue.harga),
                                        style: GoogleFonts.outfit(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF059669),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        bestValue.unitPriceLabel,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: const Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
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
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Savings Callout Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.monetization_on_rounded, color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hemat 18% dibanding kemasan lain dengan merek yang sama',
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

          // 2. ALL RANKED ITEMS LIST (Ref UI 3)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dimGroup.rankedItems.length,
            itemBuilder: (context, index) {
              final item = dimGroup.rankedItems[index];
              final isWinner = item.isBestValue;
              final diffPct = (item.rank * 18);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isWinner ? const Color(0xFF059669) : const Color(0xFFE8E4DC),
                    width: isWinner ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isWinner
                          ? const Color(0xFF059669).withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Medal Circle (Gold for #1, Silver for #2, Bronze for #3)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isWinner
                            ? const Color(0xFFFEF3C7)
                            : (item.rank == 2 ? const Color(0xFFE5E7EB) : const Color(0xFFFED7AA)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isWinner
                              ? const Color(0xFFD97706)
                              : (item.rank == 2 ? const Color(0xFF9CA3AF) : const Color(0xFFF97316)),
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${item.rank}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: isWinner
                                ? const Color(0xFFB45309)
                                : (item.rank == 2 ? const Color(0xFF374151) : const Color(0xFF9A3412)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Product Thumbnail
                    _buildProductThumbnail(item.namaProduk, size: 54),
                    const SizedBox(width: 12),

                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  dimGroup.dimensionLabel.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                              if (isWinner) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Best Value',
                                    style: GoogleFonts.outfit(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.namaProduk,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: const Color(0xFF0D2818),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatRupiah(item.harga),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isWinner ? const Color(0xFF059669) : const Color(0xFF0D2818),
                                ),
                              ),
                              const SizedBox(width: 4),
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

                    // Percentage diff red badge or check
                    if (!isWinner)
                      Container(
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
                              '+$diffPct%',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Paling Hemat',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // 3. "Insight dari Rakoon" Card (Ref UI 3)
          if (bestValue != null && bestValue.explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
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
                          bestValue.explanation,
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
