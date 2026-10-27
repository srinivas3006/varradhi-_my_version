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
  final Map<String, ({NewsArticle article, DateTime at})> _cache = {};
  final Map<String, Future<NewsArticle>> _pending = {};

  /// How long a fetched article is reused. It was kept for the whole
  /// session: the Spotlight card shows the detail copy over the feed copy,
  /// so an edit made after first view (e.g. a second image added) never
  /// appeared until the app restarted. Short enough for edits to show, long
  /// enough that swiping back and forth does not refetch.
  static const cacheTtl = Duration(minutes: 2);

  /// Clock, replaceable in tests.
  DateTime Function() now = DateTime.now;

  /// Fetches article detail by slug, reusing a copy fetched within
  /// [cacheTtl].
  Future<NewsArticle> getDetail(String slug, {bool forceRefresh = false}) async {
    final cached = _cache[slug];
    if (!forceRefresh &&
        cached != null &&
        now().difference(cached.at) < cacheTtl) {
      return cached.article;
    }
    final pending = _pending[slug];
    if (pending != null) return pending;
    final request = ApiService.instance.getArticleDetail(slug);
    _pending[slug] = request;
    try {
      final article = await request;
      _cache[slug] = (article: article, at: now());
      return article;
    } finally {
      if (identical(_pending[slug], request)) _pending.remove(slug);
    }
  }

  /// The cached copy of [slug], at once (no await), even if older than
  /// [cacheTtl]; null if never fetched. Lets a card that is built again
  /// (swiped back to, or rebuilt by the pager) draw its final story in its
  /// first frame instead of the feed's short summary and then the full
  /// text a frame later.
  NewsArticle? peekDetail(String slug) => _cache[slug]?.article;

  /// Whether the cached copy of [slug] is within [cacheTtl].
  bool isFresh(String slug) {
    final cached = _cache[slug];
    return cached != null && now().difference(cached.at) < cacheTtl;
  }

  /// Fetches [slug] in the background (no-op when fresh or already in
  /// flight); errors are left for the screen that shows it.
  void prefetchDetail(String slug) {
    if (slug.isEmpty || isFresh(slug) || _pending.containsKey(slug)) return;
    getDetail(slug).then<void>((_) {}, onError: (_) {});
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
