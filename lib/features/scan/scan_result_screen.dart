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

class CalculatedRankItem {
  final int index;
  final String name;
  final double price;
  final double size;
  final String unit;
  final String category;
  final String dimension;
  final double normalizedSize;
  final double unitPrice;
  final String unitLabel;
  int rank = 1;
  bool isBestValue = false;
  String explanation = '';
  double priceDiff = 0.0;

  CalculatedRankItem({
    required this.index,
    required this.name,
    required this.price,
    required this.size,
    required this.unit,
    required this.category,
    required this.dimension,
    required this.normalizedSize,
    required this.unitPrice,
    required this.unitLabel,
  });
}

class ScanResultScreen extends StatefulWidget {
  final String baseUrl;
  final List<ScanResultItem> detectedItems;
  final String defaultStoreId;
  final String defaultUserId;

  const ScanResultScreen({
    super.key,
    required this.baseUrl,
    required this.detectedItems,
    this.defaultStoreId = '21ba0855-bf71-4e6a-9718-b7ac79d8cfd2',
    this.defaultUserId = 'c61b0cfa-3512-4fb3-96b6-3974c05ef1c8',
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

  // Controllers for editing detected items
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _priceControllers = [];
  final List<TextEditingController> _sizeControllers = [];
  final List<TextEditingController> _unitControllers = [];

  // Selected categories for each detected item
  final List<String> _selectedCategories = [];

  // Ranked results computed locally
  List<CalculatedRankItem> _rankedItems = [];
  CalculatedRankItem? _bestValueItem;

  @override
  void initState() {
    super.initState();
    _storeIdController = TextEditingController(text: widget.defaultStoreId);
    _userIdController = TextEditingController(
      text: AuthService.currentUser?.id ?? widget.defaultUserId,
    );

    // Initialize controllers
    for (var item in widget.detectedItems) {
      _nameControllers.add(TextEditingController(text: item.namaProduk ?? ''));
      _priceControllers.add(
        TextEditingController(text: item.harga?.toInt().toString() ?? ''),
      );
      _sizeControllers.add(
        TextEditingController(text: item.ukuran?.toString() ?? ''),
      );
      _unitControllers.add(TextEditingController(text: item.satuan ?? ''));

      String itemCategory = item.kategori ?? 'Lainnya';
      if (!productCategories.contains(itemCategory)) {
        itemCategory = 'Lainnya';
      }
      _selectedCategories.add(itemCategory);
    }
    _fetchNearbyStores();
    _calculateLocalBestValue();
  }

  @override
  void dispose() {
    _storeIdController.dispose();
    _userIdController.dispose();
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    for (var controller in _priceControllers) {
      controller.dispose();
    }
    for (var controller in _sizeControllers) {
      controller.dispose();
    }
    for (var controller in _unitControllers) {
      controller.dispose();
    }
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
      _calculateLocalBestValue();
    } catch (e) {
      setState(() {
        _storesError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingStores = false;
        _selectedStore = null;
        _storeIdController.text = '';
      });
    }
  }

  void _calculateLocalBestValue() {
    _rankedItems = [];
    _bestValueItem = null;

    final List<CalculatedRankItem> validItems = [];

    for (int i = 0; i < widget.detectedItems.length; i++) {
      final name = _nameControllers[i].text.trim();
      final price = double.tryParse(_priceControllers[i].text.trim());
      final size = double.tryParse(_sizeControllers[i].text.trim());
      final unit = _unitControllers[i].text.trim().toLowerCase();
      final category = _selectedCategories[i];

      if (name.isEmpty || price == null || price <= 0 || size == null || size <= 0 || unit.isEmpty) {
        continue;
      }

      double multiplier = 1.0;
      String dimension = '';
      String baseUnit = '';

      if (['ml', 'mili', 'milliliter', 'cc'].contains(unit)) {
        dimension = 'volume';
        baseUnit = 'ml';
        multiplier = 1.0;
      } else if (['l', 'liter', 'litre'].contains(unit)) {
        dimension = 'volume';
        baseUnit = 'ml';
        multiplier = 1000.0;
      } else if (['g', 'gr', 'gram'].contains(unit)) {
        dimension = 'weight';
        baseUnit = 'g';
        multiplier = 1.0;
      } else if (['kg', 'kilo', 'kilogram'].contains(unit)) {
        dimension = 'weight';
        baseUnit = 'g';
        multiplier = 1000.0;
      } else if (['pcs', 'piece', 'pieces', 'buah', 'biji', 'pack', 'bungkus'].contains(unit)) {
        dimension = 'count';
        baseUnit = 'pcs';
        multiplier = 1.0;
      } else {
        continue;
      }

      final normalizedSize = size * multiplier;
      final unitPrice = price / normalizedSize;
      
      String unitLabel = '';
      if (baseUnit == 'ml') {
        unitLabel = 'Rp ${(unitPrice * 100).toStringAsFixed(0)} / 100ml';
      } else if (baseUnit == 'g') {
        unitLabel = 'Rp ${(unitPrice * 100).toStringAsFixed(0)} / 100g';
      } else {
        unitLabel = 'Rp ${unitPrice.toStringAsFixed(0)} / pcs';
      }

      validItems.add(
        CalculatedRankItem(
          index: i,
          name: name,
          price: price,
          size: size,
          unit: unit,
          category: category,
          dimension: dimension,
          normalizedSize: normalizedSize,
          unitPrice: unitPrice,
          unitLabel: unitLabel,
        ),
      );
    }

    if (validItems.length >= 2) {
      final Map<String, List<CalculatedRankItem>> groups = {};
      for (final item in validItems) {
        final key = '${item.category}_${item.dimension}';
        groups.putIfAbsent(key, () => []).add(item);
      }

      for (final key in groups.keys) {
        final groupItems = groups[key]!;
        if (groupItems.length >= 2) {
          groupItems.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
          final winner = groupItems.first;
          final runnerUp = groupItems[1];

          winner.isBestValue = true;
          winner.rank = 1;
          
          final savingsPerUnit = runnerUp.unitPrice - winner.unitPrice;
          final absoluteSavings = savingsPerUnit * winner.normalizedSize;
          final percentSavings = (savingsPerUnit / runnerUp.unitPrice) * 100;
          
          winner.explanation = 'Hemat ${percentSavings.toStringAsFixed(1)}% dibanding ${runnerUp.name} (Hemat ${_formatRupiah(absoluteSavings)})';
          winner.priceDiff = 0.0;

          for (int r = 1; r < groupItems.length; r++) {
            final item = groupItems[r];
            item.rank = r + 1;
            item.isBestValue = false;
            final diffPercent = ((item.unitPrice - winner.unitPrice) / winner.unitPrice) * 100;
            final diffPrice = (item.unitPrice - winner.unitPrice) * item.normalizedSize;
            item.priceDiff = diffPrice;
            item.explanation = 'Lebih mahal +${_formatRupiah(diffPrice)} (+${diffPercent.toStringAsFixed(1)}%)';
          }
        }
      }

      _rankedItems = validItems;
      final winners = _rankedItems.where((x) => x.isBestValue).toList();
      if (winners.isNotEmpty) {
        _bestValueItem = winners.first;
      }
    } else {
      _rankedItems = validItems;
    }
  }

  String _formatRupiah(double amount) {
    return 'Rp${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _openEditBottomSheet(int index) {
    final nameController = TextEditingController(text: _nameControllers[index].text);
    final priceController = TextEditingController(text: _priceControllers[index].text);
    final sizeController = TextEditingController(text: _sizeControllers[index].text);
    final unitController = TextEditingController(text: _unitControllers[index].text);
    String selectedCategory = _selectedCategories[index];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        'Edit Produk #${index + 1}',
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
                    value: selectedCategory,
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
                      final unit = unitController.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama produk tidak boleh kosong.')),
                        );
                        return;
                      }

                      if (double.tryParse(priceText) == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harga harus berupa angka valid.')),
                        );
                        return;
                      }

                      if (double.tryParse(sizeText) == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ukuran harus berupa angka valid.')),
                        );
                        return;
                      }

                      setState(() {
                        _nameControllers[index].text = name;
                        _priceControllers[index].text = priceText;
                        _sizeControllers[index].text = sizeText;
                        _unitControllers[index].text = unit;
                        _selectedCategories[index] = selectedCategory;
                        _calculateLocalBestValue();
                      });

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
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

  Widget _buildBestValueHeroCard() {
    final item = _bestValueItem!;
    return Container(
      key: const Key('best_value_hero_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'NILAI TERBAIK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('edit_best_value_btn'),
                icon: const Icon(Icons.edit, color: AppColors.accent),
                onPressed: () => _openEditBottomSheet(item.index),
                tooltip: 'Edit informasi produk',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${_selectedStore?.nama ?? "Toko"} · ',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
              ),
              Text(
                '${item.size.toStringAsFixed(item.size % 1 == 0 ? 0 : 1)} ${item.unit}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Harga Deteksi', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    _formatRupiah(item.price),
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Harga Unit', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    item.unitLabel,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(AppRadius.l),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.explanation,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductComparisonCard(int index) {
    final rankItem = _rankedItems.firstWhere(
      (x) => x.index == index,
      orElse: () => CalculatedRankItem(
        index: index,
        name: _nameControllers[index].text,
        price: double.tryParse(_priceControllers[index].text) ?? 0.0,
        size: double.tryParse(_sizeControllers[index].text) ?? 0.0,
        unit: _unitControllers[index].text,
        category: _selectedCategories[index],
        dimension: '',
        normalizedSize: 0.0,
        unitPrice: 0.0,
        unitLabel: '',
      ),
    );

    final bool isWinner = rankItem.isBestValue;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: isWinner ? AppColors.accentSoft.withOpacity(0.3) : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        side: BorderSide(
          color: isWinner
              ? AppColors.accent
              : widget.detectedItems[index].needsVerification
                  ? AppColors.warning
                  : AppColors.line,
          width: isWinner ? 1.5 : 1.0,
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
                Row(
                  children: [
                    Text(
                      'Produk #${index + 1}',
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (widget.detectedItems[index].needsVerification) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Verifikasi',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    StatusBadge(
                      status: widget.detectedItems[index].confidence == 'tinggi'
                          ? 'Tinggi'
                          : 'Rendah',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: Key('edit_item_${index}_btn'),
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.muted),
                      onPressed: () => _openEditBottomSheet(index),
                      tooltip: 'Edit informasi produk',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              rankItem.name.isNotEmpty ? rankItem.name : 'Nama produk kosong',
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${rankItem.price > 0 ? _formatRupiah(rankItem.price) : "-"} · ${rankItem.size > 0 ? rankItem.size.toStringAsFixed(rankItem.size % 1 == 0 ? 0 : 1) : "-"} ${rankItem.unit}',
                  style: AppTextStyles.bodySmall,
                ),
                if (rankItem.unitLabel.isNotEmpty)
                  Text(
                    rankItem.unitLabel,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (rankItem.explanation.isNotEmpty && !isWinner)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.error, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            rankItem.explanation,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                TextButton.icon(
                  onPressed: () => _checkAndNavigateToHistory(rankItem.name),
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
            Text('Mencari toko terdekat...', style: TextStyle(fontSize: 14)),
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
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
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
        _calculateLocalBestValue();
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

    if (storeId.isEmpty || userId.isEmpty) {
      setState(() {
        _errorMessage = 'Store ID dan User ID tidak boleh kosong!';
        _isSaving = false;
      });
      return;
    }

    final List<ScanResultItem> confirmedItems = [];
    for (int i = 0; i < widget.detectedItems.length; i++) {
      final String name = _nameControllers[i].text.trim();
      final double? price = double.tryParse(_priceControllers[i].text.trim());
      final double? size = double.tryParse(_sizeControllers[i].text.trim());
      final String unit = _unitControllers[i].text.trim();

      if (name.isEmpty) {
        setState(() {
          _errorMessage = 'Nama produk Item #${i + 1} tidak boleh kosong!';
          _isSaving = false;
        });
        return;
      }

      if (price == null) {
        setState(() {
          _errorMessage = 'Harga Item #${i + 1} harus berupa angka valid!';
          _isSaving = false;
        });
        return;
      }

      confirmedItems.add(
        ScanResultItem(
          namaProduk: name,
          harga: price,
          ukuran: size,
          satuan: unit.isEmpty ? null : unit,
          kategori: _selectedCategories[i],
          confidence: widget.detectedItems[i].confidence,
          needsVerification: widget.detectedItems[i].needsVerification,
        ),
      );
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
    if (_nameControllers.length != widget.detectedItems.length) return true;

    for (int i = 0; i < widget.detectedItems.length; i++) {
      final original = widget.detectedItems[i];
      final currentName = _nameControllers[i].text;
      final currentPriceText = _priceControllers[i].text;
      final currentSizeText = _sizeControllers[i].text;
      final currentUnit = _unitControllers[i].text;
      final currentCategory = _selectedCategories[i];

      final originalName = original.namaProduk ?? '';
      final originalPrice = original.harga?.toInt().toString() ?? '';
      final originalSize = original.ukuran?.toString() ?? '';
      final originalUnit = original.satuan ?? '';
      final originalCategory = original.kategori ?? 'Lainnya';

      if (currentName != originalName ||
          currentPriceText != originalPrice ||
          currentSizeText != originalSize ||
          currentUnit != originalUnit ||
          currentCategory != originalCategory) {
        return true;
      }
    }

    final defaultStoreId = _nearbyStores.isNotEmpty ? _nearbyStores.first.storeId : '';
    final currentStoreId = _selectedStore?.storeId ?? '';
    if (currentStoreId != defaultStoreId && currentStoreId.isNotEmpty && defaultStoreId.isNotEmpty) {
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
    final bool hasBestValue = _bestValueItem != null;

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

              if (hasBestValue) ...[
                _buildBestValueHeroCard(),
                const SizedBox(height: 16),
              ],

              const Text(
                'Daftar Perbandingan Produk',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink),
              ),
              const SizedBox(height: 8),

              if (widget.detectedItems.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Tidak ada produk terdeteksi.', textAlign: TextAlign.center),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.detectedItems.length,
                  itemBuilder: (context, index) {
                    return _buildProductComparisonCard(index);
                  },
                ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              _buildStoreSelectionArea(),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                key: const Key('save_confirm_button'),
                onPressed: _isSaving || _isLoadingStores || _selectedStore == null
                    ? null
                    : _saveResults,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Simpan Hasil Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
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
