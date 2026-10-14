import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/history/data/models/price_history_item.dart';
import 'package:rakoon_frontend/features/price_check/data/datasources/price_check_service.dart';
import 'package:rakoon_frontend/features/price_check/data/models/product_catalog_model.dart';
import 'package:rakoon_frontend/services/stores_service.dart';

enum PriceCheckStatus { initial, loading, success, error }

class PriceCheckProvider extends ChangeNotifier {
  PriceCheckStatus _status = PriceCheckStatus.initial;
  List<CatalogProduct> _products = [];
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  // Infinite scroll state; a page is "full" when it has pageSize items.
  static const int pageSize = 100;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _loadMoreError;
  int _generation = 0;

  // Product detail state
  PriceCheckStatus _detailStatus = PriceCheckStatus.initial;
  PriceHistoryResponse? _historyResponse;
  PriceCompareResponse? _comparisonResponse;
  String _selectedRange = '1m';
  bool _isDisposed = false;

  static const List<String> categories = [
    'Semua',
    'Minuman',
    'Makanan Instan',
    'Makanan Pokok',
    'Camilan',
    'Susu & Olahan',
    'Bumbu & Saus',
    'Perawatan Diri',
    'Produk Rumah Tangga',
    'Kesehatan',
    'Bayi',
    'Lainnya',
  ];

  PriceCheckStatus get status => _status;
  List<CatalogProduct> get products => _products;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  PriceCheckStatus get detailStatus => _detailStatus;
  PriceHistoryResponse? get historyResponse => _historyResponse;
  PriceCompareResponse? get comparisonResponse => _comparisonResponse;
  String get selectedRange => _selectedRange;

  bool get isLoading => _status == PriceCheckStatus.loading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get loadMoreError => _loadMoreError;
  bool get isDetailLoading => _detailStatus == PriceCheckStatus.loading;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> fetchCatalog({
    String? search,
    String? category,
    String? baseUrl,
    http.Client? client,
  }) async {
    if (search != null) _searchQuery = search;
    if (category != null) _selectedCategory = category;

    final generation = ++_generation; // invalidates any in-flight loadMore
    _isLoadingMore = false;
    _loadMoreError = null;
    _hasMore = false;
    _status = PriceCheckStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await PriceCheckService.getCatalogProducts(
        search: _searchQuery,
        category: _selectedCategory,
        limit: pageSize,
        baseUrl: baseUrl,
        client: client,
      );

      if (_isDisposed || generation != _generation) return;
      _products = items;
      _hasMore = items.length >= pageSize;
      _status = PriceCheckStatus.success;
    } catch (e) {
      if (_isDisposed || generation != _generation) return;
      _status = PriceCheckStatus.error;
      _errorMessage = 'Gagal memuat katalog: $e';
    } finally {
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Loads the next catalog page at offset = items already loaded.
  /// No-op while loading or when the last page was short.
  Future<void> loadMore({String? baseUrl, http.Client? client}) async {
    if (_isLoadingMore || !_hasMore || isLoading) return;
    final generation = _generation;
    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final items = await PriceCheckService.getCatalogProducts(
        search: _searchQuery,
        category: _selectedCategory,
        limit: pageSize,
        offset: _products.length,
        baseUrl: baseUrl,
        client: client,
      );
      if (_isDisposed || generation != _generation) return;
      _products = [..._products, ...items];
      _hasMore = items.length >= pageSize;
    } catch (_) {
      if (_isDisposed || generation != _generation) return;
      _loadMoreError = 'Gagal memuat produk berikutnya. Periksa koneksi lalu coba lagi.';
    } finally {
      if (!_isDisposed && generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void updateSearch(String query, {String? baseUrl, http.Client? client}) {
    _searchQuery = query;
    fetchCatalog(search: query, category: _selectedCategory, baseUrl: baseUrl, client: client);
  }

  void selectCategory(String cat, {String? baseUrl, http.Client? client}) {
    _selectedCategory = cat;
    fetchCatalog(search: _searchQuery, category: cat, baseUrl: baseUrl, client: client);
  }

  Future<void> fetchProductDetail({
    required String productId,
    required double userLat,
    required double userLng,
    String range = '1m',
    String? baseUrl,
    http.Client? client,
  }) async {
    _selectedRange = range;
    _detailStatus = PriceCheckStatus.loading;
    notifyListeners();

    try {
      final history = await PriceCheckService.getPriceHistory(
        productId: productId,
        range: range,
        baseUrl: baseUrl,
        client: client,
      );

      final comparison = await PriceCheckService.getPriceComparison(
        productId: productId,
        lat: userLat,
        lng: userLng,
        baseUrl: baseUrl,
        client: client,
      );

      if (_isDisposed) return;
      _historyResponse = history;
      _comparisonResponse = comparison;
      _detailStatus = PriceCheckStatus.success;
    } catch (e) {
      if (_isDisposed) return;
      _detailStatus = PriceCheckStatus.error;
    } finally {
      if (!_isDisposed) notifyListeners();
    }
  }

  void updateRange(
    String range, {
    required String productId,
    required double userLat,
    required double userLng,
    String? baseUrl,
    http.Client? client,
  }) {
    _selectedRange = range;
    fetchProductDetail(
      productId: productId,
      userLat: userLat,
      userLng: userLng,
      range: range,
      baseUrl: baseUrl,
      client: client,
    );
  }
}
