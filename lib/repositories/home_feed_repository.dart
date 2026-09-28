import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_article.dart';
import '../services/dio_client.dart';

/// Result of `GET /api/v1/feed/home/` — the Home screen's first paint.
class HomeBootstrap {
  HomeBootstrap({
    required this.personalized,
    required this.local,
    required this.cacheTtlSeconds,
    required this.analyticsBulkEndpoint,
    required this.lite,
    required this.fetchedAt,
    this.fromDeviceCache = false,
  });

  /// Ranked for this reader (category preference, profile, language,
  /// bookmarks, location, priority, recency).
  final List<NewsArticle> personalized;

  /// Stories for the reader's selected location.
  final List<NewsArticle> local;

  final int cacheTtlSeconds;
  final String? analyticsBulkEndpoint;

  /// True when this came from `mode=lite` (smaller payload).
  final bool lite;
  final DateTime fetchedAt;

  /// Served from the copy kept on the device (offline / instant start).
  final bool fromDeviceCache;

  bool get isFresh =>
      DateTime.now().difference(fetchedAt).inSeconds < cacheTtlSeconds;

  bool get isEmpty => personalized.isEmpty && local.isEmpty;

  /// Accepts the shapes the backend may use for `sections`:
  /// - a map: `{personalized: [...], local: [...]}` (lists or `{items: [...]}`)
  /// - a list: `[{key|type|name: "personalized", items|results|articles: [...]}]`
  static HomeBootstrap parse(Map<String, dynamic> body,
      {required bool lite, DateTime? fetchedAt, bool fromDeviceCache = false}) {
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;

    List<NewsArticle> articles(dynamic raw) {
      if (raw is Map) {
        raw = raw['items'] ?? raw['results'] ?? raw['articles'] ?? raw['data'];
      }
      if (raw is! List) return const [];
      final out = <NewsArticle>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          final a = NewsArticle.fromJson(Map<String, dynamic>.from(item));
          if (a.id.isNotEmpty || a.slug.isNotEmpty) out.add(a);
        } catch (e) {
          debugPrint('[HomeFeed] skipped malformed item: $e');
        }
      }
      return out;
    }

    dynamic section(String name) {
      final sections = data['sections'];
      if (sections is Map) return sections[name];
      if (sections is List) {
        for (final s in sections.whereType<Map>()) {
          final key = (s['key'] ?? s['type'] ?? s['name'] ?? s['id'])
              ?.toString()
              .toLowerCase();
          if (key == name) return s;
        }
      }
      return data[name];
    }

    final offline = data['offline_support'];
    final ttl = data['cache_ttl_seconds'];
    return HomeBootstrap(
      personalized: articles(section('personalized')),
      local: articles(section('local')),
      cacheTtlSeconds: ttl is num && ttl > 0 ? ttl.toInt() : 60,
      analyticsBulkEndpoint: offline is Map
          ? offline['analytics_bulk_endpoint']?.toString()
          : null,
      lite: lite,
      fetchedAt: fetchedAt ?? DateTime.now(),
      fromDeviceCache: fromDeviceCache,
    );
  }
}

/// Loads the Home bootstrap with three layers:
/// 1. in-memory, honoured for `cache_ttl_seconds`;
/// 2. the last response kept on the device, for an instant (and offline)
///    first paint;
/// 3. the network, in `mode=lite` when the connection has been slow.
class HomeFeedRepository {
  HomeFeedRepository._({Dio? dio}) : _dioOverride = dio;
  static final HomeFeedRepository instance = HomeFeedRepository._();

  @visibleForTesting
  factory HomeFeedRepository.forTesting(Dio dio) =>
      HomeFeedRepository._(dio: dio);

  static const endpoint = '/api/v1/feed/home/';
  static const _prefsPrefix = 'home_bootstrap_v1:';

  /// A bootstrap slower than this switches the next one to lite mode.
  static const slowThreshold = Duration(milliseconds: 2500);

  final Dio? _dioOverride;
  Dio get _dio => _dioOverride ?? DioClient().dio;

  final Map<String, HomeBootstrap> _memory = {};
  bool _preferLite = false;

  bool get prefersLite => _preferLite;

  static Map<String, String> _params({
    String? lang,
    required String state,
    required String district,
    required String subdistrict,
    required String village,
    required bool lite,
    int limit = 10,
  }) =>
      {
        if (lang != null && lang.isNotEmpty) 'lang': lang,
        if (state.isNotEmpty) 'state': state,
        if (district.isNotEmpty) 'district': district,
        if (subdistrict.isNotEmpty) 'subdistrict': subdistrict,
        if (village.isNotEmpty) 'village': village,
        'scope': 'main',
        'mode': lite ? 'lite' : 'normal',
        'limit': '$limit',
      };

  static String _cacheKey(Map<String, String> p) {
    final copy = Map.of(p)..remove('mode');
    final keys = copy.keys.toList()..sort();
    return keys.map((k) => '$k=${copy[k]}').join('&').toLowerCase();
  }

  /// The copy kept on the device for these parameters, if any.
  Future<HomeBootstrap?> cached({
    String? lang,
    required String state,
    required String district,
    required String subdistrict,
    required String village,
  }) async {
    final key = _cacheKey(_params(
        lang: lang,
        state: state,
        district: district,
        subdistrict: subdistrict,
        village: village,
        lite: false));
    final mem = _memory[key];
    if (mem != null) return mem;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsPrefix$key');
      if (raw == null) return null;
      final stored = jsonDecode(raw) as Map<String, dynamic>;
      return HomeBootstrap.parse(
        Map<String, dynamic>.from(stored['body'] as Map),
        lite: stored['lite'] == true,
        fetchedAt: DateTime.tryParse(stored['at']?.toString() ?? ''),
        fromDeviceCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Network fetch (or the in-memory copy while it is within its TTL).
  /// Returns null when the endpoint is unavailable; callers fall back to
  /// the per-section requests.
  Future<HomeBootstrap?> fetch({
    String? lang,
    required String state,
    required String district,
    required String subdistrict,
    required String village,
    bool forceRefresh = false,
  }) async {
    final lite = _preferLite;
    final params = _params(
        lang: lang,
        state: state,
        district: district,
        subdistrict: subdistrict,
        village: village,
        lite: lite);
    final key = _cacheKey(params);
    final mem = _memory[key];
    if (!forceRefresh && mem != null && mem.isFresh) return mem;

    final watch = Stopwatch()..start();
    try {
      final response = await _dio.get(endpoint, queryParameters: params);
      watch.stop();
      // Adapt to the connection for next time.
      _preferLite = watch.elapsed > slowThreshold;

      final body = response.data;
      if (body is! Map) return null;
      final map = Map<String, dynamic>.from(body);
      final result = HomeBootstrap.parse(map, lite: lite);
      _memory[key] = result;
      await _persist(key, map, lite);
      return result;
    } catch (e) {
      watch.stop();
      if (e is DioException &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout)) {
        _preferLite = true;
      }
      debugPrint('[HomeFeed] bootstrap failed: $e');
      return null;
    }
  }

  Future<void> _persist(String key, Map<String, dynamic> body, bool lite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsPrefix$key',
        jsonEncode({
          'at': DateTime.now().toIso8601String(),
          'lite': lite,
          'body': body,
        }),
      );
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTesting() {
    _memory.clear();
    _preferLite = false;
  }
}
