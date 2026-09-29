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
  List<Product> _defaultProducts = [];
  bool _isSearching = false;
  int _searchRequestToken = 0;
  Timer? _searchDebounce;

  final List<SelectedBudgetItem> _selectedItems = [];
  bool _isEvaluating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDefaultProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _budgetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDefaultProducts() async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await ProductsService.getProducts(
        baseUrl: widget.baseUrl,
      );

      if (!mounted) return;

      setState(() {
        _defaultProducts = results;
        if (_searchController.text.trim().isEmpty) {
          _searchResults = results;
        }
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _errorMessage = 'Gagal memuat produk default: $e';
      });
    }
  }

  Future<void> _searchProducts(String query) async {
    _searchRequestToken++;
    final currentToken = _searchRequestToken;

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResults = _defaultProducts;
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
      _searchResults = _defaultProducts;
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
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: const Text(
            'Smart Budget Shopping',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: const Color(0xFFF3F4F6), height: 1.0),
          ),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
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
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: Color(0xFF059669),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Total Budget Belanja (Rupiah)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          label: 'Kolom input budget belanja',
                          container: true,
                          child: TextField(
                            controller: _budgetController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Masukkan nominal budget',
                              labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF059669),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8),
                              ),
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
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cari & Tambah Barang Kebutuhan',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
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
                    style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
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
                      labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      hintText: 'Contoh: susu, roti',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Color(0xFF9CA3AF),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _searchProducts('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8),
                      ),
                    ),
                  ),
                ),

                // Search Results Dropdown List
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              item.nama,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF111827),
                              ),
                            ),
                            subtitle: Text(
                              '${item.ukuran} ${item.satuan} • Kategori: ${item.kategori}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Color(0xFF059669),
                                size: 20,
                              ),
                            ),
                            onTap: () => _addSelectedProduct(item),
                          );
                        },
                      ),
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
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // ERROR DISPLAY
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 3. DAFTAR BARANG TERPILIH
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Daftar Belanja Anda',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedItems.length} Produk',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_selectedItems.isEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_basket_outlined,
                              size: 32,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Belum ada produk terpilih.\nGunakan kolom di atas untuk mencari produk.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              height: 1.4,
                            ),
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
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Ukuran: ${item.product.ukuran} ${item.product.satuan}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
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
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                      ),
                                      color: const Color(0xFFEF4444),
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
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
                              const Divider(height: 16, color: Color(0xFFF3F4F6)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Jumlah:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const Spacer(),
                                  Semantics(
                                    label:
                                        'Kurangi kuantitas ${item.product.nama}',
                                    container: true,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                        size: 22,
                                      ),
                                      color: const Color(0xFF9CA3AF),
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _updateQuantity(index, -1),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${item.qty}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    label:
                                        'Tambah kuantitas ${item.product.nama}',
                                    container: true,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_rounded,
                                        size: 22,
                                      ),
                                      color: const Color(0xFF059669),
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
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
                        : const Icon(Icons.calculate_rounded, size: 22),
                    label: Text(
                      _isEvaluating
                          ? 'Menghitung Rekomendasi...'
                          : 'Hitung Rekomendasi Belanja',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0xFF059669).withValues(alpha: 0.3),
                      disabledBackgroundColor: const Color(0xFF059669).withValues(
                        alpha: 0.6,
                      ),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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
