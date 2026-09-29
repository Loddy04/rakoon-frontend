import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';

class PriceCheckCatalogPage extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;
  final double userLat;
  final double userLng;

  const PriceCheckCatalogPage({
    super.key,
    this.baseUrl,
    this.httpClient,
    this.userLat = -7.7829,
    this.userLng = 110.4083,
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

  void _navigateToDetail(RecommendedProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedProductPriceDetailPage(
          product: product,
          baseUrl: widget.baseUrl,
          httpClient: widget.httpClient,
          userLat: widget.userLat,
          userLng: widget.userLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'CEK HARGA',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Color(0xFF111827),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFF1F5F9), height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Modern Search Bar Container
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {});
                  _onSearchChanged(val);
                },
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Cari nama produk...',
                  hintStyle: const TextStyle(
                    fontSize: 13.0,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
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
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Horizontal Scrollable Category Filter Chips
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 38,
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
                        return GestureDetector(
                          onTap: () => _onCategorySelected(category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    )
                                  : null,
                              color: isSelected ? null : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20.0),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            Container(color: const Color(0xFFF1F5F9), height: 1.0),

            // 3. 2-Column Marketplace Product Grid (Modern Colorful Style)
            Expanded(
              child: ListenableBuilder(
                listenable: _priceCheckProvider,
                builder: (context, child) {
                  if (_priceCheckProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF059669)),
                    );
                  }

                  if (_priceCheckProvider.products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.search_off_rounded,
                                size: 44,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Produk Tidak Ditemukan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tidak ada produk yang cocok dengan pencarian atau filter kategori yang dipilih.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => _priceCheckProvider.fetchCatalog(
                      baseUrl: widget.baseUrl,
                      client: widget.httpClient,
                    ),
                    color: const Color(0xFF059669),
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.58,
                      ),
                      itemCount: _priceCheckProvider.products.length,
                      itemBuilder: (context, index) {
                        final catalogItem = _priceCheckProvider.products[index];
                        final storeInfo = catalogItem.namaTokoTerendah != null
                            ? catalogItem.namaTokoTerendah!
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
                          jarakKm: null,
                          updatedAt: catalogItem.updatedAt ?? 'just now',
                          fotoUrl: catalogItem.fotoUrl,
                        );

                        return ProductCard(
                          product: recommendedProd,
                          onTap: () => _navigateToDetail(recommendedProd),
                          width: double.infinity,
                        );
                      },
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
