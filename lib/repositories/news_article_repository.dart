import '../services/api_service.dart';
import '../models/news_article.dart';

class NewsArticleRepository {
  NewsArticleRepository._internal();
  static final NewsArticleRepository instance = NewsArticleRepository._internal();

  final Map<String, NewsArticle> _cache = {};

  Future<NewsArticle> getDetail(String slug, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(slug)) return _cache[slug]!;
    final article = await ApiService.instance.getArticleDetail(slug);
    _cache[slug] = article;
    return article;
  }

  Future<NewsArticle> getArticleBySlug(String slug, {bool forceRefresh = false}) {
    return getDetail(slug, forceRefresh: forceRefresh);
  }

  void clearCache() => _cache.clear();
}
