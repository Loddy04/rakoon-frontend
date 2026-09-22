import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/bouncy_button.dart';
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
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          'CEK HARGA',
          style: AppTextStyles.subheading.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.graphite,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.graphite,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar Container
            Container(
              color: AppColors.paper,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s10,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {});
                  _onSearchChanged(val);
                },
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.graphite),
                decoration: InputDecoration(
                  hintText: 'Cari nama produk...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.fog),
                  prefixIcon: const Icon(Icons.search, color: AppColors.graphite),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.graphite),
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
                  fillColor: AppColors.softWhite,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s12,
                    horizontal: AppSpacing.s16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.cards),
                    borderSide: BorderSide(color: AppColors.graphite.withValues(alpha: 0.2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.cards),
                    borderSide: const BorderSide(color: AppColors.graphite, width: 1.5),
                  ),
                ),
              ),
            ),

            // 2. Horizontal Scrollable Category Filter Chips
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: PriceCheckProvider.categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.s10),
                itemBuilder: (context, index) {
                  final category = PriceCheckProvider.categories[index];
                  return ListenableBuilder(
                    listenable: _priceCheckProvider,
                    builder: (context, child) {
                      final isSelected = _priceCheckProvider.selectedCategory == category;
                      return BouncyButton(
                        onPressed: () => _onCategorySelected(category),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        borderRadius: BorderRadius.circular(AppRadius.cards),
                        variant: isSelected ? BouncyButtonVariant.accentAction : BouncyButtonVariant.primaryPill,
                        child: Text(
                          category,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppColors.paper : AppColors.graphite,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1, color: AppColors.line),

            // 3. 2-Column Marketplace Product Grid (Tokopedia/Shopee style)
            Expanded(
              child: ListenableBuilder(
                listenable: _priceCheckProvider,
                builder: (context, child) {
                  if (_priceCheckProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.periwinkle),
                    );
                  }

                  if (_priceCheckProvider.products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              decoration: const BoxDecoration(
                                color: AppColors.softWhite,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: AppColors.fog,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            Text(
                              'Produk Tidak Ditemukan',
                              style: AppTextStyles.subheading.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.graphite,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s10),
                            Text(
                              'Tidak ada produk yang cocok dengan pencarian atau filter kategori yang dipilih.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.fog),
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
                    color: AppColors.periwinkle,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpacing.s12,
                        mainAxisSpacing: AppSpacing.s12,
                        childAspectRatio: 0.65,
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
