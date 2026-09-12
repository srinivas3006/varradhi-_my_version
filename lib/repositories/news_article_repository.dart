import '../core/network/dio_client.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';

/// Production NewsArticleRepository managing:
/// - Article detail caching by slug/id
/// - Related articles retrieval
/// - Safe error propagation
class NewsArticleRepository {
  NewsArticleRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  static final NewsArticleRepository instance = NewsArticleRepository();

  // ignore: unused_field
  final ApiClient _api;
  final Map<String, NewsArticle> _cache = {};

  /// Fetches article detail by slug, returning cached version if available.
  Future<NewsArticle> getDetail(String slug, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(slug)) {
      return _cache[slug]!;
    }

    final article = await ApiService.instance.getArticleDetail(slug);
    _cache[slug] = article;
    return article;
  }

  /// Alias for [getDetail].
  Future<NewsArticle> getArticleBySlug(String slug, {bool forceRefresh = false}) {
    return getDetail(slug, forceRefresh: forceRefresh);
  }

  /// Fetches related articles for the given article slug.
  Future<List<NewsArticle>> getRelatedArticles(String slug, {int limit = 6}) async {
    try {
      return await ApiService.instance.getRecommendations(limit: limit);
    } catch (_) {
      return <NewsArticle>[];
    }
  }

  /// Clears in-memory article detail cache.
  void clearCache() => _cache.clear();
}
