import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import '../../data/repositories/price_history_repository.dart';
import '../providers/price_history_notifier.dart';
import 'price_history_page.dart';

class ProductHistoryListPage extends StatefulWidget {
  final String baseUrl;

  const ProductHistoryListPage({super.key, required this.baseUrl});

  @override
  State<ProductHistoryListPage> createState() => _ProductHistoryListPageState();
}

class _ProductHistoryListPageState extends State<ProductHistoryListPage> {
  List<Product>? _products;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchProducts({String? search}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await ProductsService.getProducts(
        baseUrl: widget.baseUrl,
        search: search,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchProducts(search: query);
    });
  }

  void _navigateToPriceHistory(Product product) {
    final repository = PriceHistoryRepository(baseUrl: widget.baseUrl);
    final notifier = PriceHistoryNotifier(repository: repository);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PriceHistoryPage(notifier: notifier, productId: product.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Produk Pindai'),
        elevation: 0,
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Container
            Container(
              color: AppColors.paper,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cari produk yang pernah dipindai...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.muted),
                          onPressed: () {
                            _searchController.clear();
                            _fetchProducts();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.l),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Products list or loading/empty state
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    );
                  }

                  if (_errorMessage != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: AppSpacing.l),
                            Text(
                              'Gagal Memuat Produk',
                              style: AppTextStyles.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.s),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            ElevatedButton(
                              onPressed: () => _fetchProducts(
                                search: _searchController.text,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.paper,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                              ),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final products = _products ?? [];

                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              decoration: const BoxDecoration(
                                color: AppColors.card,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.history_toggle_off,
                                size: 48,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.l),
                            Text(
                              'Belum Ada Riwayat Pindai',
                              style: AppTextStyles.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.s),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Tidak ditemukan produk dengan kata pencarian tersebut.'
                                  : 'Produk yang Anda pindai dan konfirmasi akan terdaftar di sini.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        _fetchProducts(search: _searchController.text),
                    color: AppColors.accent,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      itemCount: products.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.m),
                      itemBuilder: (context, index) {
                        final product = products[index];

                        return InkWell(
                          onTap: () => _navigateToPriceHistory(product),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.l),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                // Icon/Art Box
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.l,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.l),

                                // Product Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.nama,
                                        style: AppTextStyles.bodyLarge,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          // Category Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.full,
                                                  ),
                                            ),
                                            child: Text(
                                              product.kategori,
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.muted,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Specs Label (if available)
                                          if (product.ukuran != null)
                                            Text(
                                              '${product.ukuran!.toStringAsFixed(product.ukuran! % 1 == 0 ? 0 : 1)} ${product.satuan ?? ""}',
                                              style: AppTextStyles.bodySmall,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.muted,
                                ),
                              ],
                            ),
                          ),
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
