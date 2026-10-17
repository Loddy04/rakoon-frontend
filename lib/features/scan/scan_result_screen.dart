import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:rakoon_frontend/features/recommendation/recommendation_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';
import 'package:rakoon_frontend/features/scan/presentation/widgets/add_product_bottom_sheet.dart';

class ScanResultScreen extends StatefulWidget {
  final String? baseUrl;
  final List<ScanResultItem> detectedItems;
  final String? initialStoreId;
  final String? initialUserId;
  final http.Client? httpClient;

  const ScanResultScreen({
    super.key,
    this.baseUrl,
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

  String get _effectiveBaseUrl =>
      (widget.baseUrl != null && widget.baseUrl!.isNotEmpty)
          ? widget.baseUrl!
          : AppConfig.backendBaseUrl;

  // Store selection state
  bool _isLoadingStores = true;
  String? _storesError;
  LocationOutcome? _locationProblem;
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

  // Fallback coordinates (Yogyakarta / Babarsari) if GPS is disabled or unavailable
  static const double _defaultFallbackLat = -7.7829;
  static const double _defaultFallbackLng = 110.4083;

  Future<void> _fetchStoresWithFallbackCoordinates({bool openSelector = false}) async {
    setState(() {
      _isLoadingStores = true;
      _storesError = null;
    });

    try {
      final response = await StoresService.getNearbyStores(
        lat: _defaultFallbackLat,
        lng: _defaultFallbackLng,
        radiusKm: 15.0,
        baseUrl: _effectiveBaseUrl,
        client: widget.httpClient,
      );

      if (!mounted) return;

      setState(() {
        _nearbyStores = response.stores;
        if (response.stores.isNotEmpty && _selectedStore == null) {
          _selectedStore = response.stores.first;
          _storeIdController.text = response.stores.first.storeId;
        }
        _isLoadingStores = false;
        _storesError = null;
      });

      if (openSelector && mounted) {
        _showStoreSelectorBottomSheet();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _storesError = userMessage(e);
        _isLoadingStores = false;
      });
    }
  }

  Future<void> _fetchNearbyStores() async {
    setState(() {
      _isLoadingStores = true;
      _storesError = null;
      _locationProblem = null;
    });

    try {
      final result = await LocationService.resolveLocation(askPermission: true);
      if (!mounted) return;

      if (result.outcome != LocationOutcome.granted || result.position == null) {
        setState(() {
          _isLoadingStores = false;
          _selectedStore = null;
          _storeIdController.text = '';
          _locationProblem = result.outcome;
          if (result.outcome == LocationOutcome.deniedForever) {
            _storesError = 'Izin lokasi ditolak permanen di pengaturan sistem.';
          } else if (result.outcome == LocationOutcome.serviceDisabled) {
            _storesError = 'Layanan lokasi (GPS) tidak aktif.';
          } else if (result.outcome == LocationOutcome.denied) {
            _storesError = 'Izin akses lokasi ditolak.';
          } else {
            _storesError = 'Gagal mendeteksi lokasi.';
          }
        });
        return;
      }

      final position = result.position!;
      final response = await StoresService.getNearbyStores(
        lat: position.latitude,
        lng: position.longitude,
        baseUrl: _effectiveBaseUrl,
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
        _storesError = userMessage(e);
        _isLoadingStores = false;
        _selectedStore = null;
        _storeIdController.text = '';
      });
    }
  }

  String _formatRupiah(double amount) {
    return formatRp(amount);
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

  void _showAppSnackBar({
    required String message,
    bool isError = true,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF00875A),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
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
          baseUrl: _effectiveBaseUrl,
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
                                      '${ProductCard.formatDistance(store.jarakKm)} dari lokasi Anda',
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
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_locationProblem == LocationOutcome.deniedForever)
                  TextButton.icon(
                    key: const Key('btn_open_app_settings_scan'),
                    onPressed: LocationService.openAppSettings,
                    icon: const Icon(Icons.settings, size: 15),
                    label: const Text('Buka Pengaturan', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00875A),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                OutlinedButton.icon(
                  key: const Key('manual_store_select_button'),
                  onPressed: () => _fetchStoresWithFallbackCoordinates(openSelector: true),
                  icon: const Icon(Icons.storefront_outlined, size: 14),
                  label: const Text('Pilih Toko Manual', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00875A),
                    side: const BorderSide(color: Color(0xFF00875A), width: 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _fetchNearbyStores,
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
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
                      if (_selectedStore != null && ProductCard.formatDistance(_selectedStore!.jarakKm) != null)
                        Text(
                          ProductCard.formatDistance(_selectedStore!.jarakKm)!,
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

    final bool isPriceValid = price > 0;
    final bool isSizeValid = size > 0 && unit.trim().isNotEmpty;
    final bool isComplete = isPriceValid && isSizeValid;

    // Card border color:
    final Color borderColor;
    if (isWinner) {
      borderColor = const Color(0xFFF59E0B);
    } else if (!isComplete) {
      borderColor = const Color(0xFFF59E0B);
    } else {
      borderColor = const Color(0xFFE8E4DC);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isWinner ? const Color(0xFFFFFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEditBottomSheet(item),
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
                padding: EdgeInsets.fromLTRB(10, isWinner ? 6 : 10, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Number Badge Circle
                    Container(
                      width: 24,
                      height: 24,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isWinner ? Colors.white : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Title, Category & Size Pills, Price, Unit Price
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
                          const SizedBox(height: 5),

                          // Pills Kategori & Ukuran
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Kategori Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.kategori?.isNotEmpty == true
                                      ? item.kategori!
                                      : 'Kategori',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ),

                              // Ukuran Pill
                              if (isSizeValid)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${size % 1 == 0 ? size.toInt() : size.toStringAsFixed(1)} $unit',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF4B5563),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '⚠️ Isi ukuran',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Price
                          Text(
                            isPriceValid ? _formatRupiah(price) : 'Rp -',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isPriceValid
                                  ? const Color(0xFF00875A)
                                  : const Color(0xFFEF4444),
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (!isPriceValid)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 12,
                                    color: Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      'Wajib isi harga',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEF4444),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
                    const SizedBox(width: 6),

                    // 3. Right Column: Badges & Action Buttons
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge logic
                        if (!isPriceValid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFEF4444), size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  'Lengkapi Harga',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFDC2626),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (!isSizeValid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFD97706), size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  'Lengkapi Ukuran',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFB45309),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Winner Crown Badge (if isWinner)
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

                        // Actions: Edit (green) & Delete (red) uniform 38x38dp buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Edit button
                            Semantics(
                              label: 'Edit produk ${name.isNotEmpty ? name : ""}',
                              button: true,
                              container: true,
                              child: InkWell(
                                key: Key('edit_item_${itemIndex}_btn'),
                                onTap: () => _openEditBottomSheet(item),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F4EA),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF00875A),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Delete button
                            Semantics(
                              label: 'Hapus produk ${name.isNotEmpty ? name : ""}',
                              button: true,
                              container: true,
                              child: InkWell(
                                key: Key('delete_item_${itemIndex}_btn'),
                                onTap: () => _deleteItem(item),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
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
        ),
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
        _showAppSnackBar(
          message: 'Sesi login tidak valid, silakan login ulang.',
          isError: true,
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
      final confirmResult = await ScanService.confirmScan(
        storeId: storeId,
        userId: userId,
        items: confirmedItems,
        baseUrl: _effectiveBaseUrl,
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
                  if (confirmResult.itemsPendingReview > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${confirmResult.itemsPendingReview} harga menunggu verifikasi',
                      key: const Key('save_pending_review_notice'),
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB45309),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
        _errorMessage = userMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF0D2818),
              size: 24,
            ),
            onPressed: () async {
              if (_hasUnsavedChanges()) {
                final shouldPop = await _showExitConfirmationDialog(context);
                if (shouldPop == true && context.mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Hasil Scan',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D2818),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Store selection card
                      _buildStoreSelectionArea(),
                      const SizedBox(height: 10),

                      // AI Detection Header (bersih di sisi kiri saja, tanpa tombol di kanan)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8, left: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8FAF2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF00875A),
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_items.length} Produk Berhasil Dideteksi',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0D2818),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

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

                      // Full-width OutlinedButton: Tambah Produk Manual
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            key: const Key('add_product_button'),
                            onPressed: _openAddBottomSheet,
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFF00875A),
                              size: 18,
                            ),
                            label: Text(
                              'Tambah Produk Manual',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00875A),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF00875A),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Best Value AI Recommendation CTA button (only displayed if products have valid price & size)
                      Builder(
                        builder: (context) {
                          final bool hasValidBestValueCandidate = _items.any(
                            (item) =>
                                item.harga != null &&
                                item.harga! > 0 &&
                                item.ukuran != null &&
                                item.ukuran! > 0 &&
                                (item.satuan != null && item.satuan!.trim().isNotEmpty),
                          );

                          if (!hasValidBestValueCandidate) {
                            return const SizedBox.shrink();
                          }

                          return InteractiveScale(
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
                          );
                        },
                      ),

                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // Fixed Bottom Action Bar (Hanya 1 tombol utama Simpan Hasil Scan)
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
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_items.any((item) =>
                            (item.harga == null || item.harga! <= 0) ||
                            (item.ukuran == null || item.ukuran! <= 0))) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    '⚠️ Lengkapi ukuran & harga semua produk sebelum menyimpan',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFEF4444),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 48,
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
                              disabledBackgroundColor: const Color(0xFF9CA3AF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                                : Text(
                                    'Simpan Hasil Scan (${_items.length} Produk)',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
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
  late String selectedCategory;
  late String selectedUnit;
  String? _nameError;
  String? _priceError;
  String? _sizeError;

  static const List<String> standardUnits = ['gr', 'kg', 'ml', 'L', 'pcs'];

  static String _resolveUnit(String? raw) {
    if (raw == null || raw.isEmpty) return 'gr';
    final lower = raw.trim().toLowerCase();
    if (lower == 'l' || lower == 'liter' || lower == 'litre') return 'L';
    if (lower == 'ml' || lower == 'mili' || lower == 'milliliter' || lower == 'cc') return 'ml';
    if (lower == 'kg' || lower == 'kilo' || lower == 'kilogram') return 'kg';
    if (lower == 'pcs' || lower == 'piece' || lower == 'buah' || lower == 'biji' || lower == 'pack' || lower == 'bungkus') return 'pcs';
    if (lower == 'gr' || lower == 'g' || lower == 'gram') return 'gr';
    for (final u in standardUnits) {
      if (u.toLowerCase() == lower) return u;
    }
    return 'gr';
  }

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item.namaProduk ?? '');
    priceController = TextEditingController(
      text: widget.item.harga != null && widget.item.harga! > 0
          ? (widget.item.harga! % 1 == 0
              ? widget.item.harga!.toInt().toString()
              : widget.item.harga!.toString())
          : '',
    );
    sizeController = TextEditingController(
      text: widget.item.ukuran != null && widget.item.ukuran! > 0
          ? (widget.item.ukuran! % 1 == 0
              ? widget.item.ukuran!.toInt().toString()
              : widget.item.ukuran!.toString())
          : '',
    );
    selectedUnit = _resolveUnit(widget.item.satuan);
    selectedCategory = widget.item.kategori ?? 'Lainnya';
    if (!productCategories.contains(selectedCategory)) {
      selectedCategory = 'Lainnya';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    sizeController.dispose();
    super.dispose();
  }

  void _saveItem() {
    final name = nameController.text.trim();
    final priceText = priceController.text.trim();
    final sizeText = sizeController.text.trim();

    String? nameErr;
    String? priceErr;
    String? sizeErr;

    if (name.isEmpty) {
      nameErr = 'Nama produk wajib diisi';
    }

    final cleanPriceText = priceText.replaceAll('.', '').replaceAll(',', '').replaceAll(' ', '');
    final parsedPrice = double.tryParse(cleanPriceText);
    if (cleanPriceText.isEmpty || parsedPrice == null || parsedPrice <= 0 || parsedPrice.isNaN || parsedPrice.isInfinite) {
      priceErr = 'Harga wajib diisi (lebih dari Rp 0)';
    }

    final cleanSizeText = sizeText.replaceAll(',', '.').trim();
    final parsedSize = double.tryParse(cleanSizeText);
    if (cleanSizeText.isEmpty || parsedSize == null || parsedSize <= 0 || parsedSize.isNaN || parsedSize.isInfinite) {
      sizeErr = 'Ukuran wajib diisi';
    }

    if (nameErr != null || priceErr != null || sizeErr != null) {
      setState(() {
        _nameError = nameErr;
        _priceError = priceErr;
        _sizeError = sizeErr;
      });
      return;
    }

    widget.item.namaProduk = name;
    widget.item.harga = parsedPrice;
    widget.item.ukuran = parsedSize;
    widget.item.satuan = selectedUnit;
    widget.item.kategori = selectedCategory;

    widget.onSaved();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Drag handle pill (lebar 40dp, tinggi 4dp, warna #D1D5DB, borderRadius 2)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header Row: Judul & tombol tutup bundar lembut di kanan
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
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Nama Produk
                Text(
                  'Nama Produk',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_name_field'),
                  controller: nameController,
                  onChanged: (val) {
                    if (_nameError != null) {
                      setState(() {
                        _nameError = null;
                      });
                    }
                  },
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0D2818)),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Indomie Goreng',
                    hintStyle: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF9CA3AF)),
                    errorText: _nameError,
                    errorStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _nameError != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _nameError != null ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Kategori Dropdown
                Text(
                  'Kategori',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('edit_category_dropdown'),
                  initialValue: selectedCategory,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                    ),
                  ),
                  items: productCategories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(
                        cat,
                        style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0D2818)),
                      ),
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
                const SizedBox(height: 14),

                // 5. Harga
                Text(
                  'Harga',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_price_field'),
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    if (_priceError != null) {
                      setState(() {
                        _priceError = null;
                      });
                    }
                  },
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0D2818)),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF9CA3AF)),
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D2818),
                    ),
                    errorText: _priceError,
                    errorStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _priceError != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _priceError != null ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Baris Ukuran & Satuan (Berdampingan)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kolom Kiri: Ukuran (flex 3)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ukuran',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const Key('edit_size_field'),
                            controller: sizeController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              if (_sizeError != null) {
                                setState(() {
                                  _sizeError = null;
                                });
                              }
                            },
                            style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0D2818)),
                            decoration: InputDecoration(
                              hintText: 'Contoh: 200',
                              hintStyle: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF9CA3AF)),
                              errorText: _sizeError,
                              errorStyle: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFFEF4444),
                                fontWeight: FontWeight.w500,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _sizeError != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _sizeError != null ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Kolom Kanan: Satuan (flex 2)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satuan',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const Key('edit_unit_dropdown'),
                            initialValue: selectedUnit,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                              ),
                            ),
                            items: standardUnits.map((u) {
                              return DropdownMenuItem<String>(
                                value: u,
                                child: Text(
                                  u,
                                  style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0D2818)),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedUnit = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Warning Box jika ada error validasi
                if (_nameError != null || _priceError != null || _sizeError != null) ...[
                  Container(
                    key: const Key('edit_validation_warning_box'),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mohon periksa kembali kolom yang belum terisi dengan benar.',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tombol Simpan Perubahan
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('save_edit_button'),
                    onPressed: _saveItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Simpan Perubahan',
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
      ),
    );
  }
}

typedef _AddProductBottomSheet = AddProductBottomSheet;
