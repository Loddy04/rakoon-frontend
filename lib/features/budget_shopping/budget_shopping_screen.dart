import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_result_screen.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class SelectedBudgetItem {
  final Product product;
  int qty;

  SelectedBudgetItem({
    required this.product,
    this.qty = 1,
  });
}

class BudgetShoppingScreen extends StatefulWidget {
  final String baseUrl;

  const BudgetShoppingScreen({
    super.key,
    required this.baseUrl,
  });

  @override
  State<BudgetShoppingScreen> createState() => _BudgetShoppingScreenState();
}

class _BudgetShoppingScreenState extends State<BudgetShoppingScreen> {
  final TextEditingController _budgetController = TextEditingController(text: '100000');
  final TextEditingController _searchController = TextEditingController();

  List<Product> _searchResults = [];
  bool _isSearching = false;

  final List<SelectedBudgetItem> _selectedItems = [];
  bool _isEvaluating = false;
  String? _errorMessage;

  Future<void> _searchProducts(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResults = [];
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

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Gagal mencari produk: $e';
      });
    }
  }

  void _addSelectedProduct(Product product) {
    // Deduplikasi via product_id
    final existingIndex = _selectedItems.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      setState(() {
        _selectedItems[existingIndex].qty += 1;
      });
    } else {
      setState(() {
        _selectedItems.add(SelectedBudgetItem(product: product, qty: 1));
      });
    }

    // Reset search
    _searchController.clear();
    setState(() {
      _searchResults = [];
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQty = _selectedItems[index].qty + delta;
      if (newQty <= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems[index].qty = newQty;
      }
    });
  }

  Future<void> _evaluateBudget() async {
    final double? budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan total budget yang valid (harus > 0).')),
      );
      return;
    }

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih setidaknya 1 produk yang ingin dibeli.')),
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
            .map((item) => BudgetItemInput(
                  productId: item.product.id,
                  qty: item.qty,
                ))
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
    return _selectedItems.isNotEmpty || _budgetController.text.trim() != '100000';
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text('Keluar Halaman'),
        content: const Text('Keluar dari halaman ini? Perubahan Anda akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
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
        appBar: AppBar(
          title: const Text('Smart Budget Shopping'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. INPUT BUDGET
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.l),
                side: const BorderSide(color: AppColors.accent, width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💰 Total Budget Belanja (Rupiah)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Misal: 100000',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. SEARCH PRODUCTS BAR
            const Text(
              '🔍 Cari & Tambah Barang Kebutuhan:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (val) => _searchProducts(val),
              decoration: InputDecoration(
                hintText: 'Ketik nama produk (contoh: "susu", "roti")',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchProducts('');
                            },
                          )
                        : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            // Search Results Dropdown List
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(color: AppColors.line),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.ukuran} ${item.satuan} • Kategori: ${item.kategori}'),
                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                      onTap: () => _addSelectedProduct(item),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // ERROR DISPLAY
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. DAFTAR BARANG TERPILIH
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📋 Daftar Belanja Anda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Chip(
                  label: Text('${_selectedItems.length} Produk'),
                  backgroundColor: AppColors.accentSoft,
                  labelStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_selectedItems.isEmpty)
              Card(
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 40, color: AppColors.muted),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada produk terpilih.\nGunakan kolom di atas untuk mencari produk.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
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
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.nama,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Ukuran: ${item.product.ukuran} ${item.product.satuan}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                color: AppColors.muted,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => _updateQuantity(index, -1),
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Text(
                                '${item.qty}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                color: AppColors.accent,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => _updateQuantity(index, 1),
                              ),
                              const SizedBox(width: AppSpacing.m),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
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
            ElevatedButton.icon(
              onPressed: _isEvaluating ? null : _evaluateBudget,
              icon: _isEvaluating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.calculate_outlined, size: 22),
              label: Text(_isEvaluating ? 'Menghitung Rekomendasi...' : '🏆 Hitung Rekomendasi Belanja'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
