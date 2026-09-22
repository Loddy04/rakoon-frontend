import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/services/recommendation_service.dart';

enum RecommendationStatus { initial, loading, success, error }

class RecommendationProvider extends ChangeNotifier {
  RecommendationStatus _status = RecommendationStatus.initial;
  List<RecommendedProduct> _products = [];
  String? _errorMessage;
  bool _isDisposed = false;

  RecommendationStatus get status => _status;
  List<RecommendedProduct> get products => _products;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == RecommendationStatus.loading;
  bool get isSuccess => _status == RecommendationStatus.success;
  bool get isError => _status == RecommendationStatus.error;

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

  Future<void> fetchRecommendedProducts({
    required String baseUrl,
    double? lat,
    double? lng,
    double radiusKm = 1.0,
    int limit = 10,
    http.Client? client,
  }) async {
    _status = RecommendationStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await RecommendationService.getRecommendedProducts(
        baseUrl: baseUrl,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        limit: limit,
        client: client,
      );

      if (_isDisposed) return;
      _products = items;
      _status = RecommendationStatus.success;
    } catch (e) {
      if (_isDisposed) return;
      _status = RecommendationStatus.error;
      _errorMessage = 'Gagal memuat rekomendasi: $e';
    } finally {
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }
}
