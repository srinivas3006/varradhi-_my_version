import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_article.dart';
import '../models/unified_feed_item.dart';
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

/// Identity of a story across Home's lists. Article and citizen-post ids are
/// separate namespaces, so the kind is part of the key: `article:<id>`.
String homeStoryKey(NewsArticle a) =>
    '${a.contentKind}:${a.id.isNotEmpty ? a.id : a.slug}';

/// The hero carousel, built only from the `/feed/home/` response:
/// live streams, then breaking articles, then featured articles, each once
/// (by [homeStoryKey]). With none of those, the first five personalized.
List<NewsArticle> homeHeroStories(
  List<NewsArticle> personalized,
  List<NewsArticle> local, {
  int max = 10,
}) {
  final all = [...personalized, ...local];
  final seen = <String>{};
  final hero = <NewsArticle>[
    ...all.where((a) => a.contentKind == 'live'),
    ...all.where((a) => a.contentKind == 'article' && a.isBreaking),
    ...all.where((a) => a.contentKind == 'article' && a.isFeatured),
  ].where((a) => seen.add(homeStoryKey(a))).toList();
  if (hero.isNotEmpty) return hero.take(max).toList();
  return personalized.take(5).toList();
}

/// The For You rail, from the `personalized` section:
/// - newest first — the server's ranking put 10-day-old stories ahead of
///   newer ones;
/// - without live streams and anything the hero already shows, so the rail
///   never repeats the carousel above it;
/// - only the last [freshWindow] when at least [minFresh] such stories
///   exist, so older ones drop out once there is fresh news. With fewer,
///   all of them, newest first, rather than an empty rail.
List<NewsArticle> homeForYouStories(
  List<NewsArticle> personalized,
  List<NewsArticle> hero, {
  DateTime? now,
  Duration freshWindow = const Duration(days: 3),
  int minFresh = 4,
}) {
  final inHero = hero.map(homeStoryKey).toSet();
  final seen = <String>{};
  final stories = personalized
      .where((a) => a.contentKind != 'live')
      .where((a) => !inHero.contains(homeStoryKey(a)))
      .where((a) => seen.add(homeStoryKey(a)))
      .toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  final cutoff = (now ?? DateTime.now()).subtract(freshWindow);
  final fresh = stories.where((a) => a.publishedAt.isAfter(cutoff)).toList();
  return fresh.length >= minFresh ? fresh : stories;
}

/// One page of `GET /api/v1/feed/`.
class LatestPage {
  const LatestPage({required this.items, this.next});

  /// Stories of type article, ugc or live, in server order.
  final List<NewsArticle> items;

  /// `meta.next` exactly as sent; null on the last page.
  final String? next;

  static const _types = {'article', 'ugc', 'live'};

  static LatestPage parse(dynamic body) {
    final map = body is Map ? Map<String, dynamic>.from(body) : const {};
    final data = map['data'];
    final list = data is List
        ? data
        : data is Map
            ? (data['results'] ?? data['items'] ?? const [])
            : const [];
    final items = <NewsArticle>[];
    for (final raw in list is List ? list : const []) {
      if (raw is! Map) continue;
      try {
        final item = UnifiedFeedItem.fromJson(Map<String, dynamic>.from(raw));
        if (!_types.contains(item.type) || item.id.isEmpty) continue;
        items.add(item.toArticle());
      } catch (e) {
        debugPrint('[HomeFeed] skipped malformed /feed/ item: $e');
      }
    }
    final meta = map['meta'];
    final next = meta is Map ? meta['next']?.toString() : null;
    return LatestPage(
      items: items,
      next: (next == null || next.trim().isEmpty) ? null : next.trim(),
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

  /// Query for `/feed/home/`. No `scope`: the endpoint builds both the main
  /// (personalized) and the local section itself.
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
        'mode': lite ? 'lite' : 'normal',
        'limit': '$limit',
        if (state.isNotEmpty) 'state': state,
        if (district.isNotEmpty) 'district': district,
        if (subdistrict.isNotEmpty) 'subdistrict': subdistrict,
        if (village.isNotEmpty) 'village': village,
      };

  /// Keyed by who is reading (`user:<id>` or `guest`), language, location
  /// and mode, so one account's personalized Home is never shown to another.
  static String _cacheKey(String viewer, Map<String, String> p) {
    final keys = p.keys.toList()..sort();
    return 'viewer=$viewer&${keys.map((k) => '$k=${p[k]}').join('&')}'
        .toLowerCase();
  }

  /// HTTP status of the last failed `/feed/home/` load (null for a network
  /// or timeout failure), so the screen can tell 429 from 5xx from offline.
  int? lastFailureStatus;

  /// The last Home kept for this viewer and place, if any — shown at once
  /// while the network refreshes it (stale-while-refresh). Tries the mode
  /// the next request will use first, then the other.
  Future<HomeBootstrap?> cached({
    required String viewer,
    String? lang,
    required String state,
    required String district,
    required String subdistrict,
    required String village,
  }) async {
    for (final lite in [_preferLite, !_preferLite]) {
      final key = _cacheKey(
          viewer,
          _params(
              lang: lang,
              state: state,
              district: district,
              subdistrict: subdistrict,
              village: village,
              lite: lite));
      final mem = _memory[key];
      if (mem != null) return mem;
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_prefsPrefix$key');
        if (raw == null) continue;
        final stored = jsonDecode(raw) as Map<String, dynamic>;
        return HomeBootstrap.parse(
          Map<String, dynamic>.from(stored['body'] as Map),
          lite: stored['lite'] == true,
          fetchedAt: DateTime.tryParse(stored['at']?.toString() ?? ''),
          fromDeviceCache: true,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// `GET /api/v1/feed/home/` (or the in-memory copy while it is within its
  /// TTL). Returns null on failure, with [lastFailureStatus] set; the cached
  /// copy is left untouched so the screen keeps showing it.
  Future<HomeBootstrap?> fetch({
    required String viewer,
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
    final key = _cacheKey(viewer, params);
    final mem = _memory[key];
    if (!forceRefresh && mem != null && mem.isFresh) return mem;

    final watch = Stopwatch()..start();
    try {
      final response = await _dio.get(endpoint, queryParameters: params);
      watch.stop();
      // Adapt to the connection for next time.
      _preferLite = watch.elapsed > slowThreshold;

      final body = response.data;
      if (body is! Map) {
        lastFailureStatus = response.statusCode;
        return null;
      }
      final map = Map<String, dynamic>.from(body);
      final result = HomeBootstrap.parse(map, lite: lite);
      _memory[key] = result;
      lastFailureStatus = null;
      await _persist(key, map, lite);
      return result;
    } catch (e) {
      watch.stop();
      lastFailureStatus = e is DioException ? e.response?.statusCode : null;
      if (e is DioException &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout)) {
        _preferLite = true;
      }
      debugPrint('[HomeFeed] /feed/home/ failed: $e');
      return null;
    }
  }

  // --- Latest: GET /api/v1/feed/ ------------------------------------------

  static const latestEndpoint = '/api/v1/feed/';

  /// One page of the Latest list — articles, citizen posts and live streams
  /// in one normalized list. Pass [next] exactly as the previous page's
  /// `meta.next` returned it; the first page is built from the rest.
  /// Throws on failure so the caller keeps what it already shows.
  Future<LatestPage> fetchLatest({
    String? next,
    String? lang,
    required String state,
    required String district,
    required String subdistrict,
    required String village,
    String? category,
    int pageSize = 20,
  }) async {
    final response = next != null
        ? await _dio.get(next)
        : await _dio.get(latestEndpoint, queryParameters: {
            'include': 'all',
            'scope': 'main',
            if (lang != null && lang.isNotEmpty) 'lang': lang,
            'page_size': pageSize,
            if (state.isNotEmpty) 'state': state,
            if (district.isNotEmpty) 'district': district,
            if (subdistrict.isNotEmpty) 'subdistrict': subdistrict,
            if (village.isNotEmpty) 'village': village,
            if (category != null && category.isNotEmpty) 'category': category,
          });
    return LatestPage.parse(response.data);
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
    lastFailureStatus = null;
  }
}
