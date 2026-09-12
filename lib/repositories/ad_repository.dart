import 'dart:async';
import 'package:dio/dio.dart';
import '../core/network/api_response.dart';
import '../core/network/dio_client.dart';
import '../models/ad_banner.dart';
import '../state/app_state.dart';

class _CachedAdEntry {
  final List<AdBanner> ads;
  final DateTime cachedAt;

  _CachedAdEntry(this.ads, this.cachedAt);

  bool isExpired(Duration ttl) =>
      DateTime.now().difference(cachedAt) > ttl;
}

/// Repository responsible for querying the backend ad catalog (`GET /api/v1/ads/`).
///
/// Features:
/// - Target-parameter query builder (state, district, city, area_id, placement_zone)
/// - Short-lived cache per targeting key with TTL
/// - In-flight asynchronous request deduplication
/// - Graceful network error translation
class AdRepository {
  static final AdRepository instance = AdRepository._internal();
  AdRepository._internal({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Visible for testing: inject custom dio instance.
  factory AdRepository.test({required Dio dio}) => AdRepository._internal(dio: dio);

  final Dio _dio;

  /// Default cache TTL for ads (5 minutes).
  Duration cacheTtl = const Duration(minutes: 5);

  /// In-memory cache by query key.
  final Map<String, _CachedAdEntry> _cache = {};

  /// In-flight requests by query key to prevent duplicate simultaneous calls.
  final Map<String, Future<ApiResponse<List<AdBanner>>>> _inFlightRequests = {};

  /// Generates a deterministic cache/in-flight key for the query parameters.
  String _buildCacheKey(Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    return sortedKeys.map((k) => '$k=${params[k]}').join('&');
  }

  /// Clears the entire ad cache (e.g. On manual pull-to-refresh or location change).
  void clearCache() {
    _cache.clear();
  }

  /// Fetches ads from `/api/v1/ads/` with targeting parameters.
  Future<ApiResponse<List<AdBanner>>> getAds({
    String placementZone = 'feed',
    String? scope,
    String? areaId,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    String? lang,
    bool forceRefresh = false,
  }) async {
    final effectiveState = state ?? AppState.instance.stateName;
    final effectiveDistrict = district ?? AppState.instance.district;
    final effectiveCity = city ?? AppState.instance.city;
    final effectiveLang = lang ?? 'te';

    final queryParams = <String, dynamic>{
      'placement_zone': placementZone,
      'zone': placementZone,
      if (scope != null && scope.isNotEmpty) 'scope': scope,
      if (areaId != null && areaId.isNotEmpty) 'area_id': areaId,
      if (effectiveState.isNotEmpty) 'state': effectiveState,
      if (effectiveDistrict.isNotEmpty) 'district': effectiveDistrict,
      if (effectiveCity.isNotEmpty) 'city': effectiveCity,
      if (subdistrict != null && subdistrict.isNotEmpty) 'subdistrict': subdistrict,
      if (village != null && village.isNotEmpty) 'village': village,
      'lang': effectiveLang,
    };

    final cacheKey = _buildCacheKey(queryParams);

    // 1. Check valid cache unless forceRefresh requested
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (!entry.isExpired(cacheTtl)) {
        return ApiResponse.success(List<AdBanner>.from(entry.ads));
      } else {
        _cache.remove(cacheKey);
      }
    }

    // 2. In-flight request deduplication
    if (_inFlightRequests.containsKey(cacheKey)) {
      return _inFlightRequests[cacheKey]!;
    }

    final future = _fetchAds(queryParams, cacheKey);
    _inFlightRequests[cacheKey] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<ApiResponse<List<AdBanner>>> _fetchAds(
    Map<String, dynamic> queryParams,
    String cacheKey,
  ) async {
    try {
      final response = await _dio.get(
        '/api/v1/ads/',
        queryParameters: queryParams,
      );

      final apiResponse = ApiResponse<List<AdBanner>>.fromJson(
        response.data,
        (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((i) => AdBanner.fromJson(i))
                .toList();
          }
          return <AdBanner>[];
        },
      );

      if (apiResponse.isSuccess && apiResponse.data != null) {
        _cache[cacheKey] = _CachedAdEntry(
          List<AdBanner>.from(apiResponse.data!),
          DateTime.now(),
        );
      }

      return apiResponse;
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.message ?? 'Network request failed',
        statusCode: e.response?.statusCode,
        fallbackData: <AdBanner>[],
      );
    } catch (e) {
      return ApiResponse.error(
        message: e.toString(),
        fallbackData: <AdBanner>[],
      );
    }
  }
}
