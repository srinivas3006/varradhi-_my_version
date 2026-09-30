import 'dart:async';
import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import '../core/navigation/app_navigator.dart';
import '../models/news_article.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../localization/app_translations.dart';
import '../state/app_state.dart';
import 'news_detail_screen.dart';
import 'search_screen.dart';
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
import '../repositories/home_feed_repository.dart';
import '../core/ads/home_ads.dart';
import '../services/analytics_queue.dart';
import 'profile_tab.dart';
import 'poster_detail_screen.dart';
import '../models/poster_images.dart';
import '../models/video_item.dart';
import '../repositories/video_repository.dart';
import 'video_player_screen.dart';
import 'notifications_screen.dart';

class NewsFeedTab extends StatefulWidget {
  const NewsFeedTab({super.key});

  @override
  State<NewsFeedTab> createState() => _NewsFeedTabState();
}

class _NewsFeedTabState extends State<NewsFeedTab> {
  // Home loads news from exactly two endpoints:
  //   GET /api/v1/feed/home/  — For You, Near You, and the hero's source
  //   GET /api/v1/feed/       — the Latest list, paged by meta.next
  // Everything else on the screen is a widget with its own API: categories,
  // ads (one request, shared through HomeAds), polls, posters, videos and
  // the daily quote. A widget that fails hides itself; Home stays up.

  /// From `/feed/home/`: `personalized` → For You, `local` → Near You.
  List<NewsArticle> _forYou = [];
  List<NewsArticle> _nearYou = [];
  bool _bootstrapLite = false;

  /// True once a Home response — cached or fresh — has been applied.
  bool _homeLoaded = false;

  /// The last `/feed/home/` refresh failed; what is shown is the cached copy.
  bool _homeFailed = false;
  Timer? _homeRetryTimer;

  /// From `/feed/`: the Latest list and the exact `meta.next` of its last
  /// page (null = no more).
  List<NewsArticle> _latest = [];
  String? _latestNext;
  bool _latestHasMore = true;
  bool _latestLoading = false;
  bool _latestLoaded = false;
  bool _latestFailed = false;

  List<Category> _categories = [];
  String? _selectedCategory;
  Poll? _poll;
  List<dynamic> _posters = [];

  /// Regular videos for the Home carousel, from /articles/video-feed/.
  /// Thumbnails only — nothing here creates a player or autoplays.
  /// Shorts live in the Reels tab, which reads /shorts-feed/.
  List<VideoItem> _homeVideos = [];
  List<AdBanner> _feedAds = [];

  /// The ticker strip's own pool. It holds a fixed place above the feed and
  /// rotates through these, so they are kept out of the in-feed ad pool.
  List<AdBanner> get _breakingStripAds => HomeAds.breakingStrip(_feedAds);
  Map<String, dynamic>? _dailyQuote;
  String? get _feedLang => AppState.instance.contentLanguage;
  bool _isProgressivelyHydrated = false;

  /// Bumped when the reader, language or location changes. A response is
  /// applied only if it was requested under the current generation, so a
  /// slow answer for the old place can never land on the new one.
  int _generation = 0;

  /// Bumped whenever the Latest list restarts (refresh, category), so an
  /// older page still in flight is dropped.
  int _latestGeneration = 0;

  /// Who is reading: the personalized Home belongs to one account.
  String get _viewer {
    final app = AppState.instance;
    if (!app.isLoggedIn) return 'guest';
    final id = app.userId;
    return (id != null && id.isNotEmpty) ? 'user:$id' : 'user';
  }

  String get _homeIdentity => [
        _viewer,
        AppState.instance.contentLanguage,
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.subdistrict,
        AppState.instance.village,
      ].join('|').toLowerCase();

  final PageController _breakingNewsController = PageController();
  int _currentBreakingIndex = 0;

  late String _identity;

  /// Same story in two lists is one story (see [homeStoryKey]).
  static String _storyKey(NewsArticle a) => homeStoryKey(a);

  void _onAppStateChanged() {
    final identity = _homeIdentity;
    if (identity == _identity) return;
    // New reader, language or place: drop everything in flight, restart
    // pagination and load Home for the new identity.
    _identity = identity;
    final generation = ++_generation;
    ++_latestGeneration;
    _homeRetryTimer?.cancel();
    setState(() {
      _forYou = [];
      _nearYou = [];
      _homeLoaded = false;
      _homeFailed = false;
      _latest = [];
      _latestNext = null;
      _latestHasMore = true;
      _latestLoading = false;
      _latestLoaded = false;
      _latestFailed = false;
      _currentBreakingIndex = 0;
    });
    _loadHome(generation);
    _loadLatest(reset: true);
    _loadWidgets(generation, forceRefresh: true);
  }

  @override
  void initState() {
    super.initState();
    _identity = _homeIdentity;
    AppState.instance.addListener(_onAppStateChanged);
    AnalyticsQueue.instance.start();

    // First frame: the cached Home at once, then /feed/home/ and categories.
    _loadHome(_generation);
    _loadCategories();
    unawaited(AnalyticsQueue.instance
        .track('feed_refresh', metadata: {'source': 'launch'}));

    // After the first frame, in parallel: the Latest list and the widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _isProgressivelyHydrated = true);
      _loadLatest(reset: true);
      _loadWidgets(_generation);
    });
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    _homeRetryTimer?.cancel();
    _breakingNewsController.dispose();
    super.dispose();
  }

  /// `/feed/home/`, stale-while-refresh: the cached copy for this reader and
  /// place is shown first; the network answer replaces it only on success.
  Future<void> _loadHome(int generation, {bool forceRefresh = false}) async {
    final app = AppState.instance;
    final repo = HomeFeedRepository.instance;
    final viewer = _viewer;

    if (!_homeLoaded) {
      final cached = await repo.cached(
        viewer: viewer,
        lang: _feedLang,
        state: app.stateName,
        district: app.district,
        subdistrict: app.subdistrict,
        village: app.village,
      );
      if (cached != null && mounted && generation == _generation) {
        setState(() {
          _forYou = cached.personalized;
          _nearYou = cached.local;
          _bootstrapLite = cached.lite;
          _homeLoaded = true;
        });
      }
    }

    final fresh = await repo.fetch(
      viewer: viewer,
      lang: _feedLang,
      state: app.stateName,
      district: app.district,
      subdistrict: app.subdistrict,
      village: app.village,
      forceRefresh: forceRefresh,
    );
    // A request for an old reader or place: ignore it.
    if (!mounted || generation != _generation) return;

    if (fresh == null) {
      // Keep whatever is on screen (the cached copy).
      setState(() {
        _homeLoaded = true;
        _homeFailed = true;
      });
      if (repo.lastFailureStatus == 429) {
        // Throttled: try once more a little later, still keeping the cache.
        _homeRetryTimer?.cancel();
        _homeRetryTimer = Timer(const Duration(seconds: 30), () {
          if (mounted && generation == _generation) {
            _loadHome(generation, forceRefresh: true);
          }
        });
      }
      return;
    }

    setState(() {
      _forYou = fresh.personalized;
      _nearYou = fresh.local;
      _bootstrapLite = fresh.lite;
      _homeLoaded = true;
      _homeFailed = false;
    });

    final bulk = fresh.analyticsBulkEndpoint;
    if (bulk != null && bulk.isNotEmpty) AnalyticsQueue.instance.endpoint = bulk;
    // The network just answered; a good moment to send what queued offline.
    unawaited(AnalyticsQueue.instance.flush());
  }

  /// `/feed/`: [reset] loads the first page (refresh, category, new place);
  /// otherwise the next page from `meta.next`, exactly as the server sent it.
  Future<void> _loadLatest({bool reset = false}) async {
    if (!reset && (_latestLoading || !_latestHasMore)) return;
    final generation = reset ? ++_latestGeneration : _latestGeneration;
    final next = reset ? null : _latestNext;
    final app = AppState.instance;
    if (mounted) setState(() => _latestLoading = true);

    try {
      final page = await HomeFeedRepository.instance.fetchLatest(
        next: next,
        lang: _feedLang,
        state: app.stateName,
        district: app.district,
        subdistrict: app.subdistrict,
        village: app.village,
        category: _selectedCategory,
      );
      if (!mounted || generation != _latestGeneration) return;
      setState(() {
        if (reset) {
          _latest = page.items;
        } else {
          final seen = _latest.map(_storyKey).toSet();
          _latest = [
            ..._latest,
            ...page.items.where((a) => seen.add(_storyKey(a))),
          ];
        }
        _latestNext = page.next;
        _latestHasMore = page.next != null;
        _latestLoaded = true;
        _latestFailed = false;
      });
      if (_latest.isNotEmpty) {
        NotificationService.instance.requestPermissionAfterArticlesLoaded();
      }
    } catch (e) {
      debugPrint('[NewsFeedTab] /feed/ failed: $e');
      // Keep the list already shown; a refresh or scroll retries.
      if (mounted && generation == _latestGeneration) {
        setState(() {
          _latestLoaded = true;
          _latestFailed = true;
        });
      }
    } finally {
      if (mounted && generation == _latestGeneration) {
        setState(() => _latestLoading = false);
      }
    }
  }

  /// The non-news widgets, in parallel. Each hides itself on failure.
  void _loadWidgets(int generation, {bool forceRefresh = false}) {
    _loadFeedAds(generation, forceRefresh: forceRefresh);
    _loadPoll(generation);
    _loadPosters(generation);
    _loadHomeVideos(generation);
    _loadDailyQuote(generation, forceRefresh: forceRefresh);
  }

  /// Opens a Home card. Articles open by slug (detail is
  /// /api/v1/articles/{slug}/ — never the id). Live streams have no article
  /// page, so they open Live.
  void _openStory(NewsArticle article) {
    AppNavigator.pushSafe(
      context,
      MaterialPageRoute(
        builder: (_) => article.contentKind == 'live'
            ? const LiveNewsScreen()
            : NewsDetailScreen(article: article, slug: article.slug),
      ),
    );
  }

  void _trackOpen(NewsArticle article, String section) {
    unawaited(AnalyticsQueue.instance.track('article_open', metadata: {
      'article_id': article.id,
      'content_kind': article.contentKind,
      'section': section,
    }));
  }

  bool _hasLocation(String? value) => value?.trim().isNotEmpty == true;

  bool _coverageIs(NewsArticle article, String level) {
    return article.coverageLevel.trim().toLowerCase() == level;
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService.instance.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadPoll(int generation) async {
    try {
      final polls = await ApiService.instance.getPolls();
      if (mounted && generation == _generation) {
        setState(() => _poll = polls.isNotEmpty ? polls.first : null);
      }
    } catch (_) {}
  }

  Future<void> _loadHomeVideos(int generation) async {
    try {
      final response = await VideoRepository.instance.getVideoFeed();
      if (!mounted || generation != _generation) return;
      // isShort is the single classification both surfaces use, so a
      // mis-tagged Short cannot leak into the carousel.
      final videos =
          (response.data ?? []).where((v) => !v.isShort).toList();
      setState(() => _homeVideos = videos);
    } catch (e) {
      debugPrint('[NewsFeedTab] home video load failed: $e');
    }
  }

  Future<void> _loadPosters(int generation) async {
    try {
      final posters = await ApiService.instance.getPosters();
      if (mounted && generation == _generation) {
        setState(() => _posters = posters);
      }
    } catch (_) {}
  }

  /// The one `/ads/` request of this Home load. Inline slots, the breaking
  /// strip and HomeScreen's bottom sticky banner all read this response.
  Future<void> _loadFeedAds(int generation, {bool forceRefresh = false}) async {
    try {
      final response = await AdRepository.instance.getAds(
        placementZone: 'feed',
        scope: 'main',
        forceRefresh: forceRefresh,
      );
      if (mounted && generation == _generation && response.data != null) {
        setState(() => _feedAds = response.data!);
        HomeAds.current.value = response.data!;
      }
    } catch (_) {}
  }

  Future<void> _loadDailyQuote(int generation,
      {bool forceRefresh = false}) async {
    try {
      final q =
          await ApiService.instance.getRandomQuote(forceRefresh: forceRefresh);
      if (mounted && generation == _generation && q != null) {
        setState(() => _dailyQuote = q);
      }
    } catch (_) {}
  }

  /// Pull-to-refresh. Nothing is cleared: the old content stays until each
  /// fresh response arrives and replaces it.
  Future<void> _refresh() async {
    final generation = _generation;
    unawaited(AnalyticsQueue.instance.track('feed_refresh', metadata: {
      'source': 'pull',
      'mode': HomeFeedRepository.instance.prefersLite ? 'lite' : 'full',
    }));
    AdDeliveryService.instance.resetSession();
    _homeRetryTimer?.cancel();
    _loadWidgets(generation, forceRefresh: true);
    await Future.wait([
      _loadHome(generation, forceRefresh: true),
      _loadLatest(reset: true),
    ]);
    if (mounted && generation == _generation && _homeFailed && _latestFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('రిఫ్రెష్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// A category narrows the Latest list only; Home's sections stay.
  void _selectCategory(String? slug) {
    setState(() => _selectedCategory = slug);
    unawaited(AnalyticsQueue.instance.track('category_select',
        metadata: {'category': slug ?? 'all'}));
    _loadLatest(reset: true);
  }

  /// The picture for a story card. Many feed stories carry it only in
  /// `media_items`, so the hero showed a grey card for them while the For
  /// You rail (which already looked there) showed the photo.
  static String _storyImage(NewsArticle a) {
    if (a.imageUrl.isNotEmpty) return a.imageUrl;
    for (final m in a.mediaItems) {
      if (m.thumbnailUrl.isNotEmpty) return m.thumbnailUrl;
      if (m.mediaType != 'video' && m.url.isNotEmpty) return m.url;
    }
    return '';
  }

  /// Behind a story that has no picture at all: deep brand red to near
  /// black, so white headline text reads and the card still looks designed.
  static const _noImageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9F1239), Color(0xFF3B0A16), Color(0xFF111111)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Card image area for a story with no picture: the brand gradient with
  /// the app logo, faint — reads as intentional, not as a failed load.
  Widget _noImageTile() {
    return DecoratedBox(
      key: const Key('no_image_tile'),
      decoration: const BoxDecoration(gradient: _noImageGradient),
      child: Center(
        child: Opacity(
          opacity: 0.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }

  /// Hero from the Home response only (see [homeHeroStories]).
  List<NewsArticle> _heroStories() => homeHeroStories(_forYou, _nearYou);

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
              _selectCategory(isAll ? null : cat?.slug);
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

  /// Horizontal carousel of regular videos. Thumbnails only — no controller
  /// is created and nothing plays until the reader taps through.
  ///
  /// 16:9 cards, not the 9:16 the Shorts carousel used: full videos are
  /// landscape and would letterbox badly in a portrait card.
  ///
  /// Hidden entirely when empty, rather than showing a section with nothing
  /// in it.
  Widget _buildHomeVideosStrip() {
    if (_homeVideos.isEmpty) return const SizedBox.shrink();

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
                    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Videos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          // 16:9 at 200 wide, plus room for the title beneath.
          height: 176,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _homeVideos.length,
            itemBuilder: (context, index) {
              final video = _homeVideos[index];
              final thumb = video.thumbnailUrl;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final url = video.youtubeUrl ?? video.videoUrl;
                  if (url == null || url.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                        videoUrl: url,
                        title: video.title,
                        thumbnailUrl: video.thumbnailUrl,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                            color: isDark
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFFF3F4F6),
                            image: thumb.isNotEmpty
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(thumb,
                                        maxWidth: 400),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
          // 8, not 16: the icon buttons carry their own 12px padding, so
          // their glyphs now line up with the 16–20px content edge below.
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12,
            left: 8,
            right: 8,
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
          // Profile left, logo centred, Search + Notifications right. The
          // logo sits in its own layer so it is centred on the screen, not
          // between the uneven left and right groups. Location moved to the
          // bottom bar's Local tab.
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Semantics(
                  image: true,
                  label: 'Vaaradhi',
                  // 36pt, the height of the avatar beside it, decoded at
                  // screen density so the mark stays sharp.
                  child: ClipRRect(
                    key: const Key('home_header_logo'),
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      cacheWidth: (36 *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildProfileButton(),
                    const Spacer(),
                    ..._buildHeaderActions(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top-left: Profile, in a 48dp target.
  /// - Logged in: the reader's avatar — their photo, else their initial on a
  ///   soft brand tint — a clean 32dp circle with a hairline edge, no glow.
  /// - Guest: the plain outline person icon, matching Search and the bell.
  Widget _buildProfileButton() {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final photo = state.profileImagePath;
        final hasPhoto =
            state.isLoggedIn && photo != null && photo.startsWith('http');
        final name = state.userName.trim();
        final initial = state.isLoggedIn &&
                name.isNotEmpty &&
                name != 'Guest User'
            ? String.fromCharCode(name.runes.first).toUpperCase()
            : '';

        final Widget face;
        if (hasPhoto) {
          face = CircleAvatar(
            key: const Key('home_header_avatar'),
            radius: 16,
            backgroundColor: AppColors.chipBg,
            backgroundImage: CachedNetworkImageProvider(photo, maxWidth: 128),
          );
        } else if (initial.isNotEmpty) {
          face = CircleAvatar(
            key: const Key('home_header_avatar'),
            radius: 16,
            backgroundColor:
                AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                height: 1,
              ),
            ),
          );
        } else {
          face = Icon(Icons.person_outline_rounded,
              color: Theme.of(context).iconTheme.color);
        }

        return IconButton(
          key: const Key('home_header_profile'),
          tooltip: tr('nav_profile'),
          onPressed: () {
            HapticFeedback.selectionClick();
            ProfileTab.open(context);
          },
          icon: hasPhoto || initial.isNotEmpty
              // Hairline ring so a photo's edge is crisp on any header.
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: face,
                )
              : face,
        );
      },
    );
  }

  /// Top-right: Search and Notifications.
  List<Widget> _buildHeaderActions() {
    return [
              IconButton(
                key: const Key('home_header_search'),
                tooltip: AppState.instance.language == 'Telugu'
                    ? 'వెతకండి'
                    : 'Search',
                icon: Icon(Icons.search_rounded,
                    color: Theme.of(context).iconTheme.color),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),

              // Notifications, badged with whatever is unread. Rebuilt from
              // AppState so the count follows a push arriving or the list
              // being read, without this bar polling anything.
              AnimatedBuilder(
                animation: AppState.instance,
                builder: (context, _) {
                  final unread = AppState.instance.unreadNotificationsCount;
                  return IconButton(
                    tooltip: AppState.instance.language == 'Telugu'
                        ? 'నోటిఫికేషన్లు'
                        : 'Notifications',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            color: Theme.of(context).iconTheme.color),
                        if (unread > 0)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              constraints: const BoxConstraints(minWidth: 15),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                // Past 99 the badge would widen enough to
                                // push the icons along.
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
    ];
  }



  /// The hero carousel, from [_heroStories]: live, breaking, featured.
  Widget _buildBreakingNewsSection(List<NewsArticle> heroItems) {
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
              final NewsArticle? article = heroItems[index];
              final isLive = article?.contentKind == 'live';
              // Only a story the server marked says so on its badge.
              final badge = isLive
                  ? null
                  : article!.isBreaking
                      ? 'BREAKING'
                      : article.isFeatured
                          ? 'FEATURED'
                          : null;

              final imageUrl = article == null ? '' : _storyImage(article);
              final title = article?.title ?? '';
              final subtitle = isLive
                  ? 'లైవ్ ప్రసారం'
                  : 'Updated ${article?.timeAgo ?? ''}';

              return GestureDetector(
                onTap: () {
                  if (article == null) return;
                  AdManager.instance.recordContentInteraction();
                  _trackOpen(article, 'hero');
                  _openStory(article);
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
                    // A story with no picture gets the brand's deep red
                    // instead of a flat grey card.
                    gradient: imageUrl.isEmpty ? _noImageGradient : null,
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
                                else if (badge != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: BackdropFilter(
                                      filter: dart_ui.ImageFilter.blur(
                                          sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        // Solid, so it reads on any photo
                                        // (the 30% orange washed out).
                                        color: AppColors.primary,
                                        child: Text(
                                          badge,
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
                                if (badge == null && !isLive) const SizedBox(),
                                if (!isLive &&
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

  /// Shown over saved content when `/feed/home/` could not be refreshed
  /// (offline, 5xx, or 429 — which also retries on its own shortly).
  Widget _buildOfflineNotice() {
    final telugu = AppState.instance.language == 'Telugu';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const Key('home_offline_notice'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 18,
              color: isDark ? Colors.white70 : const Color(0xFF8A5A00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              telugu
                  ? 'సేవ్ చేసిన వార్తలు చూపిస్తున్నాం'
                  : 'Showing saved stories',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF6B4600),
              ),
            ),
          ),
          TextButton(
            key: const Key('home_offline_retry'),
            onPressed: _refresh,
            child: Text(telugu ? 'మళ్ళీ ప్రయత్నించండి' : 'Retry'),
          ),
        ],
      ),
    );
  }

  /// Section title with the brand gradient mark. [caption] is a quiet
  /// right-aligned note (e.g. the lite-mode hint).
  Widget _buildSectionTitle(String title, {String? caption}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (caption != null)
            Text(
              caption,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  /// Header over the paginated latest feed.
  Widget _buildLatestHeader() => _buildSectionTitle(
        AppState.instance.language == 'Telugu' ? 'తాజా వార్తలు' : 'Latest',
      );

  /// Personalized rail from the home bootstrap: horizontal cards, image on
  /// top, two-line headline.
  Widget _buildForYouRail(List<NewsArticle> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final telugu = AppState.instance.language == 'Telugu';
    final cardColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            tr('for_you_section'),
            // Slow connection: the bootstrap came in lite mode.
            caption: _bootstrapLite
                ? (telugu ? 'తక్కువ డేటా మోడ్' : 'Data saver')
                : null,
          ),
          SizedBox(
            height: 232,
            child: ListView.separated(
              key: const PageStorageKey('home_for_you_rail'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length.clamp(0, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final article = items[index];
                final image = _storyImage(article);
                return SizedBox(
                  width: 220,
                  child: Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('for_you_${article.id}'),
                      onTap: () {
                        AdManager.instance.recordContentInteraction();
                        _trackOpen(article, 'for_you');
                        _openStory(article);
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: image.isEmpty
                                  ? _noImageTile()
                                  : CachedNetworkImage(
                                      imageUrl: image,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 480,
                                      placeholder: (_, __) =>
                                          Container(color: AppColors.chipBg),
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.chipBg,
                                        child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: AppColors.textMuted),
                                      ),
                                    ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 0),
                              child: Text(
                                article.category.isNotEmpty
                                    ? article.category.toUpperCase()
                                    : '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 4, 12, 0),
                              child: Text(
                                article.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: Text(
                                article.timeAgo,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
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
            _trackOpen(
                article,
                item.stableKey.startsWith('section-')
                    ? 'location_section'
                    : 'latest');
            _openStory(article);
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
    final heroItems = _heroStories();
    // Newest first, fresh-first, and nothing the hero already shows.
    final forYou = homeForYouStories(_forYou, heroItems);
    // Latest is /feed/ itself, so scrolling to the end really loads more.
    // Nothing already shown above — hero, For You, Near You — repeats here;
    // matched by kind:id, since article and citizen-post ids are separate.
    final shownAbove = {
      ...heroItems.map(_storyKey),
      ...forYou.map(_storyKey),
      ..._nearYou.map(_storyKey),
    };
    final recommended =
        _latest.where((a) => !shownAbove.contains(_storyKey(a))).toList();
    final hasHomeContent = heroItems.isNotEmpty ||
        forYou.isNotEmpty ||
        _nearYou.isNotEmpty ||
        _latest.isNotEmpty;
    // Still waiting for the first answer from either news endpoint.
    final stillLoading = !_homeLoaded || (!_latestLoaded && _latestLoading);
    final bothFailed = _homeFailed && _latestFailed;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          !hasHomeContent
              ? (stillLoading
                  ? const Center(child: CircularProgressIndicator())
                  : bothFailed
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
                                const Text(
                                  'దయచేసి నెట్‌వర్క్ తనిఖీ చేసి మళ్ళీ ప్రయత్నించండి.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  key: const Key('home_retry'),
                                  onPressed: _refresh,
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
                              const SizedBox(height: 12),
                              TextButton.icon(
                                key: const Key('home_empty_refresh'),
                                onPressed: _refresh,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('రిఫ్రెష్ చేయండి'),
                              ),
                            ],
                          ),
                        ))
              : RefreshIndicator(
                  key: const Key('home_refresh'),
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  // The header floats over the list, so the spinner starts
                  // below it (and below the breaking strip when shown);
                  // from the very top it appeared hidden behind the header.
                  edgeOffset: MediaQuery.of(context).padding.top +
                      (_breakingStripAds.isNotEmpty ? 118 : 68),
                  displacement: 32,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (scrollInfo.metrics.pixels >=
                              scrollInfo.metrics.maxScrollExtent - 200 &&
                          !_latestLoading &&
                          _latestHasMore) {
                        _loadLatest();
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
                        // Inline slots take what the strip and the bottom
                        // sticky banner do not — all from the one /ads/ call.
                        final inlineAds = HomeAds.inline(_feedAds);

                        final presentationItems = recommended.isNotEmpty
                            ? AdManager.instance
                                .buildFeedPresentation<NewsArticle>(
                                contentItems: recommended,
                                adsPool: inlineAds,
                                contentKey: (article) =>
                                    '${article.contentKind}:${article.id}',
                              )
                            : <FeedPresentationItem<NewsArticle>>[];

                        return CustomScrollView(
                          // A pull must always reach the refresh, even when
                          // Home is shorter than the screen.
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top +
                                    (_breakingStripAds.isNotEmpty ? 120 : 70), // Space for floating app bar & breaking strip
                              ),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    // Showing the saved copy because the
                                    // refresh failed (offline, 5xx, 429).
                                    if (_homeFailed) _buildOfflineNotice(),
                                    RepaintBoundary(
                                      child: _buildCategorySelector(),
                                    ),
                                    RepaintBoundary(
                                      child: _buildBreakingNewsSection(
                                          heroItems),
                                    ),
                                    // For You — personalized rail.
                                    if (forYou.isNotEmpty)
                                      RepaintBoundary(
                                        child: _buildForYouRail(forYou),
                                      ),
                                    // Near You — the bootstrap's local
                                    // section; hidden when it is empty.
                                    _buildLocationSection(
                                      title: AppState.instance.language ==
                                              'Telugu'
                                          ? 'మీ సమీపంలో'
                                          : 'Near You',
                                      location:
                                          AppState.instance.displayLocation,
                                      icon: Icons.near_me_outlined,
                                      accent: AppColors.primary,
                                      articles: _nearYou,
                                      cardColor: cardColor,
                                      borderColor: borderColor,
                                    ),
                                    // Village, Mandal, District, State and
                                    // National are not separate sections:
                                    // /feed/home/ returns only For You and
                                    // Near You. Those stories reach the
                                    // reader through Latest (/feed/).
                                    if (_isProgressivelyHydrated) ...[
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
                                      if (_homeVideos.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        _buildHomeVideosStrip(),
                                      ],
                                    ],
                                    const SizedBox(height: 16),
                                    if (recommended.isNotEmpty)
                                      _buildLatestHeader(),
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
                                      (_latestHasMore ? 1 : 0),
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
                                            'home_${_identity}_${_latestGeneration}_${item.stableKey}',
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
