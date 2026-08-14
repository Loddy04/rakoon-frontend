import 'package:flutter/material.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/features/history/data/repositories/price_history_repository.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/price_history_page.dart';
import 'package:rakoon_frontend/features/history/presentation/providers/price_history_notifier.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/features/recommendation/recommendation_screen.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:http/http.dart' as http;

class ScanResultScreen extends StatefulWidget {
  final String baseUrl;
  final List<ScanResultItem> detectedItems;
  final String? initialStoreId;
  final String? initialUserId;
  final http.Client? httpClient;

  const ScanResultScreen({
    super.key,
    required this.baseUrl,
    required this.detectedItems,
    this.initialStoreId,
    this.initialUserId,
    this.httpClient,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  bool _isSaving = false;
  String? _errorMessage;

  // Store selection state
  bool _isLoadingStores = true;
  String? _storesError;
  List<StoreNearby> _nearbyStores = [];
  StoreNearby? _selectedStore;

  // Controllers for Store & User information
  late TextEditingController _storeIdController;
  late TextEditingController _userIdController;

  // The local mutable list - single source of truth
  List<ScanResultItem> _items = [];

  @override
  void initState() {
    super.initState();
    _storeIdController = TextEditingController(text: widget.initialStoreId ?? '');
    _userIdController = TextEditingController(
      text: AuthService.currentUser?.id ?? widget.initialUserId ?? '',
    );

    // Initialize state items list
    _items = List<ScanResultItem>.from(widget.detectedItems);

    _fetchNearbyStores();
  }

  @override
  void dispose() {
    _storeIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchNearbyStores() async {
    setState(() {
      _isLoadingStores = true;
      _storesError = null;
    });

    try {
      final position = await LocationService.getCurrentLocation();
      final response = await StoresService.getNearbyStores(
        lat: position.latitude,
        lng: position.longitude,
        baseUrl: widget.baseUrl,
      );

      setState(() {
        _nearbyStores = response.stores;
        if (response.stores.isNotEmpty) {
          _selectedStore = response.stores.first;
          _storeIdController.text = response.stores.first.storeId;
        } else {
          _selectedStore = null;
          _storeIdController.text = '';
        }
        _isLoadingStores = false;
      });
    } catch (e) {
      setState(() {
        _storesError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingStores = false;
        _selectedStore = null;
        _storeIdController.text = '';
      });
    }
  }

  String _formatRupiah(double amount) {
    return formatRp(amount);
  }

  void _openEditBottomSheet(ScanResultItem item) {
    final nameController = TextEditingController(text: item.namaProduk ?? '');
    final priceController = TextEditingController(text: item.harga?.toInt().toString() ?? '');
    final sizeController = TextEditingController(text: item.ukuran?.toString() ?? '');
    final unitController = TextEditingController(text: item.satuan ?? '');
    String selectedCategory = item.kategori ?? 'Lainnya';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Produk',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  TextField(
                    key: const Key('edit_name_field'),
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    key: const Key('edit_category_dropdown'),
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: productCategories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedCategory = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    key: const Key('edit_price_field'),
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga (Rupiah)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('edit_size_field'),
                          controller: sizeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ukuran',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('edit_unit_field'),
                          controller: unitController,
                          decoration: const InputDecoration(
                            labelText: 'Satuan',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    key: const Key('save_edit_button'),
                    onPressed: () {
                      final name = nameController.text.trim();
                      final priceText = priceController.text.trim();
                      final sizeText = sizeController.text.trim();
                      final unit = unitController.text.trim().toLowerCase();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama produk tidak boleh kosong.')),
                        );
                        return;
                      }

                      final parsedPrice = double.tryParse(priceText);
                      if (parsedPrice == null || parsedPrice <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harga harus lebih besar dari 0.')),
                        );
                        return;
                      }

                      final parsedSize = double.tryParse(sizeText);
                      if (parsedSize == null || parsedSize <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ukuran harus lebih besar dari 0.')),
                        );
                        return;
                      }

                      final allowedUnits = ['ml', 'mili', 'milliliter', 'cc', 'l', 'liter', 'litre', 'g', 'gr', 'gram', 'kg', 'kilo', 'kilogram', 'pcs', 'piece', 'pieces', 'buah', 'biji', 'pack', 'bungkus'];
                      if (unit.isEmpty || !allowedUnits.contains(unit)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Satuan tidak didukung. Gunakan ml, l, g, kg, pcs, dll.')),
                        );
                        return;
                      }

                      setState(() {
                        item.namaProduk = name;
                        item.harga = parsedPrice;
                        item.ukuran = parsedSize;
                        item.satuan = unit;
                        item.kategori = selectedCategory;
                      });

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.paper,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                    ),
                    child: const Text('Simpan Perubahan'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openAddBottomSheet() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final sizeController = TextEditingController();
    final unitController = TextEditingController();
    String selectedCategory = 'Makanan Pokok';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tambah Produk Manual',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  TextField(
                    key: const Key('add_name_field'),
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    key: const Key('add_category_dropdown'),
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: productCategories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedCategory = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    key: const Key('add_price_field'),
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga (Rupiah)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('add_size_field'),
                          controller: sizeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ukuran',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('add_unit_field'),
                          controller: unitController,
                          decoration: const InputDecoration(
                            labelText: 'Satuan',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    key: const Key('save_add_button'),
                    onPressed: () {
                      final name = nameController.text.trim();
                      final priceText = priceController.text.trim();
                      final sizeText = sizeController.text.trim();
                      final unit = unitController.text.trim().toLowerCase();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama produk tidak boleh kosong.')),
                        );
                        return;
                      }

                      final parsedPrice = double.tryParse(priceText);
                      if (parsedPrice == null || parsedPrice <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harga harus lebih besar dari 0.')),
                        );
                        return;
                      }

                      final parsedSize = double.tryParse(sizeText);
                      if (parsedSize == null || parsedSize <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ukuran harus lebih besar dari 0.')),
                        );
                        return;
                      }

                      final allowedUnits = ['ml', 'mili', 'milliliter', 'cc', 'l', 'liter', 'litre', 'g', 'gr', 'gram', 'kg', 'kilo', 'kilogram', 'pcs', 'piece', 'pieces', 'buah', 'biji', 'pack', 'bungkus'];
                      if (unit.isEmpty || !allowedUnits.contains(unit)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Satuan tidak didukung. Gunakan ml, l, g, kg, pcs, dll.')),
                        );
                        return;
                      }

                      final newItem = ScanResultItem(
                        namaProduk: name,
                        harga: parsedPrice,
                        ukuran: parsedSize,
                        satuan: unit,
                        kategori: selectedCategory,
                        confidence: 'tinggi',
                        needsVerification: false,
                      );

                      setState(() {
                        _items.add(newItem);
                      });

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.paper,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                    ),
                    child: const Text('Tambah Produk'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteItem(ScanResultItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text('Hapus Produk'),
        content: Text('Apakah Anda yakin ingin menghapus "${item.namaProduk ?? 'Produk'}" dari hasil scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            key: const Key('confirm_delete_button'),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _items.remove(item);
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _evaluateBestValue() {
    final List<RecommendationCandidate> candidates = [];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      candidates.add(
        RecommendationCandidate(
          productId: 'item-${i + 1}',
          namaProduk: item.namaProduk,
          harga: item.harga,
          ukuran: item.ukuran,
          satuan: item.satuan,
          kategori: item.kategori,
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecommendationScreen(
          baseUrl: widget.baseUrl,
          initialCandidates: candidates,
          httpClient: widget.httpClient,
        ),
      ),
    );
  }

  Widget _buildProductComparisonCard(ScanResultItem item) {
    final int itemIndex = _items.indexOf(item);
    final String name = item.namaProduk ?? '';
    final double price = item.harga ?? 0.0;
    final double size = item.ukuran ?? 0.0;
    final String unit = item.satuan ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        side: BorderSide(
          color: item.needsVerification ? AppColors.warning : AppColors.line,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Produk #${itemIndex + 1}',
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.needsVerification) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Verifikasi',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(
                      status: item.confidence == 'tinggi' ? 'Tinggi' : 'Rendah',
                    ),
                    Semantics(
                      label: 'Edit produk ${name.isNotEmpty ? name : ""}',
                      button: true,
                      container: true,
                      child: IconButton(
                        key: Key('edit_item_${itemIndex}_btn'),
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        padding: EdgeInsets.zero,
                        onPressed: () => _openEditBottomSheet(item),
                        tooltip: 'Edit informasi produk',
                      ),
                    ),
                    Semantics(
                      label: 'Hapus produk ${name.isNotEmpty ? name : ""}',
                      button: true,
                      container: true,
                      child: IconButton(
                        key: Key('delete_item_${itemIndex}_btn'),
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        padding: EdgeInsets.zero,
                        onPressed: () => _deleteItem(item),
                        tooltip: 'Hapus produk',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              name.isNotEmpty ? name : 'Nama produk kosong',
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${price > 0 ? _formatRupiah(price) : "-"} · ${size > 0 ? size.toStringAsFixed(size % 1 == 0 ? 0 : 1) : "-"} $unit',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _checkAndNavigateToHistory(name),
                  icon: const Icon(Icons.analytics_outlined, size: 14, color: AppColors.accent),
                  label: const Text(
                    'Riwayat',
                    style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreSelectionArea() {
    if (_isLoadingStores) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: AppColors.line),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Mencari toko terdekat...', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
    }

    if (_storesError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorSoft,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal memuat toko: $_storesError',
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _fetchNearbyStores,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_nearbyStores.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: AppColors.line),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_off_outlined, color: AppColors.muted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tidak ada toko terdekat ditemukan',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<StoreNearby>(
      initialValue: _selectedStore,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Konfirmasi Lokasi Toko',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.storefront, color: AppColors.accent),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: _nearbyStores.map((StoreNearby store) {
        return DropdownMenuItem<StoreNearby>(
          value: store,
          child: Text(
            '${store.nama} (${store.jarakKm.toStringAsFixed(2)} km)',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (StoreNearby? newValue) {
        setState(() {
          _selectedStore = newValue;
          _storeIdController.text = newValue?.storeId ?? '';
        });
      },
    );
  }

  Future<void> _saveResults() async {
    if (AuthService.currentSession == null) {
      final bool? loginSuccess = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const LoginBottomSheet(),
        ),
      );

      if (loginSuccess != true) {
        return;
      }

      if (AuthService.currentUser != null) {
        setState(() {
          _userIdController.text = AuthService.currentUser!.id;
        });
      }
    }

    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi login tidak valid, silakan login ulang.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    final String userId = user.id;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final String storeId = _storeIdController.text.trim();

    if (storeId.isEmpty) {
      setState(() {
        _errorMessage = 'Pilih toko tempat Anda memindai terlebih dahulu!';
        _isSaving = false;
      });
      return;
    }

    final List<ScanResultItem> confirmedItems = [];
    for (var item in _items) {
      final String name = (item.namaProduk ?? '').trim();
      final double? price = item.harga;

      if (name.isEmpty) {
        setState(() {
          _errorMessage = 'Nama produk tidak boleh kosong!';
          _isSaving = false;
        });
        return;
      }

      if (price == null || price <= 0) {
        setState(() {
          _errorMessage = 'Harga produk harus lebih besar dari 0!';
          _isSaving = false;
        });
        return;
      }

      confirmedItems.add(item);
    }

    try {
      final response = await ScanService.confirmScan(
        storeId: storeId,
        userId: userId,
        items: confirmedItems,
        baseUrl: widget.baseUrl,
      );

      final int saved = response['items_saved'] ?? 0;
      final int created = response['products_created'] ?? 0;
      final String msg = response['message'] ?? 'Berhasil disimpan!';

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            elevation: 8,
            backgroundColor: AppColors.paper,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: const BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.accent,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    'Simpan Berhasil',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    msg,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.l),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.accent),
                                const SizedBox(width: AppSpacing.s),
                                Text('Entri Harga Baru', style: AppTextStyles.bodyMedium),
                              ],
                            ),
                            Text(
                              '$saved',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.s),
                          child: Divider(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.add_box_rounded, size: 18, color: AppColors.onboardingAccent1),
                                const SizedBox(width: AppSpacing.s),
                                Text('Produk Baru Dibuat', style: AppTextStyles.bodyMedium),
                              ],
                            ),
                            Text(
                              '$created',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.paper,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                      ),
                      child: Text(
                        'Selesai',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.paper,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _checkAndNavigateToHistory(String productName) async {
    if (productName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama produk tidak boleh kosong.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );

    try {
      final products = await ProductsService.getProducts(
        baseUrl: widget.baseUrl,
        search: productName.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
      }

      Product? matchedProduct;
      for (final p in products) {
        if (p.nama.trim().toLowerCase() == productName.trim().toLowerCase()) {
          matchedProduct = p;
          break;
        }
      }

      if (matchedProduct != null) {
        final repository = PriceHistoryRepository(baseUrl: widget.baseUrl);
        final notifier = PriceHistoryNotifier(repository: repository);
        final productId = matchedProduct.id;

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PriceHistoryPage(
                notifier: notifier,
                productId: productId,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Produk "${productName.trim()}" belum terdaftar di database. Silakan simpan konfirmasi terlebih dahulu untuk merekam riwayat.',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa riwayat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  bool _hasUnsavedChanges() {
    if (_items.length != widget.detectedItems.length) return true;

    for (int i = 0; i < _items.length; i++) {
      final original = widget.detectedItems[i];
      final current = _items[i];

      if (current.namaProduk != original.namaProduk ||
          current.harga != original.harga ||
          current.ukuran != original.ukuran ||
          current.satuan != original.satuan ||
          current.kategori != original.kategori) {
        return true;
      }
    }

    final initialDetectedStoreId = _nearbyStores.isNotEmpty ? _nearbyStores.first.storeId : '';
    final currentStoreId = _selectedStore?.storeId ?? '';
    if (currentStoreId != initialDetectedStoreId && currentStoreId.isNotEmpty && initialDetectedStoreId.isNotEmpty) {
      return true;
    }

    return false;
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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Koreksi Hasil Scan')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tinjauan Hasil Deteksi AI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              const Text(
                'Berikut adalah produk yang terdeteksi di rak. Silakan tinjau kebenaran data.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              const Text(
                'Daftar Perbandingan Produk',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink),
              ),
              const SizedBox(height: 8),

              if (_items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Tidak ada produk terdeteksi. Silakan tambah produk secara manual.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              else
                ..._items.map((item) => _buildProductComparisonCard(item)),

              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('add_product_button'),
                onPressed: _openAddBottomSheet,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Produk'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('best_value_cta_button'),
                onPressed: _evaluateBestValue,
                icon: const Icon(Icons.emoji_events, size: 24),
                label: const Text('🏆 Hitung Best Value Recommendation'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.accentSoft,
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              _buildStoreSelectionArea(),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                key: const Key('save_confirm_button'),
                onPressed: _isSaving || _isLoadingStores || _selectedStore == null || _items.isEmpty
                    ? null
                    : _saveResults,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.paper,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Simpan Hasil Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.paper,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
