import 'package:flutter/foundation.dart';
import '../../data/models/price_history_item.dart';
import '../../data/repositories/price_history_repository.dart';

enum PriceHistoryStatus { initial, loading, success, empty, error }

class PriceHistoryNotifier extends ChangeNotifier {
  final PriceHistoryRepository repository;

  PriceHistoryStatus _status = PriceHistoryStatus.initial;
  PriceHistoryResponse? _response;
  String? _errorMessage;

  dynamic _selectedStoreId;
  String _selectedRange = 'all';

  PriceHistoryNotifier({required this.repository});

  PriceHistoryStatus get status => _status;
  PriceHistoryResponse? get response => _response;
  String? get errorMessage => _errorMessage;

  dynamic get selectedStoreId => _selectedStoreId;
  String get selectedRange => _selectedRange;

  bool get isLoading => _status == PriceHistoryStatus.loading;
  bool get isSuccess => _status == PriceHistoryStatus.success;
  bool get isEmpty => _status == PriceHistoryStatus.empty;
  bool get isError => _status == PriceHistoryStatus.error;

  Future<void> fetchPriceHistory({
    required dynamic productId,
    dynamic storeId,
    String? range,
  }) async {
    if (storeId != null) {
      _selectedStoreId = storeId;
    }
    if (range != null) {
      _selectedRange = range;
    }

    _status = PriceHistoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await repository.getPriceHistory(
        productId: productId,
        storeId: _selectedStoreId,
        range: _selectedRange,
      );

      _response = res;
      if (res.items.isEmpty && res.trend.isEmpty) {
        _status = PriceHistoryStatus.empty;
      } else {
        _status = PriceHistoryStatus.success;
      }
    } on ProductNotFoundException catch (e) {
      _status = PriceHistoryStatus.error;
      _errorMessage = e.message;
    } on PriceHistoryNetworkException catch (e) {
      _status = PriceHistoryStatus.error;
      _errorMessage = e.message;
    } on PriceHistoryApiException catch (e) {
      _status = PriceHistoryStatus.error;
      _errorMessage = e.message;
    } catch (e) {
      _status = PriceHistoryStatus.error;
      _errorMessage = 'Terjadi kesalahan: $e';
    } finally {
      notifyListeners();
    }
  }

  void setRange(dynamic productId, String range) {
    if (_selectedRange == range) return;
    _selectedRange = range;
    fetchPriceHistory(productId: productId);
  }

  void setStoreId(dynamic productId, dynamic storeId) {
    if (_selectedStoreId == storeId) return;
    _selectedStoreId = storeId;
    fetchPriceHistory(productId: productId);
  }

  void clearFilters(dynamic productId) {
    _selectedStoreId = null;
    _selectedRange = 'all';
    fetchPriceHistory(productId: productId);
  }
}
