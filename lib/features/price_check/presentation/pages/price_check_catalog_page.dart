import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';

class PriceCheckCatalogPage extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;
  final double? userLat;
  final double? userLng;
  // userLat/userLng punya nilai bawaan; hanya dikirim ke backend bila lokasi benar-benar terdeteksi.
  final bool hasUserLocation;

  const PriceCheckCatalogPage({
    super.key,
    this.baseUrl,
    this.httpClient,
    this.userLat,
    this.userLng,
    this.hasUserLocation = false,
  });

  @override
  State<PriceCheckCatalogPage> createState() => _PriceCheckCatalogPageState();
}

class _PriceCheckCatalogPageState extends State<PriceCheckCatalogPage> {
  final TextEditingController _searchController = TextEditingController();
  late PriceCheckProvider _priceCheckProvider;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _priceCheckProvider = PriceCheckProvider();
    if (widget.hasUserLocation && widget.userLat != null && widget.userLng != null) {
      _priceCheckProvider.setUserLocation(widget.userLat!, widget.userLng!);
    }
    _priceCheckProvider.fetchCatalog(
      baseUrl: widget.baseUrl,
      client: widget.httpClient,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _priceCheckProvider.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _priceCheckProvider.updateSearch(
        query,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );
    });
  }

  void _onCategorySelected(String category) {
    _priceCheckProvider.selectCategory(
      category,
      baseUrl: widget.baseUrl,
      client: widget.httpClient,
    );
  }

  void _loadMore() {
    _priceCheckProvider.loadMore(baseUrl: widget.baseUrl, client: widget.httpClient);
  }

  Widget _buildLoadMoreFooter() {
    if (_priceCheckProvider.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Column(
          children: [
            Text(
              _priceCheckProvider.loadMoreError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
            TextButton(onPressed: _loadMore, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (_priceCheckProvider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D2818)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _navigateToDetail(RecommendedProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedProductPriceDetailPage(
          product: product,
          baseUrl: widget.baseUrl,
          httpClient: widget.httpClient,
          userLat: widget.hasUserLocation ? widget.userLat : null,
          userLng: widget.hasUserLocation ? widget.userLng : null,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('semua')) return Icons.grid_view_rounded;
    if (lower.contains('makanan')) return Icons.rice_bowl_rounded;
    if (lower.contains('minuman')) return Icons.local_drink_rounded;
    if (lower.contains('susu')) return Icons.water_drop_rounded;
    if (lower.contains('camilan') || lower.contains('snack')) return Icons.cookie_rounded;
    if (lower.contains('bumbu')) return Icons.eco_rounded;
    if (lower.contains('segar') || lower.contains('buah') || lower.contains('sayur')) return Icons.apple_rounded;
    if (lower.contains('rumah')) return Icons.home_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D2818),
        scrolledUnderElevation: 0,
        leading: const BackButton(color: Color(0xFF0D2818)),
        title: Text(
          'Cek Harga',
          style: GoogleFonts.outfit(
            fontSize: 18.0,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D2818),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE8E4DC), height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar with QR scanner icon (Ref UI 4)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: const Color(0xFFE8E4DC)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {});
                    _onSearchChanged(val);
                  },
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D2818),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari produk (contoh: Minyak, Susu, Mie)...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF059669),
                      size: 22,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _priceCheckProvider.updateSearch(
                                '',
                                baseUrl: widget.baseUrl,
                                client: widget.httpClient,
                              );
                            },
                          ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE8E4DC)),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Color(0xFF059669),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 14.0,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Horizontal Scrollable Category Filter Chips with Icons (Ref UI 4)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: PriceCheckProvider.categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = PriceCheckProvider.categories[index];
                    return ListenableBuilder(
                      listenable: _priceCheckProvider,
                      builder: (context, child) {
                        final isSelected = _priceCheckProvider.selectedCategory == category;
                        final icon = _getCategoryIcon(category);

                        return InteractiveScale(
                          onTap: () => _onCategorySelected(category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF0D2818), Color(0xFF2E6644)],
                                    )
                                  : null,
                              color: isSelected ? null : Colors.white,
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : const Color(0xFFE8E4DC),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0D2818).withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 15,
                                  color: isSelected ? Colors.white : const Color(0xFF059669),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  category,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            Container(color: const Color(0xFFE8E4DC), height: 1.0),

            // 3. Scrollable Area: Market Price Trend Chart + Sub-Header + 2-Column Marketplace Product Grid
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _priceCheckProvider.fetchCatalog(
                  baseUrl: widget.baseUrl,
                  client: widget.httpClient,
                ),
                color: const Color(0xFF0D2818),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 400) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: ListenableBuilder(
                  listenable: _priceCheckProvider,
                  builder: (context, child) {
                    if (_priceCheckProvider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF0D2818)),
                      );
                    }
                    if (_priceCheckProvider.status == PriceCheckStatus.error) {
                      return _buildErrorState();
                    }

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Count & Sort / Filter Sub-Header Row
                        SliverToBoxAdapter(
                          child: _buildSubHeaderRow(),
                        ),

                        // Products Grid or Empty State
                        if (_priceCheckProvider.products.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.70,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final catalogItem = _priceCheckProvider.products[index];
                                  final storeInfo = catalogItem.namaTokoTerendah != null
                                      ? catalogItem.namaTokoTerendah!.trim()
                                      : (catalogItem.jumlahToko > 0
                                          ? 'Tersedia di ${catalogItem.jumlahToko} toko'
                                          : 'Toko Terdekat');

                                  final recommendedProd = RecommendedProduct(
                                    id: catalogItem.id,
                                    nama: catalogItem.nama,
                                    kategori: catalogItem.kategori,
                                    harga: catalogItem.hargaTerendah ?? 0.0,
                                    ukuran: catalogItem.ukuran,
                                    satuan: catalogItem.satuan,
                                    namaToko: storeInfo,
                                    jarakKm: catalogItem.jarakKm,
                                    updatedAt: catalogItem.updatedAt ?? 'Baru saja',
                                    fotoUrl: catalogItem.fotoUrl,
                                    stale: catalogItem.stale,
                                  );

                                  return ProductCard(
                                    product: recommendedProd,
                                    onTap: () => _navigateToDetail(recommendedProd),
                                    width: double.infinity,
                                  );
                                },
                                childCount: _priceCheckProvider.products.length,
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(child: _buildLoadMoreFooter()),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),
                      ],
                    );
                  },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFF6B7280)),
            const SizedBox(height: 12),
            Text(
              _priceCheckProvider.errorMessage ?? 'Gagal memuat katalog. Coba lagi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF374151)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key('retry_catalog_button'),
              onPressed: () => _priceCheckProvider.fetchCatalog(baseUrl: widget.baseUrl, client: widget.httpClient),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2818),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Coba lagi', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Produk Tidak Ditemukan',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D2818),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tidak ada produk yang cocok dengan pencarian atau filter kategori yang dipilih.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubHeaderRow() {
    return ListenableBuilder(
      listenable: _priceCheckProvider,
      builder: (context, child) {
        final sortFilterRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E4DC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_vert_rounded, size: 13, color: Color(0xFF0D2818)),
                  const SizedBox(width: 3),
                  Text(
                    'Harga Terendah',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D2818),
                    ),
                  ),
                  const SizedBox(width: 1),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 13, color: Color(0xFF6B7280)),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E4DC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF0D2818)),
                  const SizedBox(width: 3),
                  Text(
                    'Filter',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D2818),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Ditemukan ${_priceCheckProvider.products.length} Produk',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: sortFilterRow,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


