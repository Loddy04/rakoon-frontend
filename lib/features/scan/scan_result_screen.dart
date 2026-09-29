import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:rakoon_frontend/features/history/data/repositories/price_history_repository.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/price_history_page.dart';
import 'package:rakoon_frontend/features/history/presentation/providers/price_history_notifier.dart';
import 'package:rakoon_frontend/features/recommendation/recommendation_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';

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
  bool _isDialogShowing = false;
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
        client: widget.httpClient,
      );

      if (!mounted) return;

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
      if (!mounted) return;
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

  double _calculateTotal() {
    double total = 0.0;
    for (final item in _items) {
      if (item.harga != null && item.harga! > 0) {
        total += item.harga!;
      }
    }
    return total;
  }

  double? _calculateUnitPrice(ScanResultItem item) {
    if (item.harga != null &&
        item.harga! > 0 &&
        item.ukuran != null &&
        item.ukuran! > 0) {
      return item.harga! / item.ukuran!;
    }
    return null;
  }

  int _findBestValueWinnerIndex() {
    if (_items.length < 2) return -1;
    int bestIdx = -1;
    double minUnitPrice = double.infinity;
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final up = _calculateUnitPrice(item);
      if (up != null && up < minUnitPrice) {
        minUnitPrice = up;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  void _openEditBottomSheet(ScanResultItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _EditProductBottomSheet(
          item: item,
          onSaved: () {
            setState(() {
              _errorMessage = null;
            });
          },
        );
      },
    );
  }

  void _openAddBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _AddProductBottomSheet(
          onAdded: (newItem) {
            setState(() {
              _items.add(newItem);
              _errorMessage = null;
            });
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
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Hapus Produk',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D2818),
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${item.namaProduk ?? 'Produk'}" dari hasil scan?',
          style: GoogleFonts.outfit(color: const Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.outfit(color: const Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            key: const Key('confirm_delete_button'),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _items.remove(item);
                _errorMessage = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
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

  Future<void> _showValidationErrorDialog(List<String> errorMessages) async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Data Produk Belum Lengkap',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D2818),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lengkapi data berikut sebelum menyimpan hasil scan:',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8E4DC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: errorMessages.map((msg) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ',
                                        style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                        msg,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: const Color(0xFF0D2818),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    key: const Key('validation_dialog_inspect_btn'),
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Periksa Produk',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('validation_dialog_close_btn'),
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'Tutup',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _isDialogShowing = false;
    }
  }

  void _showStoreSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pilih Lokasi Toko',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D2818),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih toko terdekat tempat Anda memindai harga produk.',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _nearbyStores.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final store = _nearbyStores[index];
                      final isSelected =
                          _selectedStore?.storeId == store.storeId;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedStore = store;
                            _storeIdController.text = store.storeId;
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE8FAF2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00A86B)
                                  : const Color(0xFFE8E4DC),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFFAF7F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFA7F3D0)
                                        : const Color(0xFFE8E4DC),
                                  ),
                                ),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  color: isSelected
                                      ? const Color(0xFF00875A)
                                      : const Color(0xFF6B7280),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      store.nama,
                                      style: GoogleFonts.outfit(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF00875A)
                                            : const Color(0xFF0D2818),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${store.jarakKm.toStringAsFixed(1)} km dari lokasi Anda',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF6B7280),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF00A86B),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getStoreLogoWidget() {
    final storeName = _selectedStore?.nama;
    final asset = BrandAssets.getStoreAsset(storeName);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.storefront_rounded,
          color: Color(0xFF00875A),
          size: 22,
        ),
      );
    }
    return const Icon(
      Icons.storefront_rounded,
      color: Color(0xFF00875A),
      size: 22,
    );
  }

  Widget _buildStoreSelectionArea() {
    if (_isLoadingStores) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E4DC)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00875A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mencari toko terdekat...',
                style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      );
    }

    if (_storesError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal memuat toko: $_storesError',
                    style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _fetchNearbyStores,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      key: const Key('store_selector_card'),
      onTap: _showStoreSelectorBottomSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Store Logo / Icon Container
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
              ),
              child: _getStoreLogoWidget(),
            ),
            const SizedBox(width: 10),

            // Store Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedStore?.nama ?? 'Pilih Toko Terdekat',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF00875A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (_selectedStore != null)
                        Text(
                          '${_selectedStore!.jarakKm.toStringAsFixed(1)} km',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8F4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD1E7DD), width: 0.8),
                        ),
                        child: Text(
                          'Otomatis',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF166534),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Ubah Toko outline pill button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00A86B), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_outlined, color: Color(0xFF00A86B), size: 12),
                  const SizedBox(width: 3),
                  Text(
                    'Ubah Toko',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF00A86B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final double? unitPrice = _calculateUnitPrice(item);
    final bool isWinner = itemIndex == _findBestValueWinnerIndex();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isWinner ? const Color(0xFFFFFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner
              ? const Color(0xFFF59E0B)
              : (item.needsVerification
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFE8E4DC)),
          width: isWinner ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If Best Value Winner: show top badge ribbon
          if (isWinner)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'BEST VALUE WINNER',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.fromLTRB(10, isWinner ? 6 : 9, 10, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Number Badge Circle (NO PRODUCT IMAGE!)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isWinner
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isWinner
                          ? const Color(0xFFD97706)
                          : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${itemIndex + 1}',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isWinner ? Colors.white : const Color(0xFF4B5563),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Title, Category, Size, Price, Unit Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Produk #${itemIndex + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D2818),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.kategori ?? "Kategori"}\n${size > 0 ? (size % 1 == 0 ? size.toInt() : size.toStringAsFixed(1)) : "-"} $unit',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          color: const Color(0xFF6B7280),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price > 0 ? _formatRupiah(price) : 'Rp -',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF00875A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (unitPrice != null)
                        Text(
                          'Rp ${unitPrice.toStringAsFixed(1).replaceAll('.', ',')} / $unit',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // 3. Right Column: Badges & Action Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Accuracy or Verification Badge
                    if (item.needsVerification)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFD97706), size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  'Verifikasi Harga',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFD97706),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Harga mungkin beda',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF9CA3AF),
                              fontSize: 8,
                              height: 1.1,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8FAF2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981), size: 11),
                            const SizedBox(width: 3),
                            Text(
                              'Akurat ${item.confidence == "tinggi" ? "98%" : "85%"}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF059669),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Winner Crown Badge
                    if (isWinner) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium_rounded,
                                color: Color(0xFFD97706), size: 13),
                            const SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Termurah',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFB45309),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'di produk sejenis!',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFB45309),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Actions: Delete, Edit
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Delete button (accessible hit area >= 48x48)
                        Semantics(
                          label: 'Hapus produk ${name.isNotEmpty ? name : ""}',
                          button: true,
                          container: true,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              key: Key('delete_item_${itemIndex}_btn'),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Color(0xFFEF4444),
                              ),
                              tooltip: 'Hapus produk',
                              onPressed: () => _deleteItem(item),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),

                        // Edit button (accessible hit area >= 48x48)
                        Semantics(
                          label: 'Edit produk ${name.isNotEmpty ? name : ""}',
                          button: true,
                          container: true,
                          child: OutlinedButton(
                            key: Key('edit_item_${itemIndex}_btn'),
                            onPressed: () => _openEditBottomSheet(item),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(54, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_outlined,
                                    size: 12, color: Color(0xFF4B5563)),
                                const SizedBox(width: 3),
                                Text(
                                  'Edit',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveResults() async {
    if (_isSaving || _isDialogShowing) return;

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
            backgroundColor: Color(0xFFEF4444),
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

    if (_items.isEmpty) {
      setState(() {
        _errorMessage = 'Tidak ada produk untuk disimpan.';
        _isSaving = false;
      });
      return;
    }

    final List<String> errorMessages = [];
    final List<ScanResultItem> confirmedItems = [];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final String name = (item.namaProduk ?? '').trim();
      final double? price = item.harga;
      final double? size = item.ukuran;
      final String unit = (item.satuan ?? '').trim();
      final String category = (item.kategori ?? '').trim();

      final List<String> missing = [];
      if (name.isEmpty) missing.add('nama produk');
      if (price == null || price <= 0 || price.isNaN || price.isInfinite) {
        missing.add('harga');
      }
      if (size == null || size <= 0 || size.isNaN || size.isInfinite) {
        missing.add('ukuran');
      }
      if (unit.isEmpty) missing.add('satuan');
      if (category.isEmpty) missing.add('kategori');

      if (missing.isNotEmpty) {
        final String itemLabel = name.isNotEmpty ? name : 'Produk #${i + 1}';
        final String fieldsText = missing.length == 1
            ? '${missing.first} belum diisi'
            : (missing.length == 2
                ? '${missing[0]} dan ${missing[1]} belum diisi'
                : '${missing.sublist(0, missing.length - 1).join(', ')} dan ${missing.last} belum diisi');
        errorMessages.add('$itemLabel - $fieldsText.');
      } else {
        confirmedItems.add(item);
      }
    }

    if (errorMessages.isNotEmpty) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        await _showValidationErrorDialog(errorMessages);
      }
      return;
    }

    try {
      await ScanService.confirmScan(
        storeId: storeId,
        userId: userId,
        items: confirmedItems,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8FAF2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF00A86B),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Simpan Berhasil',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D2818),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hasil scan berhasil disimpan.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('save_success_done_button'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00875A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Selesai',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _checkAndNavigateToHistory(String productName) async {
    if (productName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama produk tidak boleh kosong.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00875A)),
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
              backgroundColor: const Color(0xFFF59E0B),
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
            backgroundColor: const Color(0xFFEF4444),
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

    final initialDetectedStoreId =
        _nearbyStores.isNotEmpty ? _nearbyStores.first.storeId : '';
    final currentStoreId = _selectedStore?.storeId ?? '';
    if (currentStoreId != initialDetectedStoreId &&
        currentStoreId.isNotEmpty &&
        initialDetectedStoreId.isNotEmpty) {
      return true;
    }

    return false;
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Keluar Halaman',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D2818),
          ),
        ),
        content: Text(
          'Keluar dari halaman ini? Perubahan Anda akan hilang.',
          style: GoogleFonts.outfit(color: const Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.outfit(color: const Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text(
              'Keluar',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
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
        backgroundColor: const Color(0xFFFAF7F2), // Matches Home background
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF7F2),
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 50,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF0D2818),
              size: 24,
            ),
            onPressed: () async {
              if (_hasUnsavedChanges()) {
                final shouldPop = await _showExitConfirmationDialog(context);
                if (shouldPop == true && mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const SizedBox(
            height: 0,
            width: 0,
            child: Text(
              'Koreksi Hasil Scan',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8E4DC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lightbulb_rounded,
                      color: Color(0xFFF59E0B),
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Harga dapat berbeda\nsetiap toko dan lokasi',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        color: const Color(0xFF6B7280),
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title & Subtitle Section
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hasil Scan & Deteksi AI',
                              style: GoogleFonts.outfit(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0D2818),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Berikut produk yang berhasil dikenali dari rak belanja',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Store selection card
                      _buildStoreSelectionArea(),
                      const SizedBox(height: 8),

                      // Detection summary card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE8E4DC),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_items.length} produk berhasil dideteksi',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0D2818),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Cek hasil dan bandingkan harga sebelum belanja',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF00A86B),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.refresh_rounded,
                                      color: Color(0xFF00A86B),
                                      size: 13,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Scan Lagi',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF00A86B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Error message if any
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Products list
                      if (_items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8E4DC)),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.inbox_outlined,
                                size: 40,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Tidak ada produk terdeteksi. Silakan tambah produk secara manual.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._items.map((item) => _buildProductComparisonCard(item)),

                      // Best Value AI Recommendation CTA button
                      InteractiveScale(
                        key: const Key('best_value_cta_button'),
                        onTap: _evaluateBestValue,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                color: Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Analisis Best Value AI',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                    Text(
                                      'Bandingkan nilai per satuan ukuran produk secara mendalam',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFD97706),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // Fixed Bottom Action Bar (Tambah Produk Manual & Simpan Hasil Scan)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        // Left: Tambah Produk Manual Button
                        Expanded(
                          flex: 5,
                          child: OutlinedButton(
                            key: const Key('add_product_button'),
                            onPressed: _openAddBottomSheet,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF00A86B),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: Color(0xFF00A86B),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Tambah Produk',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF00A86B),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right: Simpan Hasil Scan Button
                        Expanded(
                          flex: 6,
                          child: ElevatedButton(
                            key: const Key('save_confirm_button'),
                            onPressed: _isSaving ||
                                    _isLoadingStores ||
                                    _selectedStore == null ||
                                    _items.isEmpty
                                ? null
                                : _saveResults,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00875A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Simpan Hasil Scan',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${_items.length} produk · Total ${_formatRupiah(_calculateTotal())}',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white
                                                    .withValues(alpha: 0.9),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
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
}

class _EditProductBottomSheet extends StatefulWidget {
  final ScanResultItem item;
  final VoidCallback onSaved;

  const _EditProductBottomSheet({
    required this.item,
    required this.onSaved,
  });

  @override
  State<_EditProductBottomSheet> createState() =>
      _EditProductBottomSheetState();
}

class _EditProductBottomSheetState extends State<_EditProductBottomSheet> {
  late final TextEditingController nameController;
  late final TextEditingController priceController;
  late final TextEditingController sizeController;
  late final TextEditingController unitController;
  late String selectedCategory;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item.namaProduk ?? '');
    priceController = TextEditingController(
      text: widget.item.harga != null
          ? (widget.item.harga! % 1 == 0
              ? widget.item.harga!.toInt().toString()
              : widget.item.harga!.toString())
          : '',
    );
    sizeController = TextEditingController(
      text: widget.item.ukuran != null
          ? (widget.item.ukuran! % 1 == 0
              ? widget.item.ukuran!.toInt().toString()
              : widget.item.ukuran!.toString())
          : '',
    );
    unitController = TextEditingController(text: widget.item.satuan ?? '');
    selectedCategory = widget.item.kategori ?? 'Lainnya';
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    sizeController.dispose();
    unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D2818),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE8E4DC)),
          const SizedBox(height: 12),

          TextField(
            key: const Key('edit_name_field'),
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Nama Produk',
              labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            key: const Key('edit_category_dropdown'),
            initialValue: selectedCategory,
            decoration: InputDecoration(
              labelText: 'Kategori',
              labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
              ),
            ),
            items: productCategories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat,
                child: Text(cat, style: GoogleFonts.outfit(fontSize: 13.5)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
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
            decoration: InputDecoration(
              labelText: 'Harga (Rupiah)',
              labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
              ),
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
                  decoration: InputDecoration(
                    labelText: 'Ukuran',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('edit_unit_field'),
                  controller: unitController,
                  decoration: InputDecoration(
                    labelText: 'Satuan',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                    ),
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
                  const SnackBar(
                      content: Text('Nama produk tidak boleh kosong.')),
                );
                return;
              }

              final parsedPrice = double.tryParse(priceText);
              if (parsedPrice == null || parsedPrice <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Harga harus lebih besar dari 0.')),
                );
                return;
              }

              final parsedSize = double.tryParse(sizeText);
              if (parsedSize == null || parsedSize <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ukuran harus lebih besar dari 0.')),
                );
                return;
              }

              final allowedUnits = [
                'ml',
                'mili',
                'milliliter',
                'cc',
                'l',
                'liter',
                'litre',
                'g',
                'gr',
                'gram',
                'kg',
                'kilo',
                'kilogram',
                'pcs',
                'piece',
                'pieces',
                'buah',
                'biji',
                'pack',
                'bungkus'
              ];
              if (unit.isEmpty || !allowedUnits.contains(unit)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Satuan tidak didukung. Gunakan ml, l, g, kg, pcs, dll.')),
                );
                return;
              }

              widget.item.namaProduk = name;
              widget.item.harga = parsedPrice;
              widget.item.ukuran = parsedSize;
              widget.item.satuan = unit;
              widget.item.kategori = selectedCategory;

              widget.onSaved();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00875A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Simpan Perubahan',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddProductBottomSheet extends StatefulWidget {
  final ValueChanged<ScanResultItem> onAdded;

  const _AddProductBottomSheet({
    required this.onAdded,
  });

  @override
  State<_AddProductBottomSheet> createState() => _AddProductBottomSheetState();
}

class _AddProductBottomSheetState extends State<_AddProductBottomSheet> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final sizeController = TextEditingController();
  final unitController = TextEditingController();
  String selectedCategory = 'Makanan Pokok';

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    sizeController.dispose();
    unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D2818),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE8E4DC)),
          const SizedBox(height: 12),

          TextField(
            key: const Key('add_name_field'),
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Nama Produk',
              labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            key: const Key('add_category_dropdown'),
            initialValue: selectedCategory,
            decoration: InputDecoration(
              labelText: 'Kategori',
              labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
              ),
            ),
            items: productCategories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat,
                child: Text(cat, style: GoogleFonts.outfit(fontSize: 13.5)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
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
            decoration: InputDecoration(
              labelText: 'Harga (Rupiah)',
              labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
              ),
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
                  decoration: InputDecoration(
                    labelText: 'Ukuran',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('add_unit_field'),
                  controller: unitController,
                  decoration: InputDecoration(
                    labelText: 'Satuan',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                    ),
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
                  const SnackBar(
                      content: Text('Nama produk tidak boleh kosong.')),
                );
                return;
              }

              final parsedPrice = double.tryParse(priceText);
              if (parsedPrice == null || parsedPrice <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Harga harus lebih besar dari 0.')),
                );
                return;
              }

              final parsedSize = double.tryParse(sizeText);
              if (parsedSize == null || parsedSize <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ukuran harus lebih besar dari 0.')),
                );
                return;
              }

              final allowedUnits = [
                'ml',
                'mili',
                'milliliter',
                'cc',
                'l',
                'liter',
                'litre',
                'g',
                'gr',
                'gram',
                'kg',
                'kilo',
                'kilogram',
                'pcs',
                'piece',
                'pieces',
                'buah',
                'biji',
                'pack',
                'bungkus'
              ];
              if (unit.isEmpty || !allowedUnits.contains(unit)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Satuan tidak didukung. Gunakan ml, l, g, kg, pcs, dll.')),
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

              widget.onAdded(newItem);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00875A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Tambah Produk',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
