import 'news_article.dart';

/// Why a search failed, for the message the screen shows (search handover).
enum SearchErrorKind {
  /// 400: missing or invalid query / filter.
  invalidQuery,

  /// 403.
  forbidden,

  /// 429: too many searches; not retried automatically.
  rateLimited,

  /// 5xx, timeout, no connection.
  unavailable,
}

/// `GET /api/v1/search/` response.
///
/// Universal search (Oct 2026) adds `sections` (one list per content type),
/// `counts`, `universal_result_count` and `pagination` beside the legacy
/// `results` article list. Both are read: [hasSections] is false on an
/// older backend, and the screen then shows [results] as before.
class SearchResult {
  const SearchResult({
    required this.results,
    required this.suggestions,
    this.cacheTtlSeconds = 0,
    this.error,
    this.errorKind,
    this.sections = const {},
    this.hasSections = false,
    this.resultCount = 0,
    this.universalResultCount = 0,
    this.sectionKeys = const {},
  });

  /// Legacy article results (`results`), used for the paginated
  /// "all articles" page.
  final List<NewsArticle> results;
  final List<String> suggestions;
  final int cacheTtlSeconds;
  final String? error;
  final SearchErrorKind? errorKind;

  /// Section key → its items as sent. Only non-empty lists are kept.
  final Map<String, List<Map<String, dynamic>>> sections;

  /// The backend sent `sections` (universal search).
  final bool hasSections;

  /// Total matching articles (legacy pagination).
  final int resultCount;

  /// Direct matches across every section, recommendations not included.
  final int universalResultCount;

  /// The section keys the backend sent (empty lists included).
  final Set<String> sectionKeys;

  /// Most items a universal section carries (backend, Oct 2026). A full
  /// section may have more, reachable from that content's own screen.
  static const sectionLimit = 8;

  /// The articles to show: `sections.articles`, or `results` when that key
  /// is missing (backend contract) or the backend is older.
  List<NewsArticle> get articles => hasSections &&
          sectionKeys.contains('articles')
      ? section('articles').map(NewsArticle.fromJson).toList()
      : results;

  /// Display order (search handover). `recommendations` is last and never
  /// counted as a result.
  static const sectionOrder = [
    'articles',
    'ugc',
    'live_news',
    'videos',
    'posters',
    'polls',
    'quotes',
    'categories',
    'blogs',
    'epapers',
    'trends',
    'recommendations',
  ];

  /// Non-empty sections in [sectionOrder]; unknown sections are ignored.
  List<String> get orderedSections =>
      [for (final k in sectionOrder) if (sections[k]?.isNotEmpty ?? false) k];

  List<Map<String, dynamic>> section(String key) => sections[key] ?? const [];

  /// No direct matches (recommendations do not count).
  bool get noDirectResults => hasSections
      ? universalResultCount == 0 &&
          orderedSections.every((k) => k == 'recommendations')
      : results.isEmpty;

  /// Nothing at all to show: no matches, recommendations or suggestions.
  bool get isEmpty =>
      noDirectResults && section('recommendations').isEmpty && suggestions.isEmpty;

  static SearchResult parse(dynamic body) {
    dynamic data = body is Map ? (body['data'] ?? body) : body;

    List<NewsArticle> results = const [];
    List<String> suggestions = const [];
    var ttl = 0;
    final sections = <String, List<Map<String, dynamic>>>{};
    var hasSections = false;
    var resultCount = 0;
    var universal = 0;
    final keys = <String>{};

    List<NewsArticle> articles(dynamic list) => list is List
        ? list
            .whereType<Map>()
            .map((m) => NewsArticle.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : const [];

    int asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    if (data is Map) {
      results = articles(
          data['results'] ?? data['articles'] ?? data['items'] ?? data['data']);
      final raw = data['suggestions'];
      if (raw is List) {
        suggestions = raw
            .map((s) => s is Map
                ? (s['text'] ?? s['query'] ?? s['keyword'] ?? s['title'])
                : s)
            .whereType<Object>()
            .map((s) => s.toString().trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
      }
      final t = data['cache_ttl_seconds'] ??
          (body is Map ? body['cache_ttl_seconds'] : null);
      if (t is num) ttl = t.toInt();

      final rawSections = data['sections'];
      if (rawSections is Map) {
        hasSections = true;
        rawSections.forEach((key, value) {
          keys.add(key.toString());
          if (value is List) {
            final items = value
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
            if (items.isNotEmpty) sections[key.toString()] = items;
          }
        });
      }
      resultCount = asInt(data['result_count'] ?? results.length);
      universal = data['universal_result_count'] != null
          ? asInt(data['universal_result_count'])
          : resultCount;
    } else if (data is List) {
      results = articles(data);
      resultCount = results.length;
      universal = resultCount;
    }

    return SearchResult(
      results: results,
      suggestions: suggestions,
      cacheTtlSeconds: ttl,
      sections: sections,
      hasSections: hasSections,
      resultCount: resultCount,
      universalResultCount: universal,
      sectionKeys: keys,
    );
  }

  /// The failure for an HTTP [status] (null: network or timeout).
  static SearchErrorKind errorKindFor(int? status) {
    if (status == 400 || status == 422) return SearchErrorKind.invalidQuery;
    if (status == 403) return SearchErrorKind.forbidden;
    if (status == 429) return SearchErrorKind.rateLimited;
    return SearchErrorKind.unavailable;
  }
}
