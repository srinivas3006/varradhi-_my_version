import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/news_article.dart';
import '../core/errors/app_exception.dart';
import '../services/api_service.dart';
import '../theme/article_typography.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../core/ads/ad_insertion.dart';
import '../core/ads/ad_placement.dart';
import '../core/ads/zone_ads.dart';
import '../models/ad_banner.dart';
import '../widgets/ads/unified_ad_widget.dart';
import 'news_detail_screen.dart';

/// Screen 08: CategoryScreen
/// - API: GET /api/v1/articles/feed/?category={category_slug}&state=...&district=...&city=...&lang=...
/// - For local category: scope=local
/// - Destination: NewsDetailScreen (ArticleDetailScreen)
class CategoryScreen extends StatefulWidget {
  final String categorySlug;
  final String categoryName;
  final String? scope;

  const CategoryScreen({
    super.key,
    required this.categorySlug,
    required this.categoryName,
    this.scope,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final List<NewsArticle> _articles = [];
  bool _isLoading = true;
  bool _refreshing = false;
  int _generation = 0;
  bool _isLoadingMore = false;
  String? _nextCursor;
  bool _hasMore = true;
  String? _error;

  /// `category` zone ads, placed between stories.
  List<AdBanner> _zoneAds = const [];
  late String _queryIdentity;
  String get _currentQueryIdentity => [
        AppState.instance.contentLanguage,
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.city,
        AppState.instance.subdistrict,
        AppState.instance.village,
      ].join('|');

  void _onPreferencesChanged() {
    final identity = _currentQueryIdentity;
    if (identity == _queryIdentity) return;
    _queryIdentity = identity;
    _articles.clear();
    _nextCursor = null;
    _hasMore = true;
    _fetchArticles();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  String? get _feedLang => AppState.instance.contentLanguage;

  @override
  void initState() {
    super.initState();
    _queryIdentity = _currentQueryIdentity;
    AppState.instance.addListener(_onPreferencesChanged);
    _fetchArticles();
  }

  Future<void> _loadZoneAds(int generation) async {
    final ads = await ZoneAds.load(AdPlacement.category);
    if (mounted && generation == _generation) {
      setState(() => _zoneAds = ads);
    }
  }

  Future<void> _fetchArticles() async {
    final generation = ++_generation;
    _loadZoneAds(generation);
    _refreshing = true;
    setState(() {
      _isLoading = _articles.isEmpty;
      _isLoadingMore = false;
      _error = null;
    });

    try {
      final response = await ApiService.instance.getNewsFeed(
        category: widget.categorySlug,
        scope: widget.scope == 'local' ? 'local' : null,
        // Chosen place only; none chosen → broad feed (backend contract).
        state: AppState.instance.feedPlace.state,
        district: AppState.instance.feedPlace.district,
        city: AppState.instance.hasValidLocation ? AppState.instance.city : '',
        subdistrict: AppState.instance.feedPlace.subdistrict,
        village: AppState.instance.feedPlace.village,
        lang: _feedLang,
        pageSize: 20,
      );

      if (!mounted || generation != _generation) return;
      if (response.hasErrors) {
        throw ApiException(response.errorMessage ?? 'Unable to load articles.');
      }
      setState(() {
        _articles.clear();
        _articles.addAll(response.data ?? []);
        _nextCursor = response.nextCursor;
        _hasMore = response.nextCursor != null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } finally {
      if (generation == _generation) _refreshing = false;
    }
  }

  Future<void> _loadMore() async {
    if (_refreshing || _isLoadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _isLoadingMore = true);

    try {
      final response = await ApiService.instance.getNewsFeed(
        category: widget.categorySlug,
        scope: widget.scope == 'local' ? 'local' : null,
        // Chosen place only; none chosen → broad feed (backend contract).
        state: AppState.instance.feedPlace.state,
        district: AppState.instance.feedPlace.district,
        city: AppState.instance.hasValidLocation ? AppState.instance.city : '',
        subdistrict: AppState.instance.feedPlace.subdistrict,
        village: AppState.instance.feedPlace.village,
        lang: _feedLang,
        cursor: _nextCursor,
        pageSize: 20,
      );

      if (!mounted || generation != _generation) return;
      if (response.hasErrors) {
        throw ApiException(response.errorMessage ?? 'Unable to load articles.');
      }
      final newArticles = response.data ?? [];
      setState(() {
        final seen = _articles.map((article) => article.id).toSet();
        _articles.addAll(newArticles.where((article) => seen.add(article.id)));
        _nextCursor = response.nextCursor;
        _hasMore = response.nextCursor != null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'మరిన్ని కథనాలను లోడ్ చేయడం సాధ్యం కాలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.')),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.categoryName),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _articles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchArticles,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('మళ్లీ ప్రయత్నించండి'),
                      ),
                    ],
                  ),
                )
              : _articles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.feed_outlined,
                              size: 56,
                              color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 12),
                          const Text(
                            'ఈ విభాగంలో కథనాలు ఏవీ లేవు.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchArticles,
                      color: AppColors.primary,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo.metrics.pixels >=
                                  scrollInfo.metrics.maxScrollExtent - 200 &&
                              !_isLoadingMore) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: Builder(builder: (context) {
                          // At least 6 stories apart, none in the first 3.
                          final adAfter = adSlotsAfter<NewsArticle>(
                            contentItems: _articles,
                            eligibleAds: _zoneAds,
                            placementZone: AdPlacement.category,
                            policy: AdFrequencyPolicy.category,
                          );
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            itemCount: _articles.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              if (index == _articles.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final article = _articles[index];
                              final ad = adAfter[index];

                              final card = GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewsDetailScreen(
                                        article: article,
                                        slug: article.slug,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 95,
                                      height: 95,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: cardColor,
                                        border: Border.all(color: borderColor),
                                        image: article.imageUrl.isNotEmpty
                                            ? DecorationImage(
                                                image:
                                                    CachedNetworkImageProvider(
                                                        article.imageUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              article.category.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.primary,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            article.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: ArticleTypography.heading(
                                              fontSize: 14.5,
                                              color: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.color ??
                                                  (isDark
                                                      ? AppColors.textLight
                                                      : AppColors.textDark),
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time_rounded,
                                                size: 12,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                article.timeAgo,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6),
                                                child: Text('•',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.color)),
                                              ),
                                              Icon(
                                                Icons.favorite_rounded,
                                                size: 12,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${article.likes}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (ad == null) return card;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  card,
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14.0),
                                    child: UnifiedAdWidget(
                                      key: ValueKey(
                                          'category_ad_${ad.id}_$index'),
                                      ad: ad,
                                      placementZone: AdPlacement.category,
                                      exposureKey:
                                          'category_${widget.categorySlug}_${ad.id}_$index',
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        }),
                      ),
                    ),
    );
  }
}
