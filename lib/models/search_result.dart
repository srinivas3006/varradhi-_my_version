import 'news_article.dart';

/// `GET /api/v1/search/` response: results plus the keyword suggestions the
/// backend returns so a zero-result search still has somewhere to go.
class SearchResult {
  const SearchResult({
    required this.results,
    required this.suggestions,
    this.cacheTtlSeconds = 0,
    this.error,
  });

  final List<NewsArticle> results;
  final List<String> suggestions;
  final int cacheTtlSeconds;
  final String? error;

  static SearchResult parse(dynamic body) {
    dynamic data = body is Map ? (body['data'] ?? body) : body;

    List<NewsArticle> results = const [];
    List<String> suggestions = const [];
    var ttl = 0;

    List<NewsArticle> articles(dynamic list) => list is List
        ? list
            .whereType<Map>()
            .map((m) => NewsArticle.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : const [];

    if (data is Map) {
      results = articles(data['results'] ??
          data['articles'] ??
          data['items'] ??
          data['data']);
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
      final t = data['cache_ttl_seconds'] ?? (body is Map ? body['cache_ttl_seconds'] : null);
      if (t is num) ttl = t.toInt();
    } else if (data is List) {
      results = articles(data);
    }

    return SearchResult(
        results: results, suggestions: suggestions, cacheTtlSeconds: ttl);
  }
}
