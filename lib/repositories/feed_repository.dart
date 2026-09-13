import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../core/network/api_response.dart';
import '../core/network/dio_client.dart';
import '../core/state/feed_state.dart';
import '../models/news_article.dart';
import '../state/app_state.dart';

/// In-memory cache entry for feed configurations.
class _FeedCacheEntry {
  final List<NewsArticle> items;
  final String? nextCursor;
  final DateTime cachedAt;

  _FeedCacheEntry({
    required this.items,
    this.nextCursor,
    required this.cachedAt,
  });

  bool get isExpired => DateTime.now().difference(cachedAt).inMinutes > 30;
}

/// Production FeedRepository managing:
/// - Feed requests via Dio / ApiClient
/// - Deduplication across pages using Set<String> seenIds
/// - Multi-dimensional cache key based on lang, scope, category, and location
/// - Safe cursor pagination using backend meta.next
/// - Guarding against concurrent or duplicate cursor requests
/// - Preserving existing content when refresh fails
/// - Strict adherence to backend scope (never fakes local feed with global feed)
class FeedRepository {
  FeedRepository({ApiClient? apiClient, Dio? dio})
      : _dio = dio ?? (apiClient ?? ApiClient.instance).dio;

  static final FeedRepository instance = FeedRepository();

  final Dio _dio;

  // Multi-dimensional in-memory cache
  final Map<String, _FeedCacheEntry> _cache = {};

  // Deduplication sets per cache key
  final Map<String, Set<String>> _seenIdsPerKey = {};

  // Pagination cursor and in-flight request locks
  final Map<String, String?> _activeCursors = {};
  final Set<String> _inFlightKeys = {};

  /// Generates a deterministic multi-dimensional cache/request identity.
  String generateKey({
    String? scope,
    String? category,
    String? lang,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    bool? breaking,
  }) {
    final effectiveLang = lang ?? AppState.instance.contentLanguage;
    final s = scope ?? 'all';
    final c = category != null && category.isNotEmpty ? category.toLowerCase() : 'all';
    final st = state ?? (scope == 'local' ? AppState.instance.stateName : 'any');
    final dt = district ?? (scope == 'local' ? AppState.instance.district : 'any');
    final ct = city ?? (scope == 'local' ? AppState.instance.city : 'any');
    final sdt = subdistrict ?? (scope == 'local' && AppState.instance.subdistrict.isNotEmpty ? AppState.instance.subdistrict : 'any');
    final v = village ?? (scope == 'local' && AppState.instance.village.isNotEmpty ? AppState.instance.village : 'any');
    final brk = breaking == true ? 'breaking' : 'std';

    return 'feed:$effectiveLang:$s:$c:$st:$dt:$ct:$sdt:$v:$brk';
  }

  /// Retrieves cached feed for the given key if available.
  FeedState<NewsArticle>? getCachedFeed(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    return FeedState.success(
      items: List.unmodifiable(entry.items),
      nextCursor: entry.nextCursor,
      cachedAt: entry.cachedAt,
    );
  }

  /// Initial feed load: returns cached data immediately if available,
  /// then fetches fresh data from network.
  Future<FeedState<NewsArticle>> getInitialFeed({
    String? scope,
    String? category,
    String? lang,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
    bool? breaking,
    int pageSize = 25,
    bool forceRefresh = false,
  }) async {
    final key = generateKey(
      scope: scope,
      category: category,
      lang: lang,
      state: state,
      district: district,
      city: city,
      subdistrict: subdistrict,
      village: village,
      breaking: breaking,
    );

    // Fast-path: return cached data if fresh and forceRefresh is false
    if (!forceRefresh && _cache.containsKey(key)) {
      final cached = _cache[key]!;
      _logDebug('[FeedRepository] Cache HIT for key: $key (${cached.items.length} items)');

      // Sync active cursor and deduplication tracker
      _activeCursors[key] = cached.nextCursor;
      _seenIdsPerKey[key] = cached.items.map((e) => e.id).toSet();

      // Trigger background revalidation if expired
      if (cached.isExpired) {
        _fetchAndStore(
          key: key,
          cursor: null,
          scope: scope,
          category: category,
          lang: lang,
          state: state,
          district: district,
          city: city,
          subdistrict: subdistrict,
          village: village,
          latitude: latitude,
          longitude: longitude,
          breaking: breaking,
          pageSize: pageSize,
        ).catchError((_) => null);
      }

      return FeedState.success(
        items: List.unmodifiable(cached.items),
        nextCursor: cached.nextCursor,
        cachedAt: cached.cachedAt,
      );
    }

    _logDebug('[FeedRepository] Cache MISS for key: $key. Requesting network...');

    // Fetch fresh from network
    try {
      final response = await _fetchFromNetwork(
        cursor: null,
        scope: scope,
        category: category,
        lang: lang,
        state: state,
        district: district,
        city: city,
        subdistrict: subdistrict,
        village: village,
        latitude: latitude,
        longitude: longitude,
        breaking: breaking,
        pageSize: pageSize,
      );

      if (response.hasErrors || !response.isSuccess) {
        final err = response.errorMessage ?? 'డేటాను లోడ్ చేయడంలో లోపం సంభవించింది.';
        _logDebug('[FeedRepository] Network response error for key: $key: $err');
        return FeedState.error(message: err);
      }

      final rawArticles = response.data ?? [];

      // Reset deduplication set for initial page
      final seen = <String>{};
      final deduplicated = <NewsArticle>[];
      for (final a in rawArticles) {
        if (a.id.isNotEmpty && seen.add(a.id)) {
          deduplicated.add(a);
        }
      }

      _seenIdsPerKey[key] = seen;
      _activeCursors[key] = response.nextCursor;

      // Update cache
      final now = DateTime.now();
      _cache[key] = _FeedCacheEntry(
        items: deduplicated,
        nextCursor: response.nextCursor,
        cachedAt: now,
      );

      _logDebug('[FeedRepository] Network SUCCESS for key: $key. Returned ${deduplicated.length} items, next: ${response.nextCursor}');

      if (deduplicated.isEmpty) {
        return FeedState.empty(cachedAt: now);
      }

      return FeedState.success(
        items: deduplicated,
        nextCursor: response.nextCursor,
        cachedAt: now,
      );
    } on AppException catch (e) {
      _logDebug('[FeedRepository] Network ERROR for key: $key: ${e.message}');
      return FeedState.error(message: e.message);
    } catch (e) {
      _logDebug('[FeedRepository] Unexpected ERROR for key: $key: $e');
      return FeedState.error(message: 'డేటాను లోడ్ చేయడంలో లోపం సంభవించింది.');
    }
  }

  /// Pull-to-refresh: resets cursor, fetches first page, preserves existing content on error.
  Future<FeedState<NewsArticle>> refreshFeed({
    required FeedState<NewsArticle> currentState,
    String? scope,
    String? category,
    String? lang,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
    bool? breaking,
    int pageSize = 25,
  }) async {
    final key = generateKey(
      scope: scope,
      category: category,
      lang: lang,
      state: state,
      district: district,
      city: city,
      subdistrict: subdistrict,
      village: village,
      breaking: breaking,
    );

    _logDebug('[FeedRepository] Refreshing feed for key: $key');

    try {
      final response = await _fetchFromNetwork(
        cursor: null,
        scope: scope,
        category: category,
        lang: lang,
        state: state,
        district: district,
        city: city,
        subdistrict: subdistrict,
        village: village,
        latitude: latitude,
        longitude: longitude,
        breaking: breaking,
        pageSize: pageSize,
      );

      if (response.hasErrors || !response.isSuccess) {
        final errorMsg = response.errorMessage ?? 'రిఫ్రెష్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.';
        _logDebug('[FeedRepository] Refresh FAILED: $errorMsg. Keeping ${currentState.items.length} existing items.');
        return FeedState.error(
          message: errorMsg,
          previousItems: currentState.items,
          previousCursor: currentState.nextCursor,
          previousHasMore: currentState.hasMore,
        );
      }

      final rawArticles = response.data ?? [];
      final seen = <String>{};
      final deduplicated = <NewsArticle>[];

      for (final a in rawArticles) {
        if (a.id.isNotEmpty && seen.add(a.id)) {
          deduplicated.add(a);
        }
      }

      _seenIdsPerKey[key] = seen;
      _activeCursors[key] = response.nextCursor;

      final now = DateTime.now();
      _cache[key] = _FeedCacheEntry(
        items: deduplicated,
        nextCursor: response.nextCursor,
        cachedAt: now,
      );

      if (deduplicated.isEmpty) {
        return FeedState.empty(cachedAt: now);
      }

      return FeedState.success(
        items: deduplicated,
        nextCursor: response.nextCursor,
        cachedAt: now,
      );
    } catch (e) {
      final errorMsg = e is AppException ? e.message : 'రిఫ్రెష్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.';
      _logDebug('[FeedRepository] Refresh FAILED: $errorMsg. Keeping ${currentState.items.length} existing items.');

      // Retain existing items and surface non-blocking refresh error
      return FeedState.error(
        message: errorMsg,
        previousItems: currentState.items,
        previousCursor: currentState.nextCursor,
        previousHasMore: currentState.hasMore,
      );
    }
  }

  /// Loads next page using `meta.next` cursor with full concurrency and duplicate protection.
  Future<FeedState<NewsArticle>> loadNextPage({
    required FeedState<NewsArticle> currentState,
    String? scope,
    String? category,
    String? lang,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
    bool? breaking,
    int pageSize = 25,
  }) async {
    final key = generateKey(
      scope: scope,
      category: category,
      lang: lang,
      state: state,
      district: district,
      city: city,
      subdistrict: subdistrict,
      village: village,
      breaking: breaking,
    );

    // Guard: already in flight
    if (_inFlightKeys.contains(key)) {
      _logDebug('[FeedRepository] Next page request ignored: key $key is already IN FLIGHT');
      return currentState;
    }

    // Guard: no more pages
    final cursor = currentState.nextCursor;
    if (cursor == null || cursor.isEmpty || !currentState.hasMore) {
      _logDebug('[FeedRepository] Next page request ignored: no more cursor available');
      return currentState;
    }

    _inFlightKeys.add(key);
    _logDebug('[FeedRepository] Loading next page for key: $key with cursor: $cursor');

    try {
      final response = await _fetchFromNetwork(
        cursor: cursor,
        scope: scope,
        category: category,
        lang: lang,
        state: state,
        district: district,
        city: city,
        subdistrict: subdistrict,
        village: village,
        latitude: latitude,
        longitude: longitude,
        breaking: breaking,
        pageSize: pageSize,
      );

      final newArticles = response.data ?? [];
      final seen = _seenIdsPerKey.putIfAbsent(key, () => currentState.items.map((e) => e.id).toSet());

      final deduplicatedNew = <NewsArticle>[];
      for (final a in newArticles) {
        if (a.id.isNotEmpty && seen.add(a.id)) {
          deduplicatedNew.add(a);
        }
      }

      final combined = List<NewsArticle>.from(currentState.items)..addAll(deduplicatedNew);
      final newCursor = response.nextCursor;
      final hasMore = newCursor != null && newCursor.isNotEmpty;

      _activeCursors[key] = newCursor;

      // Update cache
      _cache[key] = _FeedCacheEntry(
        items: combined,
        nextCursor: newCursor,
        cachedAt: currentState.cachedAt ?? DateTime.now(),
      );

      _logDebug('[FeedRepository] Next page SUCCESS: appended ${deduplicatedNew.length} items (total: ${combined.length}), next: $newCursor');

      return currentState.copyWith(
        status: FeedStatus.success,
        items: combined,
        nextCursor: newCursor,
        hasMore: hasMore,
      );
    } catch (e) {
      final errorMsg = e is AppException ? e.message : 'తదుపరి పేజీ లోడ్ చేయడం విఫలమైంది.';
      _logDebug('[FeedRepository] Next page FAILED: $errorMsg');
      return currentState.copyWith(
        status: FeedStatus.success, // Keep showing items
        refreshErrorMessage: errorMsg,
      );
    } finally {
      _inFlightKeys.remove(key);
    }
  }

  /// Internal network request orchestrator
  Future<ApiResponse<List<NewsArticle>>> _fetchFromNetwork({
    String? cursor,
    String? scope,
    String? category,
    String? lang,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
    bool? breaking,
    int pageSize = 25,
  }) async {
    final effectiveLang = lang ?? AppState.instance.contentLanguage;
    final effectiveState = state ?? (scope == 'local' ? AppState.instance.stateName : null);
    final effectiveDistrict = district ?? (scope == 'local' ? AppState.instance.district : null);
    final effectiveCity = city ?? (scope == 'local' ? AppState.instance.city : null);
    final effectiveSubdistrict = subdistrict ?? (scope == 'local' && AppState.instance.subdistrict.isNotEmpty ? AppState.instance.subdistrict : null);
    final effectiveVillage = village ?? (scope == 'local' && AppState.instance.village.isNotEmpty ? AppState.instance.village : null);

    final stopwatch = Stopwatch()..start();

    final response = await _dio.get(
      '/api/v1/articles/feed/',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'page_size': pageSize,
        if (scope != null && scope.isNotEmpty) 'scope': scope,
        'lang': effectiveLang,
        if (category != null && category.isNotEmpty && category != 'For You' && category != 'Trending')
          'category': category.toLowerCase(),
        if (breaking != null) 'breaking': breaking,
        if (effectiveState != null && effectiveState.isNotEmpty) 'state': effectiveState,
        if (effectiveDistrict != null && effectiveDistrict.isNotEmpty) 'district': effectiveDistrict,
        if (effectiveCity != null && effectiveCity.isNotEmpty) 'city': effectiveCity,
        if (effectiveSubdistrict != null && effectiveSubdistrict.isNotEmpty) 'subdistrict': effectiveSubdistrict,
        if (effectiveVillage != null && effectiveVillage.isNotEmpty) 'village': effectiveVillage,
        if (latitude != null) ...{
          'latitude': latitude,
          'lat': latitude,
        },
        if (longitude != null) ...{
          'longitude': longitude,
          'lng': longitude,
          'lon': longitude,
        },
      },
    );

    stopwatch.stop();

    Map<String, dynamic> responseMap;
    if (response.data is Map<String, dynamic>) {
      responseMap = response.data as Map<String, dynamic>;
    } else if (response.data is Map) {
      responseMap = Map<String, dynamic>.from(response.data as Map);
    } else {
      _logDebug('[FeedRepository] Malformed non-Map response for feed: ${response.data.runtimeType}');
      return ApiResponse.error(
        message: 'చెల్లని సర్వర్ సమాధానం.',
        statusCode: response.statusCode,
      );
    }

    final parsed = ApiResponse<List<NewsArticle>>.fromJson(
      responseMap,
      (data) {
        if (data is List) {
          final items = <NewsArticle>[];
          for (final i in data) {
            if (i is Map) {
              try {
                items.add(NewsArticle.fromJson(Map<String, dynamic>.from(i)));
              } catch (e) {
                _logDebug('[FeedRepository] Skipping malformed article item: $e');
              }
            }
          }
          return items;
        }
        return <NewsArticle>[];
      },
      statusCode: response.statusCode,
    );

    _logDebug(
      'GET /api/v1/articles/feed/ ${response.statusCode} ${stopwatch.elapsedMilliseconds}ms '
      'items=${parsed.data?.length ?? 0} next=${parsed.nextCursor != null}',
    );

    return parsed;
  }

  Future<void> _fetchAndStore({
    required String key,
    String? cursor,
    String? scope,
    String? category,
    String? lang,
    String? state,
    String? district,
    String? city,
    String? subdistrict,
    String? village,
    double? latitude,
    double? longitude,
    bool? breaking,
    int pageSize = 25,
  }) async {
    try {
      final response = await _fetchFromNetwork(
        cursor: cursor,
        scope: scope,
        category: category,
        lang: lang,
        state: state,
        district: district,
        city: city,
        subdistrict: subdistrict,
        village: village,
        latitude: latitude,
        longitude: longitude,
        breaking: breaking,
        pageSize: pageSize,
      );
      final rawArticles = response.data ?? [];
      final seen = <String>{};
      final deduplicated = <NewsArticle>[];
      for (final a in rawArticles) {
        if (a.id.isNotEmpty && seen.add(a.id)) {
          deduplicated.add(a);
        }
      }
      _cache[key] = _FeedCacheEntry(
        items: deduplicated,
        nextCursor: response.nextCursor,
        cachedAt: DateTime.now(),
      );
    } catch (_) {}
  }

  void clearCache() {
    _cache.clear();
    _seenIdsPerKey.clear();
    _activeCursors.clear();
    _inFlightKeys.clear();
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[FeedRepository] $message');
    }
  }
}
