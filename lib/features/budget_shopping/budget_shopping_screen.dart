import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
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
  bool _isFloatingBarExpanded = false;

  final List<String> _categories = const [
    'Semua',
    'Minuman',
    'Camilan',
    'Kebutuhan Pokok',
    'Susu',
    'Bumbu',
  ];
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _budgetController.addListener(_onBudgetChanged);
    _fetchDefaultProducts();
  }

  void _onBudgetChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _budgetController.removeListener(_onBudgetChanged);
    _budgetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double get _currentBudget {
    final parsed = BudgetParser.parse(_budgetController.text);
    return parsed ?? 0.0;
  }

  double get _totalSpent {
    return _selectedItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.product.effectivePrice * item.qty),
    );
  }

  int get _totalItemsCount {
    return _selectedItems.fold<int>(0, (sum, item) => sum + item.qty);
  }

  double get _remainingBudget {
    return _currentBudget - _totalSpent;
  }

  double get _progressRatio {
    final budget = _currentBudget;
    if (budget <= 0) return 0.0;
    return (_totalSpent / budget).clamp(0.0, 1.0);
  }

  List<Product> get _displayedProducts {
    final source = _searchResults;
    if (_selectedCategory == 'Semua') {
      return source;
    }

    final sel = _selectedCategory.toLowerCase();
    return source.where((product) {
      final kat = product.kategori.toLowerCase();
      final name = product.nama.toLowerCase();

      if (kat.contains(sel) || name.contains(sel)) return true;

      if (sel == 'minuman') {
        return kat.contains('minum') ||
            kat.contains('beverage') ||
            name.contains('susu') ||
            name.contains('teh') ||
            name.contains('kopi') ||
            name.contains('jus') ||
            name.contains('air') ||
            name.contains('uht');
      }
      if (sel == 'camilan') {
        return kat.contains('snack') ||
            kat.contains('camilan') ||
            name.contains('roti') ||
            name.contains('biskuit') ||
            name.contains('keripik') ||
            name.contains('wafer') ||
            name.contains('snack');
      }
      if (sel == 'kebutuhan pokok') {
        return kat.contains('pokok') ||
            kat.contains('sembako') ||
            name.contains('beras') ||
            name.contains('minyak') ||
            name.contains('gula') ||
            name.contains('telur') ||
            name.contains('mie') ||
            name.contains('tepung') ||
            name.contains('garam');
      }
      if (sel == 'susu') {
        return kat.contains('susu') ||
            kat.contains('dairy') ||
            name.contains('susu') ||
            name.contains('keju') ||
            name.contains('yogurt');
      }
      if (sel == 'bumbu') {
        return kat.contains('bumbu') ||
            name.contains('bumbu') ||
            name.contains('kecap') ||
            name.contains('saus') ||
            name.contains('sambal') ||
            name.contains('royco') ||
            name.contains('masako');
      }
      return false;
    }).toList();
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
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQty = _selectedItems[index].qty + delta;
      if (newQty < 1) {
        // Minimum quantity = 1. Decrement never drops below 1.
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

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final modalTotalSpent = _totalSpent;
            final modalRemaining = _remainingBudget;
            final isDeficit = modalRemaining < 0;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle Bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // Sheet Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Color(0xFF059669),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rincian Barang Belanjaan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  '${_selectedItems.length} produk • Total $_totalItemsCount unit',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF9CA3AF),
                            ),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),

                    // Items List
                    Flexible(
                      child: _selectedItems.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF9FAFB),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.remove_shopping_cart_outlined,
                                      size: 36,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Keranjang Belanja Kosong',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Pilih produk dari katalog untuk mulai belanja.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shrinkWrap: true,
                              itemCount: _selectedItems.length,
                              separatorBuilder: (context, i) =>
                                  const Divider(height: 16, color: Color(0xFFF3F4F6)),
                              itemBuilder: (context, index) {
                                final item = _selectedItems[index];
                                final subtotal =
                                    item.product.effectivePrice * item.qty;

                                return Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF7F2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFE8E4DC),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: BrandAssets.getProductAsset(
                                                item.product.nama,
                                              ) !=
                                              null
                                          ? Image.asset(
                                              BrandAssets.getProductAsset(
                                                item.product.nama,
                                              )!,
                                              fit: BoxFit.contain,
                                            )
                                          : const Icon(
                                              Icons.inventory_2_outlined,
                                              color: Color(0xFF059669),
                                              size: 20,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.nama,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatRp(subtotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Delete action
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFEF4444),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        setState(() {
                                          _selectedItems.removeAt(index);
                                        });
                                        setModalState(() {});
                                      },
                                    ),
                                    // Counter Controls
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_rounded,
                                              size: 16,
                                              color: Color(0xFF4B5563),
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 30,
                                              minHeight: 30,
                                            ),
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              if (item.qty > 1) {
                                                _updateQuantity(index, -1);
                                                setModalState(() {});
                                              }
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              '${item.qty}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_rounded,
                                              size: 16,
                                              color: Color(0xFF059669),
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 30,
                                              minHeight: 30,
                                            ),
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              _updateQuantity(index, 1);
                                              setModalState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),

                    // Cost Summary & AI Callout
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Estimasi Belanja',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                formatRp(modalTotalSpent),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isDeficit
                                    ? 'Defisit Budget'
                                    : 'Sisa Saldo Budget',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDeficit
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF059669),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                isDeficit
                                    ? '-${formatRp(modalRemaining.abs())}'
                                    : formatRp(modalRemaining),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isDeficit
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Smart Callout
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Rakoon AI akan menemukan toko dengan kombinasi harga paling hemat di sekitar Anda.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // CTA Button in Sheet
                          ElevatedButton.icon(
                            onPressed: _isEvaluating
                                ? null
                                : () {
                                    Navigator.pop(modalContext);
                                    _evaluateBudget();
                                  },
                            icon: const Icon(
                              Icons.storefront_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Cari Toko Termurah Sekarang',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopStickyBudgetTracker() {
    final remaining = _remainingBudget;
    final total = _currentBudget;
    final isDeficit = remaining < 0;
    final progress = _progressRatio;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E4DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Numbers: Sisa Budget & Total Budget in safe, non-overflowing vertical structure
          Text(
            'Sisa Budget: ${isDeficit ? "-${formatRp(remaining.abs())}" : formatRp(remaining)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDeficit
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Total Budget: ${formatRp(total)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // 2. Linear Progress Bar horizontal
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 7,
                  color: const Color(0xFFE5E7EB),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: progress > 0.85 || isDeficit
                            ? const [Color(0xFFF59E0B), Color(0xFFEF4444)]
                            : const [Color(0xFF059669), Color(0xFFFBBF24)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. Compact Total Budget Input Field
          Semantics(
            label: 'Kolom input budget belanja',
            container: true,
            child: TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Atur Total Budget Belanja',
                labelStyle: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF059669),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF059669),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndCategoryFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rounded Search Bar with Barcode Icon
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Semantics(
            label: 'Kolom pencarian barang kebutuhan',
            container: true,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
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
                isDense: true,
                hintText: 'Cari nama produk...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6B7280),
                  size: 20,
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(10.0),
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
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _searchProducts('');
                            },
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF059669),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Horizontal Category Pill Tabs
        SizedBox(
          height: 32,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, i) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _selectedCategory;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF059669)
                          : const Color(0xFFE5E7EB),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.22),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCatalogList() {
    final products = _displayedProducts;

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 95),
        children: [
          // Error Display
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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

          // Empty Search Message
          if (_searchController.text.isNotEmpty &&
              products.isEmpty &&
              !_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: Text(
                  'Tidak ada produk yang ditemukan untuk "${_searchController.text}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),

          // Main Product Cards
          ...products.map((product) {
            final selectedIndex = _selectedItems.indexWhere(
              (item) => item.product.id == product.id,
            );
            final isSelected = selectedIndex >= 0;
            final itemQty =
                isSelected ? _selectedItems[selectedIndex].qty : 0;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              color: Colors.white,
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                onTap: () {
                  if (!isSelected) {
                    _addSelectedProduct(product);
                  }
                },
                // Sisi Kiri: Thumbnail / Icon Produk
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8E4DC)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: BrandAssets.getProductAsset(product.nama) != null
                      ? Image.asset(
                          BrandAssets.getProductAsset(product.nama)!,
                          fit: BoxFit.contain,
                        )
                      : const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                ),

                // Sisi Tengah & Kanan: Layout yang responsif dan fleksibel
                title: Text(
                  product.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Color(0xFF111827),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (product.ukuran != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${product.ukuran!.toInt()} ${product.satuan ?? ""}'
                                  .trim(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          formatRp(product.effectivePrice),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Action controls row (Interactive counter or add button)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isSelected) ...[
                          Semantics(
                            label:
                                'Hapus barang ${product.nama} dari daftar belanja',
                            container: true,
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              color: const Color(0xFFEF4444),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _selectedItems.removeAt(selectedIndex);
                                });
                              },
                            ),
                          ),
                          Semantics(
                            label: 'Kurangi kuantitas ${product.nama}',
                            container: true,
                            child: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 20,
                              ),
                              color: const Color(0xFF9CA3AF),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  _updateQuantity(selectedIndex, -1),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$itemQty',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Semantics(
                            label: 'Tambah kuantitas ${product.nama}',
                            container: true,
                            child: IconButton(
                              icon: const Icon(
                                Icons.add_circle_rounded,
                                size: 20,
                              ),
                              color: const Color(0xFF059669),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  _updateQuantity(selectedIndex, 1),
                            ),
                          ),
                        ] else ...[
                          Semantics(
                            label:
                                'Tambah barang ${product.nama} ke daftar belanja',
                            container: true,
                            child: InkWell(
                              onTap: () => _addSelectedProduct(product),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tambah',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomCartBar() {
    final totalSpent = _totalSpent;
    final totalCount = _totalItemsCount;
    final remaining = _remainingBudget;
    final isDeficit = remaining < 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Floating Bar yang muncul/keluar saat tombol dipencet
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isFloatingBarExpanded && totalCount > 0
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Cart Icon Container
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Text Summary
                  Expanded(
                    child: InkWell(
                      onTap: () => _showCartBottomSheet(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalCount Barang • ${formatRp(totalSpent)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDeficit
                                ? 'Defisit: -${formatRp(remaining.abs())}'
                                : 'Sisa: ${formatRp(remaining)}',
                            style: TextStyle(
                              color: isDeficit
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF6EE7B7),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // CTA Button: "Lihat Daftar"
                  InkWell(
                    onTap: () => _showCartBottomSheet(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lihat Daftar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_right_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Tombol Sembunyikan Floating Bar
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _isFloatingBarExpanded = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),

          // 2. Baris Kontrol Bawah (Tombol Utama)
          Row(
            children: [
              // Jika ada barang dan bar tersembunyi, tampilkan tombol toggle floating di kiri
              if (totalCount > 0 && !_isFloatingBarExpanded) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _isFloatingBarExpanded = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$totalCount Item',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Color(0xFF10B981),
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Tombol Hitung Rekomendasi Belanja
              Expanded(
                child: Semantics(
                  label: 'Hitung rekomendasi belanja',
                  container: true,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isEvaluating ? null : _evaluateBudget,
                      icon: _isEvaluating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.calculate_rounded, size: 20),
                      label: Text(
                        _isEvaluating
                            ? 'Menghitung Rekomendasi...'
                            : 'Hitung Rekomendasi Belanja',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor:
                            const Color(0xFF059669).withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF111827),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: const Color(0xFFF3F4F6), height: 1.0),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Sticky Budget Tracker
              _buildTopStickyBudgetTracker(),

              // 2. Search Bar & Horizontal Category Filter Tabs
              _buildSearchAndCategoryFilters(),

              const SizedBox(height: 6),

              // 3. Main Product List (Scrollable Area)
              _buildProductCatalogList(),

              // 4. Floating Bottom Cart Bar
              _buildFloatingBottomCartBar(),
            ],
          ),
        ),
      ),
    );
  }
}
