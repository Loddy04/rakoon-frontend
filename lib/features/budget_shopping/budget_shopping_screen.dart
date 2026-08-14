import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_result_screen.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/features/budget_shopping/utils/budget_parser.dart';

class SelectedBudgetItem {
  final Product product;
  int qty;

  SelectedBudgetItem({required this.product, this.qty = 1});
}

class BudgetShoppingScreen extends StatefulWidget {
  final String baseUrl;

  const BudgetShoppingScreen({super.key, required this.baseUrl});

  @override
  State<BudgetShoppingScreen> createState() => _BudgetShoppingScreenState();
}

class _BudgetShoppingScreenState extends State<BudgetShoppingScreen> {
  final TextEditingController _budgetController = TextEditingController(
    text: '100000',
  );
  final TextEditingController _searchController = TextEditingController();

  List<Product> _searchResults = [];
  bool _isSearching = false;
  int _searchRequestToken = 0;
  Timer? _searchDebounce;

  final List<SelectedBudgetItem> _selectedItems = [];
  bool _isEvaluating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _budgetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    _searchRequestToken++;
    final currentToken = _searchRequestToken;

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await ProductsService.getProducts(
        baseUrl: widget.baseUrl,
        search: cleanQuery,
      );

      if (!mounted) return;
      if (currentToken != _searchRequestToken) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (currentToken != _searchRequestToken) return;

      setState(() {
        _isSearching = false;
        _errorMessage = 'Gagal mencari produk: $e';
      });
    }
  }

  void _addSelectedProduct(Product product) {
    final existingIndex = _selectedItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      setState(() {
        _selectedItems[existingIndex].qty += 1;
      });
    } else {
      setState(() {
        _selectedItems.add(SelectedBudgetItem(product: product, qty: 1));
      });
    }

    _searchController.clear();
    setState(() {
      _searchResults = [];
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQty = _selectedItems[index].qty + delta;
      if (newQty < 1) {
        // Minimum quantity = 1. Decrement must never create zero/negative quantity. Remove must be explicit.
        return;
      }
      _selectedItems[index].qty = newQty;
    });
  }

  Future<void> _evaluateBudget() async {
    final String rawText = _budgetController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan budget terlebih dahulu.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final double? budget = BudgetParser.parse(rawText);
    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget harus lebih dari Rp0.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih setidaknya 1 produk yang ingin dibeli.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isEvaluating = true;
      _errorMessage = null;
    });

    try {
      final request = BudgetRecommendRequest(
        budget: budget,
        items: _selectedItems
            .map(
              (item) =>
                  BudgetItemInput(productId: item.product.id, qty: item.qty),
            )
            .toList(),
      );

      final result = await BudgetShoppingService.evaluateBudgetShopping(
        baseUrl: widget.baseUrl,
        request: request,
      );

      if (!mounted) return;

      setState(() {
        _isEvaluating = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BudgetResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isEvaluating = false;
        _errorMessage = e.toString();
      });
    }
  }

  bool _hasUnsavedChanges() {
    return _selectedItems.isNotEmpty ||
        _budgetController.text.trim() != '100000';
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text('Keluar Halaman'),
        content: const Text(
          'Keluar dari halaman ini? Perubahan Anda akan hilang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog(context);
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Smart Budget Shopping'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. INPUT BUDGET
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.l,
                                ),
                              ),
                              child: const Icon(
                                Icons.payments_outlined,
                                color: AppColors.ink,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Total Budget Belanja (Rupiah)',
                                style: AppTextStyles.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Kolom input budget belanja',
                          container: true,
                          child: TextField(
                            controller: _budgetController,
                            keyboardType: TextInputType.number,
                            style: AppTextStyles.bodyMedium,
                            decoration: InputDecoration(
                              labelText: 'Masukkan nominal budget',
                              prefixText: 'Rp ',
                              prefixStyle: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. SEARCH PRODUCTS BAR
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                      child: const Icon(
                        Icons.search_outlined,
                        color: AppColors.ink,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cari & Tambah Barang Kebutuhan',
                        style: AppTextStyles.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Kolom pencarian barang kebutuhan',
                  container: true,
                  child: TextField(
                    controller: _searchController,
                    style: AppTextStyles.bodyMedium,
                    onChanged: (val) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 300),
                        () {
                          _searchProducts(val);
                        },
                      );
                    },
                    decoration: InputDecoration(
                      labelText: 'Cari Nama Produk',
                      hintText: 'Contoh: susu, roti',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.muted,
                      ),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.muted,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _searchProducts('');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),

                // Search Results Dropdown List
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(color: AppColors.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              item.nama,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                            subtitle: Text(
                              '${item.ukuran} ${item.satuan} • Kategori: ${item.kategori}',
                              style: AppTextStyles.bodySmall,
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.accent,
                            ),
                            onTap: () => _addSelectedProduct(item),
                          );
                        },
                      ),
                    ),
                  ),

                if (_searchController.text.isNotEmpty &&
                    _searchResults.isEmpty &&
                    !_isSearching)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Text(
                      'Tidak ada produk yang ditemukan untuk "${_searchController.text}"',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ERROR DISPLAY
                if (_errorMessage != null)
                  Card(
                    color: AppColors.errorSoft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      side: const BorderSide(
                        color: AppColors.error,
                        width: 1.0,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. DAFTAR BARANG TERPILIH
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.ink,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Daftar Belanja Anda',
                        style: AppTextStyles.titleSmall,
                      ),
                    ),
                    Chip(
                      label: Text('${_selectedItems.length} Produk'),
                      backgroundColor: AppColors.accentSoft,
                      side: BorderSide.none,
                      labelStyle: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_selectedItems.isEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.shopping_basket_outlined,
                            size: 40,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada produk terpilih.\nGunakan kolom di atas untuk mencari produk.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedItems.length,
                    itemBuilder: (context, index) {
                      final item = _selectedItems[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.line),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.nama,
                                          style: AppTextStyles.bodyLarge
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ukuran: ${item.product.ukuran} ${item.product.satuan}',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Semantics(
                                    label:
                                        'Hapus barang ${item.product.nama} dari daftar belanja',
                                    container: true,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      color: AppColors.error,
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        setState(() {
                                          _selectedItems.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Jumlah:',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Semantics(
                                    label:
                                        'Kurangi kuantitas ${item.product.nama}',
                                    container: true,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                      ),
                                      color: AppColors.muted,
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _updateQuantity(index, -1),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${item.qty}',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Semantics(
                                    label:
                                        'Tambah kuantitas ${item.product.nama}',
                                    container: true,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                      ),
                                      color: AppColors.accent,
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _updateQuantity(index, 1),
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

                const SizedBox(height: 24),

                // 4. SUBMIT BUTTON
                Semantics(
                  label: 'Hitung rekomendasi belanja',
                  container: true,
                  child: ElevatedButton.icon(
                    onPressed: _isEvaluating ? null : _evaluateBudget,
                    icon: _isEvaluating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.calculate_outlined, size: 22),
                    label: Text(
                      _isEvaluating
                          ? 'Menghitung Rekomendasi...'
                          : 'Hitung Rekomendasi Belanja',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.accent.withValues(
                        alpha: 0.6,
                      ),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                      textStyle: AppTextStyles.bodyLarge.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
