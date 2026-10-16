import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/widgets/price_freshness_label.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';
import 'package:rakoon_frontend/widgets/rakoon_location_map.dart';

class NearbyStoresScreen extends StatefulWidget {
  final String baseUrl;
  final double? initialLat;
  final double? initialLng;
  final http.Client? httpClient;

  const NearbyStoresScreen({
    super.key,
    required this.baseUrl,
    this.initialLat,
    this.initialLng,
    this.httpClient,
  });

  @override
  State<NearbyStoresScreen> createState() => _NearbyStoresScreenState();
}

class _NearbyStoresScreenState extends State<NearbyStoresScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _isLoading = true;
  String? _errorMessage;
  // Bukan granted = tidak ada lokasi: tanpa panggilan toko, daftar, atau marker lokasi pengguna.
  LocationOutcome? _locationProblem;
  // True selama permintaan lokasi/izin atau pemuatan toko berjalan: tombol dan resume diabaikan.
  bool _requesting = false;

  Position? _userPosition;
  NearbyStoresResponse? _storesResponse;
  StoreNearby? _selectedStore;
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Satu-satunya permintaan izin otomatis; berikutnya hanya lewat tombol "Izinkan lokasi".
    _fetchLocationAndStores(askPermission: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final problem = _locationProblem;
    if (state == AppLifecycleState.resumed &&
        !_requesting &&
        problem != null &&
        problem != LocationOutcome.failed) {
      _recheckLocationOnResume();
    }
  }

  /// Resume (mis. kembali dari pengaturan): periksa status tanpa dialog izin, dan muat ulang hanya
  /// bila statusnya berubah dari hasil terakhir.
  Future<void> _recheckLocationOnResume() async {
    _requesting = true;
    try {
      final result = await LocationService.resolveLocation(askPermission: false);
      if (!mounted || result.outcome == _locationProblem) return;
      _startLoading();
      await _showLocationResult(result);
    } finally {
      _requesting = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheetController.dispose();
    super.dispose();
  }

  /// Sanitizes address by removing raw Google Plus Code prefixes (e.g. "6C8F+HW7, ").
  static String cleanAddress(String? rawAddress) {
    if (rawAddress == null || rawAddress.trim().isEmpty) {
      return 'Sekitar Lokasi Anda';
    }
    var cleaned = rawAddress.trim();
    final plusCodeRegex = RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,5},?\s*', caseSensitive: false);
    cleaned = cleaned.replaceFirst(plusCodeRegex, '').trim();
    if (cleaned.isEmpty) {
      return 'Sekitar Lokasi Anda';
    }
    return cleaned;
  }

  /// Launches Google Maps navigation route to the destination store.
  Future<void> _launchRoute(double lat, double lng, String storeName) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka rute ke $storeName', style: GoogleFonts.outfit()),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka aplikasi navigasi', style: GoogleFonts.outfit()),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Centers the map on the store and scrolls the card into view if needed.
  void _scrollToStore(StoreNearby store) {
    setState(() => _selectedStore = store);
    _mapController.move(
      LatLng(store.lat - 0.005, store.lng),
      _mapController.camera.zoom,
    );

    // Expand sheet to a comfortable viewing position (0.38) so active store card is completely visible without clipping
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.38,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _cardKeys[store.storeId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.0,
        );
      }
    });
  }

  void _startLoading() {
    _cardKeys.clear();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _locationProblem = null;
      _selectedStore = null;
    });
  }

  /// Gets location and queries the backend for stores. [askPermission] hanya true saat layar dibuka
  /// dan lewat tombol "Izinkan lokasi"; abaikan bila permintaan lain sedang berjalan.
  Future<void> _fetchLocationAndStores({bool askPermission = false}) async {
    if (_requesting) return;
    _requesting = true;
    try {
      _startLoading();
      // initialLat/initialLng dari pemanggil diabaikan: Home meneruskan titik bawaan saat lokasi belum
      // terdeteksi, dan layar ini tidak boleh memakai koordinat bawaan.
      final result = await LocationService.resolveLocation(askPermission: askPermission);
      if (!mounted) return;
      await _showLocationResult(result);
    } finally {
      _requesting = false;
    }
  }

  Future<void> _showLocationResult(LocationResult result) async {
    try {
      final position = result.position;
      if (result.outcome != LocationOutcome.granted || position == null) {
        setState(() {
          _locationProblem = result.outcome == LocationOutcome.granted ? LocationOutcome.failed : result.outcome;
          _userPosition = null;
          _storesResponse = null;
          _isLoading = false;
        });
        return;
      }
      _userPosition = position;

      final response = await StoresService.getNearbyStores(
        lat: position.latitude,
        lng: position.longitude,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );

      if (!mounted) return;
      setState(() {
        _storesResponse = response;
        if (response.stores.isNotEmpty) {
          _selectedStore = response.stores.first;
        }
        _isLoading = false;
      });

      // Position camera so pins are in the visible upper area above the bottom sheet
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(
          LatLng(position.latitude - 0.007, position.longitude),
          13.5,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = userMessage(e);
        _isLoading = false;
      });
    }
  }

  static String _formatStoreProductTimestamp(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Tersedia di Rak';
    }
    final trimmed = raw.trim();
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      return trimmed;
    }

    final now = DateTime.now();
    final diff = now.difference(parsed.toLocal());

    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Baru saja';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    }
    if (diff.inDays == 1) {
      return 'Kemarin';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    }
    if (diff.inDays < 30) {
      final weeks = diff.inDays ~/ 7;
      return '$weeks minggu lalu';
    }

    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final monthStr = (parsed.month >= 1 && parsed.month <= 12)
        ? months[parsed.month]
        : '${parsed.month}';
    return '${parsed.day} $monthStr';
  }

  /// Displays store detail modal bottom sheet with search and route navigation.
  void _showStoreDetail(BuildContext context, StoreNearby store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      backgroundColor: Colors.white,
      builder: (modalContext) {
        String searchQuery = '';
        final searchController = TextEditingController();

        // Infinite scroll state: a full page (== limit) means there may be more.
        final products = <StoreProductItem>[];
        var hasMore = false;
        var loadingMore = false;
        String? moreError;
        StateSetter? setSheet;

        final firstPage = StoresService.getStoreProducts(
          storeId: store.storeId,
          baseUrl: widget.baseUrl,
          client: widget.httpClient,
        ).then((items) {
          products.addAll(items);
          hasMore = items.length >= StoresService.storeProductsPageSize;
          return items;
        });

        Future<void> loadMore() async {
          if (loadingMore || !hasMore) return;
          loadingMore = true;
          moreError = null;
          if (modalContext.mounted) setSheet?.call(() {});
          try {
            final items = await StoresService.getStoreProducts(
              storeId: store.storeId,
              baseUrl: widget.baseUrl,
              offset: products.length,
              client: widget.httpClient,
            );
            products.addAll(items);
            hasMore = items.length >= StoresService.storeProductsPageSize;
          } catch (_) {
            moreError = 'Gagal memuat produk berikutnya. Periksa koneksi lalu coba lagi.';
          }
          loadingMore = false;
          if (!modalContext.mounted) return;
          setSheet?.call(() {});
          // The search box filters loaded items only, so keep fetching while it is in use.
          if (searchQuery.isNotEmpty && hasMore && moreError == null) loadMore();
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            setSheet = setModalState;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top drag handle indicator
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Flexible(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 400) {
                            loadMore();
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header: Logo, Store Name, Distance & Close 'X' button
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BrandAssets.buildStoreLogo(store.nama, size: 44, borderRadius: 12),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        store.nama,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18.0,
                                          color: const Color(0xFF0D2818),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${store.jarakKm.toStringAsFixed(2)} km dari lokasi Anda',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: const Color(0xFF059669),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 22),
                                  onPressed: () => Navigator.pop(context),
                                  tooltip: 'Tutup',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFFE8E4DC), height: 1),
                            const SizedBox(height: 12),

                            // Store Address (Cleaned from Plus Code)
                            _buildDetailRow(
                              Icons.location_on_outlined,
                              'Alamat Toko',
                              cleanAddress(store.alamat),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFE8E4DC), height: 1),
                            const SizedBox(height: 14),

                            // Section: List Barang yang Dijual di Toko Ini
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF059669), size: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Daftar Produk di Toko Ini',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0D2818),
                                        ),
                                      ),
                                      Text(
                                        'Ketersediaan & update harga terkini',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Instant Product Search Bar
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(14.0),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: TextField(
                                controller: searchController,
                                onChanged: (val) {
                                  setModalState(() {
                                    searchQuery = val.trim();
                                  });
                                  if (searchQuery.isNotEmpty) loadMore();
                                },
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D2818),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Cari produk di toko ini...',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF059669),
                                    size: 18,
                                  ),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                          onPressed: () {
                                            searchController.clear();
                                            setModalState(() {
                                              searchQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // FutureBuilder for store products
                            FutureBuilder<List<StoreProductItem>>(
                              future: firstPage,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24.0),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF059669),
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  );
                                }

                                final items = products;
                                if (items.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    child: Text(
                                      'Belum ada data barang di toko ini.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 12),
                                    ),
                                  );
                                }

                                final filtered = items.where((item) {
                                  if (searchQuery.isEmpty) return true;
                                  final q = searchQuery.toLowerCase();
                                  return item.nama.toLowerCase().contains(q) ||
                                      item.kategori.toLowerCase().contains(q);
                                }).toList();

                                if (filtered.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    child: Text(
                                      'Tidak ada produk yang cocok dengan "$searchQuery"',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 12),
                                    ),
                                  );
                                }

                                return Column(children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (context, idx) => const Divider(height: 12, color: Color(0xFFF3F4F6)),
                                  itemBuilder: (context, idx) {
                                    final item = filtered[idx];
                                    final resolvedUrl = BrandAssets.resolveImageUrl(item.fotoUrl);
                                    final assetPath = BrandAssets.getProductAsset(item.nama);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFAF7F2),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE8E4DC)),
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: resolvedUrl != null
                                                  ? Image.network(
                                                      resolvedUrl,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context, error, stackTrace) =>
                                                          assetPath != null
                                                              ? Image.asset(assetPath, fit: BoxFit.contain)
                                                              : const Icon(Icons.inventory_2_outlined, color: Color(0xFF059669), size: 22),
                                                    )
                                                  : (assetPath != null
                                                      ? Image.asset(assetPath, fit: BoxFit.contain)
                                                      : const Icon(Icons.inventory_2_outlined, color: Color(0xFF059669), size: 22)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.nama,
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: const Color(0xFF0D2818),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    if (item.ukuran != null && item.satuan != null) ...[
                                                      Text(
                                                        '${item.ukuran!.toStringAsFixed(0)} ${item.satuan} · ',
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 10.5,
                                                          color: const Color(0xFF6B7280),
                                                        ),
                                                      ),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        item.kategori,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 10.5,
                                                          color: const Color(0xFF059669),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                formatRp(item.harga),
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13.5,
                                                  color: const Color(0xFF059669),
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              if (item.stale)
                                                PriceFreshnessLabel(
                                                  isStale: item.stale,
                                                  updatedAt: item.updatedAt,
                                                )
                                              else
                                                Text(
                                                  _formatStoreProductTimestamp(item.updatedAt),
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF9CA3AF),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (moreError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      children: [
                                        Text(
                                          moreError!,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 12),
                                        ),
                                        TextButton(onPressed: loadMore, child: const Text('Coba lagi')),
                                      ],
                                    ),
                                  )
                                else if (loadingMore)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                                    ),
                                  ),
                                ]);
                              },
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),

                    // Pinned Primary Action Button: Buka Rute
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFE8E4DC))),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchRoute(store.lat, store.lng, store.nama),
                          icon: const Icon(Icons.directions_rounded, size: 18, color: Colors.white),
                          label: Text(
                            'Buka Rute',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D2818),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D2818),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = !_isLoading && _userPosition != null && _storesResponse != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        titleSpacing: 0,
        leading: const BackButton(color: Color(0xFF0D2818)),
        title: Text(
          'Toko Sekitar',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF0D2818),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D2818),
        actions: const [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE8E4DC), height: 1.0),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingWidget()
            : _locationProblem != null
                ? _buildLocationProblemWidget()
                : _errorMessage != null
                ? _buildErrorWidget()
                : hasData
                    ? _buildMainLayout()
                    : const SizedBox.shrink(),
      ),
    );
  }

  /// Renders loading spinner and message
  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: Color(0xFF0D2818),
              strokeWidth: 2.8,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mencari koordinat & toko terdekat...',
            style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Keadaan tanpa lokasi (izin ditolak/permanen, layanan mati, gagal): teks ramah + satu tombol aksi.
  Widget _buildLocationProblemWidget() {
    final problem = _locationProblem!;
    final String title;
    final String body;
    final String actionLabel;
    final VoidCallback onAction;
    switch (problem) {
      case LocationOutcome.deniedForever:
        title = 'Izin lokasi diperlukan untuk melihat toko terdekat';
        body = 'Izin lokasi dimatikan di pengaturan. Aktifkan izin lokasi untuk Rakoon, lalu kembali ke sini.';
        actionLabel = 'Buka pengaturan';
        onAction = LocationService.openAppSettings;
        break;
      case LocationOutcome.serviceDisabled:
        title = 'Aktifkan layanan lokasi';
        body = 'Nyalakan GPS perangkat Anda agar kami bisa menampilkan toko di sekitar Anda.';
        actionLabel = 'Coba lagi';
        onAction = _fetchLocationAndStores;
        break;
      case LocationOutcome.failed:
        title = 'Lokasi belum terdeteksi';
        body = 'Kami belum berhasil mengambil lokasi Anda. Coba lagi sebentar lagi.';
        actionLabel = 'Coba lagi';
        onAction = _fetchLocationAndStores;
        break;
      case LocationOutcome.denied:
      case LocationOutcome.granted:
        title = 'Izin lokasi diperlukan untuk melihat toko terdekat';
        body = 'Izinkan akses lokasi agar kami bisa menampilkan toko di sekitar Anda.';
        actionLabel = 'Izinkan lokasi';
        onAction = () => _fetchLocationAndStores(askPermission: true);
        break;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 64, color: AppColors.muted),
            const SizedBox(height: AppSpacing.l),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.titleSmall),
            const SizedBox(height: AppSpacing.s),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              key: const Key('nearby_location_action_button'),
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders clean error state box
  Widget _buildErrorWidget() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Terjadi Kesalahan',
                style: GoogleFonts.dmSerifDisplay(
                  color: const Color(0xFF991B1B),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage ?? 'Gagal memuat data.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: const Color(0xFF7F1D1D)),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _fetchLocationAndStores,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Coba Lagi', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders main screen with full-area map and flexible DraggableScrollableSheet
  Widget _buildMainLayout() {
    final response = _storesResponse!;
    final stores = response.stores;
    final isFallback = response.source == 'local_fallback';
    final hasWarningMsg = response.message != null && response.message!.isNotEmpty;
    final warningText = hasWarningMsg ? response.message! : '';

    return Stack(
      children: [
        // 1. Full-area Map
        Positioned.fill(
          child: RakoonLocationMap(
            userLat: _userPosition!.latitude,
            userLng: _userPosition!.longitude,
            mapController: _mapController,
            heroTag: 'nearby_stores_recenter',
            selectedStoreId: _selectedStore?.storeId,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.transparent),
            boxShadow: const [],
            onMarkerTap: (storeId) {
              final store = stores.firstWhere(
                (s) => s.storeId == storeId,
                orElse: () => stores.first,
              );
              _scrollToStore(store);
            },
            markers: stores
                .map((s) => MapStoreMarker(
                      storeId: s.storeId,
                      lat: s.lat,
                      lng: s.lng,
                      label: s.nama,
                    ))
                .toList(),
          ),
        ),

        // 2. Warning Status Badge Banner (if any)
        if (hasWarningMsg)
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const StatusBadge(status: 'Warning'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningText,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. Flexible DraggableScrollableSheet for Store List
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.32,
          minChildSize: 0.30,
          maxChildSize: 0.88,
          snap: true,
          snapSizes: const [0.30, 0.88],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. PINNED / STATIC HEADER (Tidak ikut ter-scroll)
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) {
                      if (_sheetController.isAttached) {
                        final screenHeight = MediaQuery.of(context).size.height;
                        if (screenHeight > 0) {
                          final delta = -details.primaryDelta! / screenHeight;
                          final newSize = (_sheetController.size + delta).clamp(0.30, 0.88);
                          _sheetController.jumpTo(newSize);
                        }
                      }
                    },
                    onVerticalDragEnd: (details) {
                      if (_sheetController.isAttached) {
                        final current = _sheetController.size;
                        final velocity = details.primaryVelocity ?? 0;
                        double target;
                        if (velocity < -300) {
                          target = 0.88;
                        } else if (velocity > 300) {
                          target = 0.30;
                        } else {
                          target = (current > 0.55) ? 0.88 : 0.30;
                        }
                        _sheetController.animateTo(
                          target,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag handle indicator
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Header title & subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Toko Sekitar',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0D2818),
                                      ),
                                    ),
                                    Text(
                                      'Temukan supermarket dan minimarket terdekat dari lokasi Anda',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: const Color(0xFF6B7280),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isFallback) ...[
                                const SizedBox(width: 8),
                                const StatusBadge(status: 'Offline'),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),

                  // 2. SCROLLABLE STORE LIST
                  Expanded(
                    child: stores.isEmpty
                        ? _buildEmptyStoresState()
                        : ListView.builder(
                            controller: scrollController,
                            // ignore: deprecated_member_use
                            cacheExtent: 10000.0,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                            itemCount: stores.length,
                            itemBuilder: (context, index) {
                              final store = stores[index];
                              final isSelected = _selectedStore?.storeId == store.storeId;
                              return _buildStoreCard(store, isSelected, index == 0);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Renders simplified individual store card with full clickable area
  Widget _buildStoreCard(StoreNearby store, bool isSelected, bool isFirst) {
    final walkingMinutes = (store.jarakKm * 12).round();
    final cardKey = _cardKeys.putIfAbsent(store.storeId, () => GlobalKey());
    final cleanAlamat = cleanAddress(store.alamat);

    return Container(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedStore = store;
            });
            _mapController.move(
              LatLng(store.lat, store.lng),
              _mapController.camera.zoom,
            );
            _showStoreDetail(context, store);
          },
          borderRadius: BorderRadius.circular(20.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: isSelected ? const Color(0xFF059669) : const Color(0xFFE8E4DC),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF059669).withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: isSelected ? 10 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Logo, Name, Distance, Walking Badge & Chevron
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    BrandAssets.buildStoreLogo(store.nama, size: 42, borderRadius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: const Color(0xFF0D2818),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(store.jarakKm * 1000).round()} m · $cleanAlamat',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // "Terdekat" or "X menit" walking badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFirst ? Icons.near_me_rounded : Icons.directions_walk_rounded,
                            size: 13,
                            color: const Color(0xFF059669),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isFirst ? 'Terdekat' : '$walkingMinutes menit',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),

                // Mini stats block (HANYA tampil jika data productCount riil > 0 dari database)
                if (store.productCount != null && store.productCount! > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8E4DC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sell_outlined, size: 13, color: Color(0xFF059669)),
                        const SizedBox(width: 5),
                        Text(
                          '${store.productCount} Harga Tercatat',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Renders state if no stores are found nearby
  Widget _buildEmptyStoresState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 40.0,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak ada toko terdeteksi di sekitar Anda.',
            style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
