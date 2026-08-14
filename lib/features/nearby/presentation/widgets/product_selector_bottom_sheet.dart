import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

/// A reusable stateful bottom sheet widget that fetches products dynamically and allows searching with debouncing.
class ProductSelectorBottomSheet extends StatefulWidget {
  final String baseUrl;
  final Function(Product) onProductSelected;

  const ProductSelectorBottomSheet({
    super.key,
    required this.baseUrl,
    required this.onProductSelected,
  });

  @override
  State<ProductSelectorBottomSheet> createState() =>
      _ProductSelectorBottomSheetState();
}

class _ProductSelectorBottomSheetState
    extends State<ProductSelectorBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Fetches products using the ProductsService API.
  Future<void> _fetchProducts({String? search}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ProductsService.getProducts(
        baseUrl: widget.baseUrl,
        search: search,
      );
      if (!mounted) return;
      setState(() {
        _products = list;
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

  /// Callback when the search query text changes, implementing a 400ms debounce.
  void _onSearchChanged(String text) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchProducts(search: text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Pilih Produk untuk Dibandingkan',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bandingkan harga produk ini di seluruh toko sekitar Anda.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.l),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Cari nama produk...',
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
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s,
                horizontal: AppSpacing.m,
              ),
              fillColor: AppColors.card,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // Dynamic Content Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _products.isEmpty
                        ? _buildEmptyState()
                        : _buildProductsList(),
          ),
        ],
      ),
    );
  }

  /// Renders clean error state box using error Soft design token
  Widget _buildErrorWidget() {
    return Center(
      child: Text(
        _errorMessage ?? 'Gagal memuat daftar produk.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
      ),
    );
  }

  /// Renders empty state when search returns no products
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 40.0,
            color: AppColors.muted,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Produk tidak ditemukan',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Coba ketik kata kunci pencarian yang lain.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Renders lists of fetched products
  Widget _buildProductsList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final prod = _products[index];
        final subText = [
          prod.kategori,
          if (prod.ukuran != null) '${prod.ukuran} ${prod.satuan ?? ""}',
        ].join(' • ');

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.accent,
              size: 20.0,
            ),
          ),
          title: Text(
            prod.nama,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subText,
            style: AppTextStyles.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
          onTap: () => widget.onProductSelected(prod),
        );
      },
    );
  }
}
