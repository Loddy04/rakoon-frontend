import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';
import 'package:rakoon_frontend/features/nearby/price_comparison_screen.dart';

class NearbyStoresScreen extends StatefulWidget {
  final String baseUrl;

  const NearbyStoresScreen({
    super.key,
    required this.baseUrl,
  });

  @override
  State<NearbyStoresScreen> createState() => _NearbyStoresScreenState();
}

class _NearbyStoresScreenState extends State<NearbyStoresScreen> {
  final MapController _mapController = MapController();

  void _showProductSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      backgroundColor: AppColors.paper,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ProductSelectorBottomSheet(
            baseUrl: widget.baseUrl,
            onProductSelected: (prod) {
              Navigator.pop(context); // Close bottom sheet
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PriceComparisonScreen(
                    productId: prod.id,
                    productName: prod.nama,
                    baseUrl: widget.baseUrl,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  bool _isLoading = true;
  String? _errorMessage;
  
  Position? _userPosition;
  NearbyStoresResponse? _storesResponse;
  StoreNearby? _selectedStore;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndStores();
  }

  /// Gets location and queries the backend for stores.
  Future<void> _fetchLocationAndStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedStore = null;
    });

    try {
      // 1. Get GPS coordinates
      final position = await LocationService.getCurrentLocation();
      _userPosition = position;

      // 2. Fetch stores using GPS coordinates
      final response = await StoresService.getNearbyStores(
        lat: position.latitude,
        lng: position.longitude,
        baseUrl: widget.baseUrl,
      );

      setState(() {
        _storesResponse = response;
        if (response.stores.isNotEmpty) {
          _selectedStore = response.stores.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = !_isLoading && _userPosition != null && _storesResponse != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Toko Terdekat'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLocationAndStores,
            tooltip: 'Segarkan Data',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingWidget()
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
          const CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3.5,
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'Mencari koordinat & toko terdekat...',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  /// Renders clean error state box using error Soft design token
  Widget _buildErrorWidget() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.errorSoft,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Terjadi Kesalahan',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                _errorMessage ?? 'Gagal memuat data.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: _fetchLocationAndStores,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders main screen split between OSM Map and Store Info list
  Widget _buildMainLayout() {
    final response = _storesResponse!;
    final stores = response.stores;
    final isFallback = response.source == 'local_fallback';
    final hasWarningMsg = response.message != null && response.message!.isNotEmpty;

    // Check if we should display warning banner
    final showWarning = isFallback || hasWarningMsg;
    final warningText = hasWarningMsg 
        ? response.message! 
        : 'Peta offline fallback. Menggunakan database lokal.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. OpenStreetMap Section
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.line, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      _userPosition!.latitude,
                      _userPosition!.longitude,
                    ),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rakoon.rakoon_frontend',
                    ),
                    MarkerLayer(
                      markers: [
                        // User position marker (Blue)
                        Marker(
                          point: LatLng(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                          ),
                          width: 45.0,
                          height: 45.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2563EB),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.my_location,
                                color: Color(0xFF1D4ED8),
                                size: 20.0,
                              ),
                            ),
                          ),
                        ),
                        // Stores markers (Emerald Green Accent)
                        ...stores.map((store) {
                          final isSelected = _selectedStore?.storeId == store.storeId;
                          
                          return Marker(
                            point: LatLng(store.lat, store.lng),
                            width: 50.0,
                            height: 50.0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedStore = store;
                                });
                                _mapController.move(
                                  LatLng(store.lat, store.lng),
                                  _mapController.camera.zoom,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                decoration: isSelected
                                    ? BoxDecoration(
                                        color: AppColors.accentSoft,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.accent,
                                          width: 2.0,
                                        ),
                                      )
                                    : const BoxDecoration(),
                                child: Icon(
                                  Icons.store,
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.accent.withValues(alpha: 0.75),
                                  size: isSelected ? 32.0 : 26.0,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                
                // Recenter button
                Positioned(
                  bottom: AppSpacing.m,
                  right: AppSpacing.m,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_btn',
                    backgroundColor: AppColors.paper,
                    foregroundColor: AppColors.ink,
                    onPressed: () {
                      if (_userPosition != null) {
                        _mapController.move(
                          LatLng(_userPosition!.latitude, _userPosition!.longitude),
                          14.0,
                        );
                      }
                    },
                    child: const Icon(Icons.gps_fixed),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Warning Status Badge Banner
        if (showWarning)
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.xs,
            ),
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const StatusBadge(status: 'Warning'),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    warningText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 3. Info List Section
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.s,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toko Terdekat (${stores.length})',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isFallback)
                      const StatusBadge(status: 'Offline'),
                  ],
                ),
              ),
              Expanded(
                child: stores.isEmpty
                    ? _buildEmptyStoresState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.l,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: stores.length,
                        itemBuilder: (context, index) {
                          final store = stores[index];
                          final isSelected = _selectedStore?.storeId == store.storeId;
                          
                          return _buildStoreCard(store, isSelected);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Renders individual premium store visual card
  Widget _buildStoreCard(StoreNearby store, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStore = store;
        });
        _mapController.move(
          LatLng(store.lat, store.lng),
          _mapController.camera.zoom,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: MediaQuery.of(context).size.width * 0.72,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.s,
        ),
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.line,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: isSelected ? 0.06 : 0.03),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        store.nama,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.storefront,
                      color: isSelected ? AppColors.accent : AppColors.muted,
                      size: 20.0,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ID: ${store.storeId.substring(0, 8)}...',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk,
                      size: 14.0,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '${store.jarakKm.toStringAsFixed(2)} km',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                StatusBadge(
                  status: store.source == 'osm' ? 'OSM' : 'Lokal',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showProductSelector(context),
                icon: const Icon(Icons.compare_arrows, size: 14.0),
                label: const Text(
                  'Bandingkan Harga',
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  backgroundColor: AppColors.accentSoft,
                  foregroundColor: AppColors.accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
              ),
            ),
          ],
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
            color: AppColors.muted,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Tidak ada toko terdeteksi di sekitar Anda.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A stateful bottom sheet widget that fetches products dynamically and allows searching with debouncing.
class ProductSelectorBottomSheet extends StatefulWidget {
  final String baseUrl;
  final Function(Product) onProductSelected;

  const ProductSelectorBottomSheet({
    super.key,
    required this.baseUrl,
    required this.onProductSelected,
  });

  @override
  State<ProductSelectorBottomSheet> createState() => _ProductSelectorBottomSheetState();
}

class _ProductSelectorBottomSheetState extends State<ProductSelectorBottomSheet> {
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
      setState(() {
        _products = list;
        _isLoading = false;
      });
    } catch (e) {
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

