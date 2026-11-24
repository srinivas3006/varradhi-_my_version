import 'dart:async';
import '../core/ads/ad_placement.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_response.dart';
import '../core/network/dio_client.dart';
import '../models/ad_banner.dart';
import '../state/app_state.dart';

class _CachedAdEntry {
  final List<AdBanner> ads;
  final DateTime cachedAt;

  _CachedAdEntry(this.ads, this.cachedAt);

  bool isExpired(Duration ttl) => DateTime.now().difference(cachedAt) > ttl;
}

/// Repository responsible for querying the backend ad catalog (`GET /api/v1/ads/`).
///
/// Features:
/// - Target-parameter query builder (state, district, city, area_id, placement_zone)
/// - Short-lived cache per targeting key with TTL
/// - In-flight asynchronous request deduplication
/// - Graceful network error translation
class AdRepository {
  static const managedDeliveryEnabled = bool.fromEnvironment('ADS_MANAGED_V2');

  static final AdRepository instance = AdRepository._internal();
  AdRepository._internal({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Visible for testing: inject custom dio instance.
  factory AdRepository.test({required Dio dio}) =>
      AdRepository._internal(dio: dio);

  final Dio _dio;

  static String get targetingKey {
    final app = AppState.instance;
    return Uri(queryParameters: {
      ..._savedLocation(),
      'lang': app.feedLang,
      'reader': app.userId ?? '',
      'device': app.deviceId,
    }).query;
  }

  static Map<String, String> _savedLocation({
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    String? areaId,
  }) {
    final app = AppState.instance;
    final place = app.feedPlace;
    final values = {
      'state': state ?? place.state,
      'district': district ?? place.district,
      'city': city ?? app.feedCity,
      'subdistrict': subdistrict ?? place.subdistrict,
      'village': village ?? place.village,
      'area_id': areaId,
    };
    values.updateAll((_, value) {
      final clean = AppState.cleanPlace(value);
      return const {'n/a', 'na', 'none', 'any', '-', 'select location'}
              .contains(clean.toLowerCase())
          ? ''
          : clean;
    });
    return {
      for (final entry in values.entries)
        if (entry.value?.isNotEmpty == true) entry.key: entry.value!,
    };
  }

  /// A single opportunity tied to its caller's placement and content.
  /// The caller keeps the offer with that slot for its lifetime.
  Future<AdBanner?> decide({
    required String placementZone,
    int? contentIndex,
    String? language,
    String? category,
    String? areaId,
  }) async {
    final zone = AdPlacement.canonical(placementZone);
    final app = AppState.instance;
    final deviceId = app.deviceId;
    final targeting = targetingKey;
    final lang = language?.trim().toLowerCase();
    final slug = category?.trim();
    if (deviceId.isEmpty) return null;
    try {
      final response = await _dio.post('/api/v1/ads/decision/',
          data: {
            'tracking_version': 2,
            'placement_zone': zone,
            'limit': 1,
            if (contentIndex != null) 'content_index': contentIndex,
            if (lang != null && RegExp(r'^[a-z]{2}$').hasMatch(lang))
              'language': lang,
            if (slug != null && RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(slug))
              'category': slug,
            ..._savedLocation(areaId: areaId),
          },
          options: Options(headers: {'X-Device-ID': deviceId}));
      if (targetingKey != targeting) return null;
      final envelope = response.data;
      if (envelope is! Map || envelope['errors'] != null) return null;
      final data = envelope['data'];
      if (data is! Map || data['should_show'] != true) return null;
      final offers = _parseOffers(data['ads'], zone, deviceId, targeting);
      return offers.where((ad) => ad.exposure != null).firstOrNull;
    } on DioException catch (error) {
      final body = error.response?.data;
      final detail = ApiError.fromJson(body is Map ? body['errors'] : null);
      debugPrint(
          '[Ads] Decision failed in $zone (${error.response?.statusCode}); '
          'validation fields: ${detail.details is Map ? (detail.details as Map).keys : []}');
      return null;
    }
  }

  static List<AdBanner> _parseOffers(
      dynamic data, String zone, String deviceId, String? targeting) {
    final rows = data is List ? data : (data is Map ? data['ads'] : null);
    if (rows is! List) return const [];
    final offers = <AdBanner>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final ad =
          AdBanner.fromJson(row, deviceId: deviceId, targetingKey: targeting);
      if (ad.placementZone.trim().toLowerCase() != zone ||
          !AdPlacement.supports(zone, ad) ||
          (ad.exposure != null &&
              zone == AdPlacement.articleEnd &&
              ad.isVideo)) {
        debugPrint('[Ads] Ignoring an incompatible creative for $zone');
        continue;
      }
      if (ad.id.isNotEmpty && ad.canDisplay) offers.add(ad);
    }
    return offers;
  }

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
    bool trackingV2 = false,
  }) async {
    // The reader's real place: with none chosen, no location is sent, not
    // the starting Telangana / Hyderabad.
    final effectiveLang = lang ?? AppState.instance.contentLanguage;
    final zone = AdPlacement.canonical(placementZone);
    final device = AppState.instance.deviceId;
    final targeting = targetingKey;
    if (trackingV2 && device.isEmpty) return ApiResponse.success([]);

    // placement_zone only: the backend's canonical parameter (it accepts
    // `zone` too, but asks for one, not both).
    final queryParams = <String, dynamic>{
      'placement_zone': zone,
      if (scope != null && scope.isNotEmpty) 'scope': scope,
      ..._savedLocation(
          areaId: areaId,
          state: state,
          district: district,
          city: city,
          subdistrict: subdistrict,
          village: village),
      'lang': effectiveLang,
      if (trackingV2) 'tracking_version': 2,
    };

    if (trackingV2) {
      return _fetchAds(queryParams, null, device, targeting);
    }
    final cacheKey = _buildCacheKey({...queryParams, 'targeting': targeting});

    // 1. Check valid cache unless forceRefresh requested
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (!entry.isExpired(cacheTtl)) {
        return ApiResponse.success(
            entry.ads.where((ad) => ad.canDisplay).toList());
      } else {
        _cache.remove(cacheKey);
      }
    }

    // 2. In-flight request deduplication
    if (_inFlightRequests.containsKey(cacheKey)) {
      return _inFlightRequests[cacheKey]!;
    }

    final future = _fetchAds(queryParams, cacheKey, device, targeting);
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
    String? cacheKey,
    String device,
    String targeting,
  ) async {
    try {
      final response = await _dio.get(
        '/api/v1/ads/',
        queryParameters: queryParams,
        options:
            Options(headers: {if (device.isNotEmpty) 'X-Device-ID': device}),
      );

      if (targetingKey != targeting) return ApiResponse.success([]);
      final apiResponse = ApiResponse<List<AdBanner>>.fromJson(
        response.data,
        (json) => _parseOffers(json, queryParams['placement_zone'] as String,
                device, targeting)
            .where((ad) => (ad.exposure != null) == (cacheKey == null))
            .toList(),
      );

      if (cacheKey != null &&
          apiResponse.isSuccess &&
          apiResponse.data != null) {
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
