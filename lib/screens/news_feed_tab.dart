import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import '../core/navigation/app_navigator.dart';
import '../core/network/api_response.dart';
import '../models/news_article.dart';
import '../theme/app_theme.dart';
import '../localization/app_translations.dart';
import '../state/app_state.dart';
import 'news_detail_screen.dart';
import 'search_screen.dart';
import 'spotlight_screen.dart';
import 'live_news_screen.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/ad_banner.dart';
import '../widgets/ads/unified_ad_widget.dart';
import '../widgets/ads/rotating_breaking_strip.dart';
import '../services/ad_delivery_service.dart';
import '../services/ad_manager.dart';
import '../repositories/ad_repository.dart';
import '../services/notification_service.dart';
import '../widgets/feed/daily_greeting_widget.dart';
import '../models/category.dart';
import '../models/poll.dart';
import '../widgets/poll_card.dart';
import '../models/live_news.dart';
import '../core/errors/app_exception.dart';
import '../repositories/feed_repository.dart';
import '../repositories/ugc_repository.dart';
import '../core/state/feed_state.dart';
import 'location_selection_screen.dart';
import 'poster_detail_screen.dart';
import '../models/poster_images.dart';

enum HeroCardKind { liveStream, breakingArticle }

class HeroCardItem {
  final HeroCardKind kind;
  final LiveNews? liveStream;
  final NewsArticle? article;

  const HeroCardItem.live(this.liveStream)
      : kind = HeroCardKind.liveStream,
        article = null;

  const HeroCardItem.article(this.article)
      : kind = HeroCardKind.breakingArticle,
        liveStream = null;
}

class NewsFeedTab extends StatefulWidget {
  const NewsFeedTab({super.key});

  @override
  State<NewsFeedTab> createState() => _NewsFeedTabState();
}

class _NewsFeedTabState extends State<NewsFeedTab> {
  late List<NewsArticle> _articles;
  List<NewsArticle> _featuredArticles = [];
  List<NewsArticle> _recommendedArticles = [];
  List<Category> _categories = [];
  List<LiveNews> _liveNewsList = [];
  String? _selectedCategory;
  Poll? _poll;
  List<dynamic> _posters = [];
  List<AdBanner> _feedAds = [];

  /// The ticker strip's own pool. It holds a fixed place above the feed and
  /// rotates through these, so they are kept out of the in-feed ad pool.
  List<AdBanner> get _breakingStripAds =>
      _feedAds.where((ad) => ad.isBreakingStrip).toList();
  Map<String, dynamic>? _dailyQuote;
  bool _isLoadingMore = false;
  String? _nextCursor;
  bool _hasMore = true;
  FeedStatus _feedStatus = FeedStatus.initial;
  String? _feedError;
  String? get _feedLang => AppState.instance.contentLanguage;
  List<NewsArticle> _villageSection = [];
  List<NewsArticle> _mandalSection = [];
  List<NewsArticle> _districtUgc = [];
  List<NewsArticle> _stateUgc = [];
  bool _locationSectionsLoaded = false;
  bool _isProgressivelyHydrated = false;
  int _sectionGeneration = 0;
  int _feedGeneration = 0;
  String get _feedLocationKey => [
        AppState.instance.contentLanguage,
        AppState.instance.city,
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.subdistrict,
        AppState.instance.village,
      ].join('|').toLowerCase();

  final PageController _breakingNewsController = PageController();
  int _currentBreakingIndex = 0;

  late String _preferencesIdentity;

  void _onPreferencesChanged() {
    final identity = _feedLocationKey;
    if (identity == _preferencesIdentity) return;
    _preferencesIdentity = identity;
    ++_sectionGeneration;
    _articles = [];
    _recommendedArticles = [];
    _featuredArticles = [];
    _villageSection = [];
    _mandalSection = [];
    _districtUgc = [];
    _stateUgc = [];
    _feedAds = [];
    _posters = [];
    _poll = null;
    _liveNewsList = [];
    _nextCursor = null;
    _hasMore = true;
    _feedStatus = FeedStatus.loading;
    _refresh();
  }

  @override
  void initState() {
    super.initState();
    _preferencesIdentity = _feedLocationKey;
    AppState.instance.addListener(_onPreferencesChanged);
    _articles = [];
    // 1. Critical primary feed requests for first paint.
    _loadMore();
    _loadCategories();

    // 2. Progressive hydration: defer secondary ancillary metadata past initial frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _isProgressivelyHydrated = true);
      Future.microtask(() {
        _loadLocationSections();
        _loadFeedAds();
        _loadFeatured();
        _loadRecommendations();
        _loadPoll();
        _loadPosters();
        _loadLiveNews();
        _loadDailyQuote();
      });
    });
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onPreferencesChanged);
    _breakingNewsController.dispose();
    super.dispose();
  }

  Future<void> _loadLiveNews() async {
    final queryIdentity = _feedLocationKey;
    try {
      final list = await ApiService.instance.getLiveNews();
      if (mounted && queryIdentity == _feedLocationKey) {
        setState(() => _liveNewsList = list);
      }
    } catch (_) {
      if (mounted && queryIdentity == _feedLocationKey) {
        setState(() => _liveNewsList = []);
      }
    }
  }

  Future<ApiResponse<List<NewsArticle>>?> _settleSectionRequest(
    Future<ApiResponse<List<NewsArticle>>> request,
  ) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLocationSections({bool clearExisting = false}) async {
    final generation = ++_sectionGeneration;
    final state = AppState.instance.stateName;
    final district = AppState.instance.district;
    final subdistrict = AppState.instance.subdistrict;
    final village = AppState.instance.village;

    if (clearExisting && mounted) {
      setState(() {
        _locationSectionsLoaded = false;
        _villageSection = [];
        _mandalSection = [];
        _districtUgc = [];
        _stateUgc = [];
      });
    }

    final requests = <Future<ApiResponse<List<NewsArticle>>?>>[
      if (village.isNotEmpty)
        _settleSectionRequest(
          ApiService.instance.getNewsFeed(
            scope: 'local',
            lang: _feedLang,
            state: state,
            district: district,
            subdistrict: subdistrict.isEmpty ? null : subdistrict,
            village: village,
            pageSize: 10,
            forceRefresh: true,
          ),
        )
      else
        Future.value(null),
      if (village.isNotEmpty)
        _settleSectionRequest(
          UgcRepository.instance.getUgcFeed(
            scope: 'local',
            state: state,
            district: district,
            subdistrict: subdistrict.isEmpty ? null : subdistrict,
            village: village,
            pageSize: 10,
          ),
        )
      else
        Future.value(null),
      if (subdistrict.isNotEmpty)
        _settleSectionRequest(
          ApiService.instance.getNewsFeed(
            scope: 'local',
            lang: _feedLang,
            state: state,
            district: district,
            subdistrict: subdistrict,
            village: '',
            pageSize: 10,
            forceRefresh: true,
          ),
        )
      else
        Future.value(null),
      if (subdistrict.isNotEmpty)
        _settleSectionRequest(
          UgcRepository.instance.getUgcFeed(
            scope: 'local',
            state: state,
            district: district,
            subdistrict: subdistrict,
            pageSize: 10,
          ),
        )
      else
        Future.value(null),
      if (district.isNotEmpty)
        _settleSectionRequest(
          UgcRepository.instance.getUgcFeed(
            scope: 'main',
            state: state,
            district: district,
            pageSize: 10,
          ),
        )
      else
        Future.value(null),
      if (state.isNotEmpty)
        _settleSectionRequest(
          UgcRepository.instance.getUgcFeed(
            scope: 'main',
            state: state,
            pageSize: 10,
          ),
        )
      else
        Future.value(null),
    ];

    final results = await Future.wait(requests);
    if (!mounted || generation != _sectionGeneration) return;

    final villageAdmin = (results[0]?.data ?? <NewsArticle>[]).where(
      (article) =>
          _coverageIs(article, 'local') &&
          _matchesVillage(article, state, district, subdistrict, village),
    );
    final villageUgc = (results[1]?.data ?? <NewsArticle>[]).where(
      (article) =>
          _matchesVillage(article, state, district, subdistrict, village),
    );
    final mergedVillage = _mergeArticles(villageAdmin, villageUgc);

    final mandalAdmin = (results[2]?.data ?? <NewsArticle>[]).where(
      (article) =>
          _coverageIs(article, 'local') &&
          _matchesMandal(article, state, district, subdistrict),
    );
    final mandalUgc = (results[3]?.data ?? <NewsArticle>[]).where(
      (article) => _matchesMandal(article, state, district, subdistrict),
    );
    final villageIds = mergedVillage.map((article) => article.id).toSet();
    final mergedMandal = _mergeArticles(mandalAdmin, mandalUgc)
        .where((article) => !villageIds.contains(article.id))
        .toList();

    setState(() {
      _locationSectionsLoaded = true;
      _villageSection = mergedVillage;
      _mandalSection = mergedMandal;
      _districtUgc = (results[4]?.data ?? <NewsArticle>[])
          .where(
            (article) =>
                _sameLocation(article.state, state) &&
                _sameLocation(article.district, district),
          )
          .toList();
      _stateUgc = (results[5]?.data ?? <NewsArticle>[])
          .where(
            (article) =>
                _sameLocation(article.state, state) &&
                !_hasLocation(article.district),
          )
          .toList();
    });
  }

  bool _hasLocation(String? value) => value?.trim().isNotEmpty == true;

  bool _sameLocation(String? actual, String expected) {
    return _hasLocation(actual) &&
        expected.trim().isNotEmpty &&
        actual!.trim().toLowerCase() == expected.trim().toLowerCase();
  }

  bool _coverageIs(NewsArticle article, String level) {
    return article.coverageLevel.trim().toLowerCase() == level;
  }

  bool _matchesVillage(
    NewsArticle article,
    String state,
    String district,
    String subdistrict,
    String village,
  ) {
    return village.isNotEmpty &&
        _sameLocation(article.state, state) &&
        _sameLocation(article.district, district) &&
        (subdistrict.isEmpty ||
            _sameLocation(article.subdistrict, subdistrict)) &&
        _sameLocation(article.village, village);
  }

  bool _matchesMandal(
    NewsArticle article,
    String state,
    String district,
    String subdistrict,
  ) {
    return subdistrict.isNotEmpty &&
        _sameLocation(article.state, state) &&
        _sameLocation(article.district, district) &&
        _sameLocation(article.subdistrict, subdistrict);
  }

  List<NewsArticle> _mergeArticles(
    Iterable<NewsArticle> first,
    Iterable<NewsArticle> second,
  ) {
    final byId = <String, NewsArticle>{};
    for (final article in [...first, ...second]) {
      byId.putIfAbsent(article.id, () => article);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return merged;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final generation = _feedGeneration;
    final locationKey = _feedLocationKey;
    setState(() {
      _isLoadingMore = true;
      if (_articles.isEmpty) {
        _feedStatus = FeedStatus.loading;
        _feedError = null;
      }
    });

    try {
      if (_articles.isEmpty && _nextCursor == null) {
        final state = await FeedRepository.instance.getInitialFeed(
          scope: 'main',
          category: _selectedCategory,
          lang: _feedLang,
          state: AppState.instance.stateName,
          district: AppState.instance.district,
          pageSize: 25,
        );
        if (!mounted ||
            generation != _feedGeneration ||
            locationKey != _feedLocationKey) {
          return;
        }
        setState(() {
          _articles = List.from(state.items);
          _nextCursor = state.nextCursor;
          _hasMore = state.hasMore;
          _feedStatus = state.status;
          _feedError = state.errorMessage;
        });
      } else {
        final currentState = FeedState<NewsArticle>.success(
          items: _articles,
          nextCursor: _nextCursor,
          hasMore: _hasMore,
        );
        final state = await FeedRepository.instance.loadNextPage(
          currentState: currentState,
          scope: 'main',
          category: _selectedCategory,
          lang: _feedLang,
          state: AppState.instance.stateName,
          district: AppState.instance.district,
          pageSize: 25,
        );
        if (!mounted ||
            generation != _feedGeneration ||
            locationKey != _feedLocationKey) {
          return;
        }
        setState(() {
          _articles = List.from(state.items);
          _nextCursor = state.nextCursor;
          _hasMore = state.hasMore;
          _feedStatus = state.status;
          _feedError = state.errorMessage;
        });
      }

      if (_articles.isNotEmpty) {
        NotificationService.instance.requestPermissionAfterArticlesLoaded();
      }
    } catch (e) {
      if (mounted && _articles.isEmpty) {
        setState(() {
          _feedStatus = FeedStatus.error;
          _feedError = e is AppException
              ? e.message
              : 'కథనాలు లోడ్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.';
        });
      }
    } finally {
      if (mounted && generation == _feedGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadFeatured() async {
    final queryIdentity = _feedLocationKey;
    try {
      final breakingRes = await ApiService.instance.getNewsFeed(
        scope: 'main',
        breaking: true,
        state: AppState.instance.stateName,
        district: AppState.instance.district,
        city: AppState.instance.city,
        lang: _feedLang,
        pageSize: 10,
      );
      if (mounted && (breakingRes.data?.isNotEmpty ?? false)) {
        setState(() => _featuredArticles = breakingRes.data!);
        return;
      }
      final featured = await ApiService.instance.getFeaturedArticles(
        lang: _feedLang,
      );
      if (mounted && queryIdentity == _feedLocationKey) {
        setState(() => _featuredArticles = featured);
      }
    } catch (e) {
      // Silently fail, fall back to empty list
    }
  }

  Future<void> _loadRecommendations() async {
    final queryIdentity = _feedLocationKey;
    try {
      final recs = await ApiService.instance.getRecommendations(limit: 15);
      if (mounted && queryIdentity == _feedLocationKey) {
        setState(() => _recommendedArticles = recs);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService.instance.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadPoll() async {
    final queryIdentity = _feedLocationKey;
    try {
      final polls = await ApiService.instance.getPolls();
      if (mounted && queryIdentity == _feedLocationKey && polls.isNotEmpty) {
        setState(() => _poll = polls.first);
      }
    } catch (_) {}
  }

  Future<void> _loadPosters() async {
    final queryIdentity = _feedLocationKey;
    try {
      final posters = await ApiService.instance.getPosters();
      if (mounted && queryIdentity == _feedLocationKey) {
        setState(() => _posters = posters);
      }
    } catch (_) {}
  }

  Future<void> _loadFeedAds({bool forceRefresh = false}) async {
    final queryIdentity = _feedLocationKey;
    try {
      final response = await AdRepository.instance.getAds(
        placementZone: 'feed',
        scope: 'main',
        forceRefresh: forceRefresh,
      );
      if (mounted &&
          queryIdentity == _feedLocationKey &&
          response.data != null) {
        setState(() => _feedAds = response.data!);
      }
    } catch (_) {}
  }

  Future<void> _loadDailyQuote({bool forceRefresh = false}) async {
    final queryIdentity = _feedLocationKey;
    try {
      final q =
          await ApiService.instance.getRandomQuote(forceRefresh: forceRefresh);
      if (mounted && queryIdentity == _feedLocationKey && q != null) {
        setState(() => _dailyQuote = q);
      }
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final generation = ++_feedGeneration;
    if (mounted) setState(() => _isLoadingMore = false);
    try {
      final currentState = FeedState<NewsArticle>.success(
        items: _articles,
        nextCursor: _nextCursor,
        hasMore: _hasMore,
      );
      final state = await FeedRepository.instance.refreshFeed(
        currentState: currentState,
        scope: 'main',
        category: _selectedCategory,
        lang: _feedLang,
        state: AppState.instance.stateName,
        district: AppState.instance.district,
      );

      if (!mounted || generation != _feedGeneration) return;

      setState(() {
        _articles = List.from(state.items);
        _nextCursor = state.nextCursor;
        _hasMore = state.hasMore;
        _feedStatus = state.status;
        _feedError = state.errorMessage;
        _dailyQuote = null;
      });

      if (state.hasRefreshError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.refreshErrorMessage!),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      AdDeliveryService.instance.resetSession();
      await _loadFeatured();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is AppException
                ? e.message
                : 'రిఫ్రెష్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    await _loadLocationSections();

    // Ancillary sections load in background without blocking
    _loadCategories();
    _loadRecommendations();
    _loadPoll();
    _loadPosters();
    _loadLiveNews();
    _loadFeedAds(forceRefresh: true);
    _loadDailyQuote(forceRefresh: true);
  }

  Future<void> _changeLocation() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LocationSelectionScreen()),
    );
    if (changed != true || !mounted) return;

    setState(() {
      _feedGeneration++;
      _articles = [];
      _featuredArticles = [];
      _recommendedArticles = [];
      _nextCursor = null;
      _hasMore = true;
      _isLoadingMore = false;
      _feedStatus = FeedStatus.loading;
    });
    await Future.wait([
      _loadMore(),
      _loadLocationSections(clearExisting: true),
      _loadFeatured(),
      _loadFeedAds(forceRefresh: true),
    ]);
  }

  Widget _buildCategorySelector() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final cat = isAll ? null : _categories[index - 1];
          final isSelected = isAll
              ? _selectedCategory == null
              : _selectedCategory == cat?.slug;

          return GestureDetector(
            onTap: () {
              if (isSelected) return;
              setState(() {
                _selectedCategory = isAll ? null : cat?.slug;
              });
              _refresh();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
              ),
              child: Center(
                child: Text(
                  isAll ? tr('all') : categoryLabel(cat!.name),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostersStrip() {
    if (_posters.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr('daily_posters'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _posters.length,
            itemBuilder: (context, index) {
              final poster = _posters[index] as Map<String, dynamic>;
              // Shared parser, same as the feed and detail view: the raw
              // `a ?? b` this replaced also missed that the API sends empty
              // strings, so a tile could render blank.
              final images = posterImageUrls(poster);
              final imageUrl = images.isEmpty ? '' : images.first;
              final title = poster['title'] ?? 'Greeting';

              // The strip had no tap handler at all — not a blocked pointer
              // or a bad route, the callback was simply never there, so
              // posters on Home were never openable.
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PosterDetailScreen(poster: poster),
                  ),
                ),
                child: Container(
                width: 130,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(imageUrl,
                              maxWidth: 300),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      child: BackdropFilter(
        filter: dart_ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _changeLocation,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vaaradhi',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    AppState.instance.displayLocation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.search_rounded,
                    color: Theme.of(context).iconTheme.color),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),
              Container(
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.primary),
                  onPressed: () {
                    AppNavigator.pushSafe(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SpotlightScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildBreakingNewsSection(List<HeroCardItem> heroItems) {
    if (heroItems.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    final clampedIndex = _currentBreakingIndex.clamp(0, heroItems.length - 1);

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _breakingNewsController,
            onPageChanged: (index) {
              setState(() => _currentBreakingIndex = index);
            },
            itemCount: heroItems.length,
            itemBuilder: (context, index) {
              final item = heroItems[index];
              final isLive = item.kind == HeroCardKind.liveStream &&
                  item.liveStream != null;
              final stream = item.liveStream;
              final article = item.article;

              final imageUrl = isLive
                  ? (stream?.thumbnailUrl ?? '')
                  : (article?.imageUrl ?? '');
              final title = isLive
                  ? (stream?.title ?? '')
                  : (article?.title ?? '');
              final subtitle = isLive
                  ? (stream?.channelName.isNotEmpty == true
                      ? 'లైవ్ ప్రసారం • ${stream!.channelName}'
                      : 'లైవ్ ప్రసారం • YouTube Live')
                  : 'Updated ${article?.timeAgo ?? ''}';

              return GestureDetector(
                onTap: () {
                  if (isLive) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LiveNewsScreen()),
                    );
                  } else if (article != null) {
                    AppNavigator.pushSafe(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NewsDetailScreen(
                              article: article, slug: article.slug)),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isLive
                          ? Colors.red.withValues(alpha: 0.4)
                          : borderColor,
                      width: isLive ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isLive
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    image: imageUrl.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(imageUrl,
                                maxWidth: 800),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isLive
                            ? [
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.95),
                              ]
                            : [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.4),
                                Colors.black.withValues(alpha: 0.9),
                              ],
                        stops: const [0.4, 0.7, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Stack(
                      children: [
                        if (isLive)
                          Center(
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isLive)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: BackdropFilter(
                                      filter: dart_ui.ImageFilter.blur(
                                          sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFDC2626),
                                              Color(0xFFB91C1C),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'LIVE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: BackdropFilter(
                                      filter: dart_ui.ImageFilter.blur(
                                          sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        color: Colors.orange
                                            .withValues(alpha: 0.3),
                                        child: const Text(
                                          'BREAKING',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isLive &&
                                    stream?.channelName.isNotEmpty == true)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: dart_ui.ImageFilter.blur(
                                          sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          stream!.channelName,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (!isLive &&
                                    article?.category.isNotEmpty == true)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: dart_ui.ImageFilter.blur(
                                          sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Text(
                                          article!.category.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: dart_ui.ImageFilter.blur(
                                  sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                color: Colors.white.withValues(alpha: 0.15),
                                child: Text(
                                  '${(index + 1).toString().padLeft(2, '0')} / ${heroItems.length.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // Pagination Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(heroItems.length, (index) {
            final isActive = index == clampedIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 5,
              width: isActive ? 22 : 5,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : (isDark ? Colors.white24 : Colors.black26),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildForYouHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr('for_you_section'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                tr('cat_local'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedArticleCard(
    FeedPresentationItem<NewsArticle> item,
    Color cardColor,
    Color borderColor,
  ) {
    final article = item.content!;
    return Container(
      key: ValueKey(item.stableKey),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            AdManager.instance.recordContentInteraction();
            AppNavigator.pushSafe(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      NewsDetailScreen(article: article, slug: article.slug)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 96,
                    height: 86,
                    color: Colors.grey.withValues(alpha: 0.1),
                    child: article.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: article.imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            memCacheHeight: 300,
                            placeholder: (_, __) => Container(
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.broken_image_rounded,
                              size: 28,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.article_rounded,
                            size: 32,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
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
                          const Spacer(),
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            article.timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              _locationLabelFor(article),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _locationLabelFor(NewsArticle article) {
    if (_coverageIs(article, 'global')) return 'India / Global';
    if (_coverageIs(article, 'state')) {
      return _hasLocation(article.state)
          ? article.state!.trim()
          : AppState.instance.stateName;
    }
    if (_coverageIs(article, 'district')) {
      final district = _hasLocation(article.district)
          ? article.district!.trim()
          : AppState.instance.district;
      return district.isEmpty ? 'District' : '$district District';
    }
    if (_hasLocation(article.village)) return article.village!.trim();
    if (_hasLocation(article.subdistrict)) return article.subdistrict!.trim();
    if (_hasLocation(article.district)) {
      return '${article.district!.trim()} District';
    }
    return 'Local';
  }

  Widget _buildLocationSection({
    required String title,
    required String location,
    required IconData icon,
    required Color accent,
    required List<NewsArticle> articles,
    required Color cardColor,
    required Color borderColor,
    bool showWhenEmpty = false,
    String emptyMessage = 'ఈ విభాగంలో ఇంకా వార్తలు లేవు.',
  }) {
    if (articles.isEmpty && !showWhenEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (articles.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            )
          else
            ...articles.take(5).map(
                  (article) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: _buildFeedArticleCard(
                      FeedPresentationItem<NewsArticle>.content(
                        article,
                        stableKey: 'section-${article.id}',
                      ),
                      cardColor,
                      borderColor,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedState = AppState.instance.stateName;
    final selectedDistrict = AppState.instance.district;
    final selectedSubdistrict = AppState.instance.subdistrict;
    final selectedVillage = AppState.instance.village;

    final districtSection = _mergeArticles(
      _articles.where(
        (article) =>
            _coverageIs(article, 'district') &&
            _sameLocation(article.district, selectedDistrict),
      ),
      _districtUgc,
    );
    final stateSection = _mergeArticles(
      _articles.where(
        (article) =>
            _coverageIs(article, 'state') &&
            _sameLocation(article.state, selectedState),
      ),
      _stateUgc,
    );
    final globalSection =
        _articles.where((article) => _coverageIs(article, 'global')).toList();
    final sectionIds = {
      ..._villageSection.map((article) => article.id),
      ..._mandalSection.map((article) => article.id),
      ...districtSection.map((article) => article.id),
      ...stateSection.map((article) => article.id),
      ...globalSection.map((article) => article.id),
    };
    final hasHomeContent = _articles.isNotEmpty ||
        _liveNewsList.any((s) => s.isLiveActive) ||
        _villageSection.isNotEmpty ||
        _mandalSection.isNotEmpty ||
        _districtUgc.isNotEmpty ||
        _stateUgc.isNotEmpty ||
        (_locationSectionsLoaded && selectedState.isNotEmpty);
    final breakingNews = _featuredArticles.isNotEmpty
        ? _featuredArticles
        : _articles.take(5).toList();
    final recommendedSource = _recommendedArticles.isNotEmpty
        ? _recommendedArticles
        : _articles.skip(breakingNews == _featuredArticles ? 0 : 5).toList();
    final recommended = recommendedSource
        .where((article) => !sectionIds.contains(article.id))
        .toList();
    final activeStreams = _liveNewsList.where((s) => s.isLiveActive).toList();
    final heroItems = [
      ...activeStreams.map((s) => HeroCardItem.live(s)),
      ...breakingNews.map((a) => HeroCardItem.article(a)),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          !hasHomeContent
              ? (_feedStatus == FeedStatus.loading || _isLoadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : _feedStatus == FeedStatus.error
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 56, color: AppColors.error),
                                const SizedBox(height: 16),
                                const Text(
                                  'కథనాలు లోడ్ చేయడం విఫలమైంది',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _feedError ??
                                      'దయచేసి నెట్‌వర్క్ తనిఖీ చేసి మళ్ళీ ప్రయత్నించండి.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _nextCursor = null;
                                      _hasMore = true;
                                      _feedStatus = FeedStatus.loading;
                                    });
                                    _loadMore();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text('మళ్ళీ ప్రయత్నించండి'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.article_outlined,
                                  size: 56,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              const Text(
                                'కథనాలు అందుబాటులో లేవు',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'తాజా కథనాల కోసం వేచి ఉండండి.',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ))
              : RefreshIndicator(
                  onRefresh: _refresh,
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
                    child: Builder(
                      builder: (context) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final cardColor = isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03);
                        final borderColor = isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05);
                        final feedAdsWithoutBreakingStrip =
                            _feedAds.where((ad) => !ad.isBreakingStrip).toList();
                        
                        final presentationItems = recommended.isNotEmpty
                            ? AdManager.instance
                                .buildFeedPresentation<NewsArticle>(
                                contentItems: recommended,
                                adsPool: feedAdsWithoutBreakingStrip,
                                contentKey: (article) =>
                                    '${article.contentKind}:${article.id}',
                              )
                            : <FeedPresentationItem<NewsArticle>>[];

                        return CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top +
                                    (_breakingStripAds.isNotEmpty ? 120 : 70), // Space for floating app bar & breaking strip
                              ),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    RepaintBoundary(
                                      child: _buildCategorySelector(),
                                    ),
                                    RepaintBoundary(
                                      child: _buildBreakingNewsSection(
                                          heroItems),
                                    ),
                                    if (selectedVillage.isNotEmpty)
                                      _buildLocationSection(
                                        title:
                                            '$selectedVillage స్థానిక వార్తలు',
                                        location: selectedVillage,
                                        icon: Icons.holiday_village_outlined,
                                        accent: AppColors.primary,
                                        articles: _villageSection,
                                        cardColor: cardColor,
                                        borderColor: borderColor,
                                        showWhenEmpty: true,
                                        emptyMessage:
                                            'ఈ ప్రాంతానికి ఇంకా స్థానిక వార్తలు లేవు. దగ్గరి ప్రాంతాల వార్తలు కింద కనిపిస్తాయి.',
                                      ),
                                    if (_isProgressivelyHydrated) ...[
                                      if (selectedSubdistrict.isNotEmpty)
                                        _buildLocationSection(
                                          title:
                                              '$selectedSubdistrict మండల వార్తలు',
                                          location: selectedSubdistrict,
                                          icon: Icons.location_city_outlined,
                                          accent: Colors.teal,
                                          articles: _mandalSection,
                                          cardColor: cardColor,
                                          borderColor: borderColor,
                                          showWhenEmpty: true,
                                          emptyMessage:
                                              'ఈ మండలంలో ఇంకా వార్తలు లేవు. జిల్లా మరియు రాష్ట్ర వార్తలు కింద కనిపిస్తాయి.',
                                        ),
                                      if (selectedDistrict.isNotEmpty)
                                        _buildLocationSection(
                                          title:
                                              '$selectedDistrict జిల్లా వార్తలు',
                                          location: '$selectedDistrict జిల్లా',
                                          icon: Icons.domain_outlined,
                                          accent: Colors.indigo,
                                          articles: districtSection,
                                          cardColor: cardColor,
                                          borderColor: borderColor,
                                          showWhenEmpty: true,
                                        ),
                                      if (selectedState.isNotEmpty)
                                        _buildLocationSection(
                                          title: '$selectedState ముఖ్యాంశాలు',
                                          location: selectedState,
                                          icon: Icons.map_outlined,
                                          accent: Colors.deepOrange,
                                          articles: stateSection,
                                          cardColor: cardColor,
                                          borderColor: borderColor,
                                          showWhenEmpty: true,
                                        ),
                                      _buildLocationSection(
                                        title: 'జాతీయ / అంతర్జాతీయ వార్తలు',
                                        location: 'జాతీయం / అంతర్జాతీయం',
                                        icon: Icons.public_outlined,
                                        accent: Colors.blueGrey,
                                        articles: globalSection,
                                        cardColor: cardColor,
                                        borderColor: borderColor,
                                        showWhenEmpty: true,
                                      ),
                                      if (_dailyQuote != null &&
                                          (_dailyQuote!['text'] != null ||
                                              _dailyQuote!['quote'] !=
                                                  null)) ...[
                                        const SizedBox(height: 16),
                                        DailyGreetingWidget(
                                          imageUrl: _dailyQuote!['image_url'] ??
                                              _dailyQuote!['imageUrl'] ??
                                              '',
                                          title: _dailyQuote!['author'] ??
                                              'Daily Quote',
                                          quote: _dailyQuote!['text'] ??
                                              _dailyQuote!['quote'] ??
                                              '',
                                        ),
                                      ],
                                      if (_poll != null) ...[
                                        const SizedBox(height: 16),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: PollCard(poll: _poll!),
                                        ),
                                      ],
                                      if (_posters.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        _buildPostersStrip(),
                                      ],
                                    ],
                                    const SizedBox(height: 16),
                                    if (recommended.isNotEmpty)
                                      _buildForYouHeader(),
                                  ],
                                ),
                              ),
                            ),
                            if (presentationItems.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, top: 8, bottom: 120),
                                sliver: SliverList.separated(
                                  itemCount: presentationItems.length +
                                      (_hasMore ? 1 : 0),
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    if (index == presentationItems.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }

                                    final item = presentationItems[index];
                                    if (item.isAd && item.ad != null) {
                                      return UnifiedAdWidget(
                                        key: ValueKey(item.stableKey),
                                        ad: item.ad!,
                                        placementZone: 'feed',
                                        exposureKey:
                                            'home_${_feedLocationKey}_${_feedGeneration}_${item.stableKey}',
                                      );
                                    }

                                    return _buildFeedArticleCard(
                                        item, cardColor, borderColor);
                                  },
                                ),
                              )
                            else
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 120),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

          // Floating Top App Bar Layer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopAppBar(),
                if (_breakingStripAds.isNotEmpty)
                  RotatingBreakingStrip(
                    ads: _breakingStripAds,
                    placementZone: 'feed',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
