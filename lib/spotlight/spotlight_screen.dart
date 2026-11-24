import '../services/content_analytics.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/feed/ugc_feed_freshness.dart';
import '../core/navigation/app_navigator.dart';
import '../models/spotlight_item.dart';
import '../models/news_article.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/ads/ad_video_preloader.dart';
import '../widgets/ads/sponsored_spotlight_ad_card.dart';
import '../services/ad_delivery_service.dart';
import '../core/widgets/flip_page_view.dart';
import '../widgets/spotlight/spotlight_news_card.dart';
import '../widgets/spotlight/spotlight_shimmer_card.dart';
import '../widgets/spotlight/news_language_sheet.dart';
import '../services/location_permission_coordinator.dart';
import '../widgets/poster_card.dart';
import '../widgets/info_card.dart';
import '../widgets/smart_fit_image.dart';
import '../widgets/poll_card.dart';
import '../core/widgets/fit_or_scroll.dart';
import '../widgets/spotlight/spotlight_trending_strip.dart';
import '../screens/news_detail_screen.dart';
import '../screens/feedback_screen.dart';
import '../services/feedback_service.dart';
import '../repositories/news_article_repository.dart';
import '../repositories/top_stories_repository.dart';
import '../utils/share_service.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../localization/app_translations.dart';
import '../screens/home_screen.dart';
import '../screens/location_selection_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/profile_tab.dart';
import '../services/tts_service.dart';

import 'spotlight_controller.dart';
import 'spotlight_state.dart';
import 'top_stories_controller.dart';
import 'spotlight_media_coordinator.dart';
import '../widgets/ads/paced_ads_overlay.dart';

class SpotlightScreenView extends StatefulWidget {
  final String? initialStoryId;
  final int? initialStoryIndex;
  final String? initialCategory;
  final bool isLocal;

  /// A story opened from a notification: shown as the first card at once,
  /// and kept there when the feed arrives.
  final NewsArticle? pinnedArticle;

  /// True when this is Home's persistent tab content rather than a pushed
  /// route. Suppresses the internal back-button handling and redirects the
  /// header's Profile/Post buttons through [onOpenProfile]/[onOpenPost]
  /// instead of pushing duplicate screens — HomeScreen owns both concerns
  /// when embedded.
  final bool embedded;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenPost;

  const SpotlightScreenView({
    super.key,
    this.initialStoryId,
    this.initialStoryIndex,
    this.initialCategory,
    this.isLocal = false,
    this.pinnedArticle,
    this.embedded = false,
    this.onOpenProfile,
    this.onOpenPost,
  });

  @override
  State<SpotlightScreenView> createState() => _SpotlightScreenViewState();
}

class _SpotlightScreenViewState extends State<SpotlightScreenView>
    with WidgetsBindingObserver {
  /// This Spotlight session's impressions: each story once (analytics).
  final ImpressionLog _impressions = ImpressionLog();

  late final SpotlightController _controller;
  // A real PageController: the feed rides Flutter's own scroll physics
  // (momentum, fling, settle) instead of the hand-rolled vertical drag
  // handlers it used before, which had none of them — that is what made the
  // swipe feel like it caught.
  late final PageController _pageController =
      PageController(onAttach: (_) => _restoreSpotlightPage());
  ({int page, int generation})? _spotlightPosition;
  int _lastPageIndex = 0;
  final _topStories = TopStoriesController();
  final _topPageController = PageController(keepPage: false);
  final _topPage = ValueNotifier<int>(0);
  final _qualifiedTopStories = <(String, String)>{};
  bool _showTopStories = false;

  List<SpotlightItem> get _visibleFeed =>
      _showTopStories ? _topStories.stories : _controller.state.feed;
  ValueNotifier<int> get _visiblePage =>
      _showTopStories ? _topPage : _currentPage;

  void _syncTopStoriesFilters() {
    if (!_showTopStories) return;
    final query = TopStoriesQuery.fromApp(AppState.instance);
    if (query.cacheKey == _topStories.filterKey) return;
    _topPage.value = 0;
    SpotlightMediaCoordinator.instance.stopAll();
    unawaited(_topStories.show(query));
  }

  void _topStoriesChanged() {
    final stories = _topStories.stories;
    if (stories.isEmpty) {
      if (!_topStories.loading) _topPage.value = 0;
      return;
    }
    if (_topPage.value < stories.length) return;
    final index = stories.length - 1;
    _topPage.value = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showTopStories && _topPageController.hasClients) {
        _topPageController.jumpToPage(_topPage.value);
      }
    });
  }

  void _selectTopStories(bool selected) {
    if (selected == _showTopStories) return;
    _locationPromptTimer?.cancel();
    SpotlightMediaCoordinator.instance.stopAll();
    _controller.resetOverlayTimer();
    setState(() => _showTopStories = selected);
    if (selected) {
      _spotlightPosition = (
        page: _pageController.hasClients
            ? _pageController.page?.round() ?? _currentPage.value
            : _currentPage.value,
        generation: _controller.state.generation,
      );
      _syncTopStoriesFilters();
    } else {
      _lastPageIndex = _spotlightPageToRestore;
      _currentPage.value = _lastPageIndex;
      _topStories.close();
      _jumpToInitialStoryOnce();
    }
  }

  int get _spotlightPageToRestore {
    final saved = _spotlightPosition;
    final state = _controller.state;
    if (saved == null ||
        saved.generation != state.generation ||
        state.feed.isEmpty) {
      return 0;
    }
    return saved.page.clamp(0, state.feed.length - 1).toInt();
  }

  void _restoreSpotlightPage() {
    if (_spotlightPosition == null) return;
    final page = _spotlightPageToRestore;
    _spotlightPosition = null;
    _pageController.jumpToPage(page);
  }

  Future<void> _refreshVisibleFeed() =>
      _showTopStories ? _topStories.refresh() : _controller.refreshFeed();

  String get _topStoriesLabel =>
      AppState.instance.language == 'Telugu' ? 'టాప్ స్టోరీస్' : 'Top Stories';

  /// Which page is settled. A notifier rather than setState: only the two
  /// cards whose isCurrent actually flips need to rebuild, not the feed.
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  Timer? _dwellTimer;
  Timer? _locationPromptTimer;
  bool _hasPromptedLocationThisSession = false;
  bool _isLanguageSheetShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = SpotlightController(
      initialCategory: widget.initialCategory,
      isLocal: widget.isLocal,
      initialStoryId: widget.initialStoryId,
      pinnedArticle: widget.pinnedArticle,
    );
    // Ask which news language before anything location-related: it decides
    // what the very first feed request asks for.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isLanguageSheetShowing = true;
      await NewsLanguageSheet.showIfNeeded(context);
      _isLanguageSheetShowing = false;
    });
    // No location prompt on entry — Home/Spotlight load with whatever
    // location is already known. The soft prompt only appears once the
    // reader has actually engaged (see _handlePageChanged).
    // A deep link can ask for a specific story. The feed is empty at this
    // point, so jump once as soon as it arrives.
    _controller.addListener(_jumpToInitialStoryOnce);
    // New feed pages: get the photos around the reader ready.
    _controller.addListener(_precacheAroundCurrent);
    UgcFeedFreshness.published.addListener(_refreshIfAtTop);
    AppState.instance.addListener(_syncTopStoriesFilters);
    _topStories.addListener(_topStoriesChanged);
  }

  void _precacheAroundCurrent() => _precacheUpcoming(_currentPage.value);

  bool _jumpedToInitialStory = false;

  void _jumpToInitialStoryOnce() {
    if (_jumpedToInitialStory || _showTopStories) return;
    final feed = _controller.state.feed;
    if (feed.isEmpty) return;

    _jumpedToInitialStory = true;
    _controller.removeListener(_jumpToInitialStoryOnce);

    final target = widget.initialStoryIndex ??
        _controller.findInitialIndex(widget.initialStoryId);
    if (target <= 0 || target >= feed.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(target);
      _lastPageIndex = target;
      _currentPage.value = target;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      SpotlightMediaCoordinator.instance.stopAll();
    }
    if (state == AppLifecycleState.resumed &&
        UgcFeedFreshness.isStale(_feedLoadedAt)) {
      _refreshIfAtTop();
    }
  }

  /// When the feed last asked for page one on its own.
  DateTime? _feedLoadedAt = DateTime.now();

  /// New citizen posts come only from a new page one. Only on the first
  /// card: a reader further down must not have the story moved under them.
  void _refreshIfAtTop() {
    if (_currentPage.value != 0) return;
    _feedLoadedAt = DateTime.now();
    unawaited(_controller.loadFeed(refresh: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    UgcFeedFreshness.published.removeListener(_refreshIfAtTop);
    AppState.instance.removeListener(_syncTopStoriesFilters);
    _topStories.removeListener(_topStoriesChanged);
    _topStories.dispose();
    _topPage.dispose();
    _topPageController.dispose();
    SpotlightMediaCoordinator.instance.stopAll();
    AdVideoPreloader.instance.clear();
    AppTtsService.instance.stop();
    _dwellTimer?.cancel();
    _locationPromptTimer?.cancel();
    _controller.removeListener(_jumpToInitialStoryOnce);
    _controller.removeListener(_precacheAroundCurrent);
    _currentPage.dispose();
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Moves to the next page, used by cards that dismiss themselves.
  void _advancePage() {
    if (!_pageController.hasClients) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Soft-prompts for location once the reader has actually engaged with
  /// Spotlight — never on entry. Gated on the shared cooldown policy so this
  /// can't stack with a prompt already shown elsewhere in the app, and on
  /// there being no TTS/video playing or other sheet open so it never
  /// interrupts something the reader is mid-way through.
  Future<void> _maybeShowGentleLocationPrompt() async {
    if (_hasPromptedLocationThisSession) return;
    if (AppState.instance.hasValidLocation) return;
    if (SpotlightMediaCoordinator.instance.hasActiveMedia) return;
    if (_isLanguageSheetShowing) return;
    if (!await LocationPermissionCoordinator.shouldShowAutomaticPrompt()) {
      return;
    }
    if (!mounted || _showTopStories) return;

    _hasPromptedLocationThisSession = true;
    final changed = await LocationPermissionCoordinator.requestCurrentLocation(
      context,
      reason: LocationPromptReason.spotlight,
    );
    if (changed && mounted) {
      _controller.updateLocation();
    }
  }

  Future<void> _openLocationSelector() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationSelectionScreen()),
    );
    if (mounted) {
      _controller.updateLocation();
    }
  }

  void _handlePageChanged(int index) {
    final bool isSwipingBack = index < _lastPageIndex;
    _lastPageIndex = index;
    _currentPage.value = index;
    _controller.recordPageConsumed(index);

    // Mutually exclusive playback: stop active TTS/video on swipe. This used
    // to hang off the pager's onSwipeStart, which the PageView has no
    // equivalent for — landing on a new page is the reliable signal.
    SpotlightMediaCoordinator.instance.stopAll();
    AppTtsService.instance.stop();

    // Auto-hide overlays on swipe for clean, immersive reading — but only on
    // story cards. A poll, poster or sponsored card keeps its chrome: those
    // carry the controls the reader needs (vote, save, close), and stripping
    // them left no way to act on the card or leave it.
    // A null type means the index is past the end of the feed — which happens
    // when a dismissed ad was the last item. Default to keeping the chrome
    // there: a blank page with no chrome is the one state with no way out.
    final landedOn = index >= 0 && index < _controller.state.feed.length
        ? _controller.state.feed[index].type
        : null;
    if (landedOn?.isImmersiveStory ?? false) {
      if (_controller.state.showOverlays) {
        _controller.hideOverlay();
      }
    } else if (!_controller.state.showOverlays) {
      _controller.showOverlayPersistently();
    }

    // Track dwell and page selection in AdDeliveryService
    AdDeliveryService.instance.onPageSelected(index);

    // Debounced early prefetch to avoid network burst spikes on rapid swipes
    _controller.prefetchNextPageIfNeeded(index);
    _precacheUpcoming(index);

    _dwellTimer?.cancel();

    // Dwell logic: only consider meaningful read if user forward-swipes and stays >= 2 seconds
    if (!isSwipingBack && index < _controller.state.feed.length) {
      // After the reader has actively read past the first few stories,
      // gently offer to personalize with their location.
      if (index >= 2 &&
          !AppState.instance.hasValidLocation &&
          !_hasPromptedLocationThisSession) {
        _locationPromptTimer?.cancel();
        _locationPromptTimer = Timer(const Duration(milliseconds: 1800), () {
          _maybeShowGentleLocationPrompt();
        });
      }
    }
  }

  /// Photos already requested ahead of time (each is fetched once).
  final Set<String> _precachedUrls = {};

  /// Starts downloading the photos of the next few story cards while the
  /// reader is on [index], so a swipe lands on a ready image rather than an
  /// empty frame that fills in later. Uses the card's own cache key
  /// ([SmartFitImage.precache]); video cards load their own player.
  void _precacheUpcoming(int index) {
    if (!mounted) return;
    final feed = _controller.state.feed;
    for (var i = index; i <= index + 3 && i < feed.length; i++) {
      if (i < 0) continue;
      // An ad ahead: its poster and, for a video, its player, so it opens
      // on a picture rather than a black page with a spinner.
      final ad = feed[i].adBanner;
      if (ad != null) {
        if (ad.imageUrl.isNotEmpty && _precachedUrls.add(ad.imageUrl)) {
          unawaited(precacheImage(
              CachedNetworkImageProvider(ad.imageUrl), context,
              onError: (_, __) {}));
        }
        // Not the current page: its card opens its own player.
        if (i > index && i <= index + 2) {
          AdVideoPreloader.instance.preload(ad.videoUrl);
        }
        continue;
      }
      final article = feed[i].article;
      if (article == null) continue;
      // The full story too (the feed has only a summary), so the card is
      // built with its final text and never swaps it in while on screen.
      if (i <= index + 2 && !article.isUgc && article.slug.isNotEmpty) {
        NewsArticleRepository.instance.prefetchDetail(article.slug);
      }
      final String url;
      final media = article.orderedMedia;
      if (media.length > 1) {
        if (media.first.isVideo) continue;
        url = media.first.url;
      } else if (article.isVideo) {
        continue;
      } else {
        url = (article.mediaItems.isNotEmpty &&
                article.mediaItems.first.url.isNotEmpty)
            ? article.mediaItems.first.url
            : article.imageUrl;
      }
      if (url.isEmpty || !_precachedUrls.add(url)) continue;
      unawaited(SmartFitImage.precache(context, url));
    }
    // The share cards of the next two stories (any kind: photo, video,
    // citizen post), so Share opens at once with the card there too.
    for (var i = index + 1; i <= index + 2 && i < feed.length; i++) {
      final article = feed[i].article;
      if (article != null) unawaited(ShareService.prepareShare(article));
    }
  }

  void _closeSpotlight() {
    if (_showTopStories) {
      _selectTopStories(false);
      return;
    }
    SpotlightMediaCoordinator.instance.stopAll();
    AdVideoPreloader.instance.clear();
    AppTtsService.instance.stop();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  /// Share always sends the branded card. It is made ahead, so the sheet
  /// usually opens at once; a short "preparing" note appears only when it
  /// takes longer than [ShareService.slowAfter].
  Future<void> _shareArticle(NewsArticle article) async {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.maybeOf(context);
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? note;
    void hide() => note?.close();
    try {
      await ShareService.shareNow(
        article,
        onSlow: () {
          note = messenger?.showSnackBar(
            const SnackBar(
              key: Key('share_preparing'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 20),
              content: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 14),
                  Expanded(child: Text('షేర్ కోసం సిద్ధం చేస్తోంది…')),
                ],
              ),
            ),
          );
        },
        onReady: hide,
      );
    } finally {
      hide();
    }
  }

  void _openArticle(NewsArticle article) {
    _controller.resetOverlayTimer();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(
          article: article,
          slug: article.slug,
        ),
      ),
    );
  }

  FeedbackContentReference? _feedbackReference(SpotlightItem item) {
    FeedbackContentType? type;
    String? id;
    if (item.article != null) {
      final article = item.article!;
      id = article.id;
      if (article.contentKind == 'ugc') {
        type = FeedbackContentType.ugc;
      } else if (article.contentKind == 'quote') {
        type = FeedbackContentType.quote;
      } else if (article.isVideo) {
        type = FeedbackContentType.video;
      } else {
        type = FeedbackContentType.article;
      }
    } else {
      switch (item.type) {
        case SpotlightType.ad:
          type = FeedbackContentType.ad;
          id = item.adBanner?.id;
        case SpotlightType.poster:
          type = FeedbackContentType.poster;
          id = item.id;
        case SpotlightType.poll:
          type = FeedbackContentType.poll;
          id = item.poll?.id;
        case SpotlightType.standard:
        case SpotlightType.ugc:
        case SpotlightType.carousel:
        case SpotlightType.infoCard:
        case SpotlightType.shimmer:
          break;
      }
    }
    if (type == null || id == null) return null;
    final reference = FeedbackContentReference(type: type, id: id);
    return reference.isValid ? reference : null;
  }

  void _reportCurrentContent() {
    final feed = _visibleFeed;
    final index = _visiblePage.value;
    if (index < 0 || index >= feed.length) return;
    final content = _feedbackReference(feed[index]);
    if (content == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          content: content,
          initialType: FeedbackType.contentReport,
        ),
      ),
    );
  }

  /// Stories to offer alongside a utility card.
  ///
  /// Sourced from the feed already in memory rather than a new request: the
  /// point is to use space the poll or ad leaves empty, which is not worth a
  /// round trip. Skips the card itself and anything without a headline.
  List<NewsArticle> _trendingNear(int index) {
    final feed = _controller.state.feed;
    final picks = <NewsArticle>[];
    final seen = <String>{};
    for (var offset = 1; offset < feed.length && picks.length < 8; offset++) {
      for (final probe in [index + offset, index - offset]) {
        if (probe < 0 || probe >= feed.length || probe == index) continue;
        final article = feed[probe].article;
        if (article == null || article.title.trim().isEmpty) continue;
        if (!seen.add(article.id.isEmpty ? article.slug : article.id)) continue;
        picks.add(article);
        if (picks.length >= 8) break;
      }
    }
    return picks;
  }

  /// Lays a utility card over the space it actually needs and gives the
  /// remainder to the trending strip.
  Widget _withTrending(int index, Widget card) {
    final trending = _trendingNear(index);
    if (trending.isEmpty) return card;
    return Column(
      children: [
        Expanded(child: card),
        SpotlightTrendingStrip(
          articles: trending,
          onOpen: _openArticle,
        ),
        SizedBox(
            height:
                MediaQuery.paddingOf(context).bottom + _bottomBarHeight + 8),
      ],
    );
  }

  /// Keeps a utility card clear of the chrome that now stays on screen for
  /// it — the top bar, the local-location strip, and the bottom capsule.
  EdgeInsets _utilityCardInsets(BuildContext context,
      {bool reserveBottomChrome = true}) {
    final padding = MediaQuery.paddingOf(context);
    final state = _controller.state;
    return EdgeInsets.fromLTRB(
      16,
      padding.top +
          (state.isLocalNews ? _topBarHeight + 46 : _topBarHeight + 8),
      16,
      // When a trending strip sits below, it already owns the bottom of the
      // page. Reserving the chrome height here too double-counted it and
      // squeezed the card enough to give its FitOrScroll real scroll extent
      // — and a vertical scrollable inside a vertical pager wins the drag,
      // which is exactly how a page ends up refusing to advance.
      reserveBottomChrome ? padding.bottom + _bottomBarHeight + 12 : 8,
    );
  }

  /// Builds one page.
  ///
  /// The transition is FlipPageView's job now, so cards are built settled:
  /// no drag offset, no partial opacity, no scale. A card at rest renders
  /// pixel-exact instead of sitting on a transformed layer, which is both
  /// sharper and cheaper than re-laying it out on every frame of a swipe.
  Widget _buildItem(BuildContext context, int index) {
    return ValueListenableBuilder<int>(
      valueListenable: _currentPage,
      builder: (context, currentPage, _) =>
          _buildItemFor(context, index, index == currentPage),
    );
  }

  void _removeUnavailablePoll(String id) {
    final previous = _currentPage.value;
    final removed = _controller.removeUnavailablePoll(id);
    if (removed == null) return;
    final last = _controller.state.feed.length - 1;
    final next = last < 0
        ? 0
        : (removed < previous ? previous - 1 : previous).clamp(0, last).toInt();
    _lastPageIndex = next;
    _currentPage.value = next;
    final saved = _spotlightPosition;
    if (saved != null && removed < saved.page) {
      _spotlightPosition = (page: saved.page - 1, generation: saved.generation);
    }
    if (next != previous) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showTopStories && _pageController.hasClients) {
          _pageController.jumpToPage(next);
        }
      });
    }
  }

  Widget _buildItemFor(BuildContext context, int index, bool isCurrent) {
    const dragDelta = 0.0;
    const dragProgress = 0.0;
    const matchCutProgress = 0.0;

    final feed = _visibleFeed;
    if (index >= feed.length) return const SizedBox();

    final item = feed[index];

    Widget child;

    switch (item.type) {
      case SpotlightType.standard:
      case SpotlightType.ugc:
        if (item.article == null) return const SizedBox();
        child = SpotlightNewsCard(
          key: _showTopStories ? ValueKey((item.type, item.id)) : null,
          article: item.article!,
          pageIndex: index,
          pageCount: feed.length,
          isCurrent: isCurrent &&
              (!_showTopStories || (ModalRoute.isCurrentOf(context) ?? true)),
          topStoriesScope: _showTopStories ? _topStories.filterKey : null,
          isEditorialHighlight: item.isEditorialHighlight,
          claimQualifiedOpen: _showTopStories
              ? () =>
                  _qualifiedTopStories.add((item.article!.contentKind, item.id))
              : null,
          dragDelta: dragDelta,
          dragProgress: dragProgress,
          matchCutProgress: matchCutProgress,
          onTap: _controller.toggleOverlay,
          onShare: () => _shareArticle(item.article!),
          onShareResolved: _showTopStories ? _shareArticle : null,
          onClose: _closeSpotlight,
        );
        break;

      case SpotlightType.carousel:
        if (item.article == null) return const SizedBox();
        child = SpotlightNewsCard(
            article: item.article!,
            pageIndex: index,
            pageCount: feed.length,
            isCurrent: isCurrent,
            dragDelta: dragDelta,
            dragProgress: dragProgress,
            matchCutProgress: matchCutProgress,
            onTap: _controller.toggleOverlay,
            onShare: () => _shareArticle(item.article!),
            onClose: _closeSpotlight);
        break;

      case SpotlightType.ad:
        if (item.adBanner == null) return const SizedBox();
        child = SponsoredSpotlightAdCard(
            key: ValueKey(item.id),
            ad: item.adBanner!,
            active: isCurrent,
            exposureKey: 'spotlight_${_controller.state.generation}_${item.id}',
            onClose: () => _controller.removeAdAt(index),
            // No duration from the backend: images close after 5 s; a video
            // is not cut off mid-play (plain Skip, no timer).
            durationSeconds: item.adBanner!.displayDurationSeconds > 0
                ? item.adBanner!.displayDurationSeconds
                : (item.adBanner!.videoUrl.trim().isNotEmpty ? 0 : 5),
            placementZone: 'feed');
        // Full page: the ad is immersive (chrome hidden), so it gets the whole
        // screen. Wrapping it with the trending strip squeezed the creative
        // into what was left above the strip and a 76pt spacer.
        break;

      case SpotlightType.poster:
        child = PosterCard(
          key: ValueKey('poster_${item.id}'),
          posterId: item.id,
          destinationUrl: item.destinationUrl,
          mediaUrl: item.mediaUrl ?? '',
          imageUrls: item.imageUrls ?? [],
          durationSeconds: 0,
          pageIndex: item.posterPageIndex,
          pageCount: item.posterPageCount,
          title: item.title ?? '',
          onClose: _advancePage,
        );
        break;

      case SpotlightType.infoCard:
        child = FitOrScroll(
          padding: _utilityCardInsets(context),
          child: InfoCard(
            key: ValueKey('info_${item.id}'),
            title: item.title ?? 'Did you know?',
          ),
        );
        break;

      case SpotlightType.poll:
        if (item.poll == null) return const SizedBox();
        // FitOrScroll, not Center: a poll builds one row per option, so a
        // long one overflowed the card and put the last options — and the
        // vote button — out of reach. It also keeps the scroll extent at
        // exactly zero when the poll does fit, so the swipe still belongs to
        // the pager rather than being swallowed by an inner scroll view.
        child = Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: _withTrending(
            index,
            FitOrScroll(
              padding: _utilityCardInsets(context, reserveBottomChrome: false),
              child: PollCard(
                key: ValueKey('poll_${item.id}'),
                poll: item.poll!,
                onUnavailable: _removeUnavailablePoll,
              ),
            ),
          ),
        );
        break;

      case SpotlightType.shimmer:
        child = const SpotlightShimmerCard();
        break;
    }

    return RepaintBoundary(
      key: ValueKey('spotlight-card-${item.id}-$index'),
      // Tap-to-toggle lives on the wrapper so it covers every card kind, not
      // just the story cards that happen to accept an onTap. Without it a
      // reader who swiped onto a poster, poll or ad had no way to bring the
      // chrome back, and no way out of the card. Children win the gesture
      // arena, so vote buttons and ad click-through still take their taps.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _controller.toggleOverlay,
        child: Transform.translate(
          offset: const Offset(0, dragDelta),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLocationFallback() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded,
                    size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                tr('location_fallback_title'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                tr('location_fallback_desc'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.location_on_rounded),
                  label: Text(tr('set_location_btn'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _openLocationSelector,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFeedState(bool isLocal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLocal
                      ? Icons.location_city_rounded
                      : Icons.newspaper_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _controller.state.errorMessage != null
                    ? tr('retry')
                    : isLocal
                        ? tr('no_local_stories')
                        : tr('no_stories_available'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _controller.state.errorMessage ??
                    (isLocal
                        ? (AppState.instance.hasValidLocation
                            ? '${AppState.instance.displayLocation} కోసం ప్రస్తుతం స్థానిక వార్తలు అందుబాటులో లేవు. వేరే జిల్లా లేదా మండలాన్ని ఎంచుకోండి.'
                            : 'స్థానిక వార్తల కోసం మీ జిల్లా లేదా మండలాన్ని ఎంచుకోండి.')
                        : 'తాజా బ్రేకింగ్ న్యూస్ మరియు అప్‌డేట్‌ల కోసం మళ్లీ చూడండి.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              if (isLocal) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(tr('change_location_btn'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _openLocationSelector,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('refresh'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _controller.refreshFeed();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeps the chrome alive while the reader is reaching for it.
  ///
  /// Resetting on pointer-down, not on a completed tap: every
  /// resetOverlayTimer() call below sits inside an onPressed, which cannot
  /// run when the tap is the thing being lost. IgnorePointer engages the
  /// instant showOverlays flips, while the button is still visibly fading, so
  /// a tap aimed at a control the reader can still see did nothing. This
  /// keeps the controls live for as long as they are actually being used.
  Widget _keepChromeAlive(Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _controller.resetOverlayTimer(),
      child: child,
    );
  }

  /// Height of the top bar below the status bar: one 48pt row (Android's
  /// minimum touch target) plus 4pt
  /// above and below. Kept slim so it covers as little of the photo as it
  /// can while every control stays easy to hit.
  static const double _topBarHeight = 56;

  /// Height of the bottom bar above the system gesture area.
  static const double _bottomBarHeight = 52;

  Widget _buildTopOverlay(SpotlightState state) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          // Lighter than before (0.50) so the photo reads through; the blur
          // keeps the white controls legible on any image.
          color: Colors.black.withValues(alpha: 0.32),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 4,
            bottom: 4,
            left: 8,
            right: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Profile Icon on Left -> Opens Profile screen
              IconButton(
                key: const Key('spotlight_profile_btn'),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _controller.resetOverlayTimer();
                  if (widget.embedded && widget.onOpenProfile != null) {
                    widget.onOpenProfile!();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          elevation: 0,
                          leading: const BackButton(),
                        ),
                        body: const ProfileTab(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline_rounded,
                    color: Colors.white, size: 24),
                tooltip: 'ప్రొఫైల్',
              ),

              // 2. Animated Sliding Toggle Pill: [ ప్రధాన వార్తలు | స్థానికం ]
              Container(
                key: const Key('spotlight_mode_toggle'),
                width: (MediaQuery.sizeOf(context).width - 114)
                    .clamp(140.0, 270.0)
                    .toDouble(),
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: _showTopStories
                          ? Alignment.centerRight
                          : state.isLocalNews
                              ? Alignment.center
                              : Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 1 / 3,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _controller.resetOverlayTimer();
                              _selectTopStories(false);
                              _controller.toggleMode(false);
                            },
                            child: Center(
                              child: Text(
                                tr('tab_main'), // 'ప్రధాన వార్తలు' in Telugu
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: !_showTopStories && !state.isLocalNews
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _controller.resetOverlayTimer();
                              _selectTopStories(false);
                              _controller.toggleMode(true);
                              if (!AppState.instance.hasValidLocation) {
                                // Tapping Local is explicit intent — ask
                                // right away, ignoring the automatic-prompt
                                // cooldown, and skip the later dwell prompt.
                                _hasPromptedLocationThisSession = true;
                                _locationPromptTimer?.cancel();
                                LocationPermissionCoordinator
                                    .requestCurrentLocation(
                                  context,
                                  reason: LocationPromptReason.localNews,
                                ).then((changed) {
                                  if (changed && mounted) {
                                    _controller.updateLocation();
                                  }
                                });
                              }
                            },
                            child: Center(
                              child: Text(
                                tr('tab_local'), // 'స్థానికం' in Telugu
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: !_showTopStories && state.isLocalNews
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            selected: _showTopStories,
                            child: TextButton(
                              key: const Key('spotlight_top_stories'),
                              style: TextButton.styleFrom(
                                foregroundColor: _showTopStories
                                    ? Colors.black
                                    : Colors.white70,
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _selectTopStories(true),
                              child: Text(
                                _topStoriesLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Create Post Action Button (+) in Red Circle — a 36pt disc
              // inside a 48pt touch target.
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    key: const Key('spotlight_post_btn'),
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x40FF3B30),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      // The whole 48pt square is the target, not just the disc.
                      constraints:
                          const BoxConstraints.tightFor(width: 48, height: 48),
                      tooltip: 'వార్తను పోస్ట్ చేయండి',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _controller.resetOverlayTimer();
                        if (widget.embedded && widget.onOpenPost != null) {
                          widget.onOpenPost!();
                          return;
                        }
                        // Opens for guests too: the Post screen shows its own
                        // "log in to post news" page. pushSafe drops a double tap.
                        AppNavigator.pushSafe(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CreatePostScreen()),
                        );
                      },
                      icon: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStrip() {
    final locationName = AppState.instance.displayLocation;

    return GestureDetector(
      onTap: () {
        _controller.resetOverlayTimer();
        _openLocationSelector();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  locationName.isNotEmpty
                      ? locationName
                      : tr('change_location'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay() {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          key: const Key('spotlight_bottom_bar'),
          // One 48pt row with 2pt above and below, then the system gesture
          // area (or 4pt on phones without one).
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: 2,
            bottom: (bottomPadding > 0 ? bottomPadding : 4) + 2,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.embedded
                ? MainAxisAlignment.end
                : MainAxisAlignment.spaceBetween,
            children: [
              // Embedded as Home's own tab content, there is nowhere for
              // this to "close" to — back navigation belongs to HomeScreen.
              if (!widget.embedded)
                IconButton(
                  key: const Key('spotlight_home_btn'),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 48, height: 48),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _closeSpotlight();
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  tooltip: 'వెనుకకు',
                ),
              IconButton(
                key: const Key('spotlight_refresh_btn'),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _controller.resetOverlayTimer();
                  _refreshVisibleFeed();
                },
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
                tooltip: 'తాజాకరించండి',
              ),
              ValueListenableBuilder<int>(
                valueListenable: _visiblePage,
                builder: (context, index, _) {
                  final feed = _visibleFeed;
                  if (index < 0 ||
                      index >= feed.length ||
                      _feedbackReference(feed[index]) == null) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    key: const Key('spotlight_report_content'),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 48, height: 48),
                    onPressed: _reportCurrentContent,
                    icon: const Icon(Icons.flag_outlined,
                        color: Colors.white, size: 22),
                    tooltip: AppState.instance.language == 'Telugu'
                        ? 'కంటెంట్‌ను నివేదించండి'
                        : 'Report this content',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopStoriesFeed() {
    final stories = _topStories.stories;
    final failure = _topStories.failure;
    final te = AppState.instance.language == 'Telugu';
    final message = switch (failure?.status) {
      400 => failure!.details.isEmpty
          ? (te
              ? 'భాష లేదా ప్రాంతం ఎంపికను మార్చండి.'
              : 'Change your language or location selection.')
          : failure.details.join('\n'),
      429 =>
        te ? 'కాసేపటి తర్వాత మళ్లీ ప్రయత్నించండి.' : 'Try again in a moment.',
      _ when failure?.offline == true =>
        te ? 'ఇంటర్నెట్ కనెక్షన్ లేదు.' : 'You’re offline.',
      _ when failure != null =>
        te ? 'వార్తలను లోడ్ చేయలేకపోయాము.' : 'Couldn’t load Top Stories.',
      _ => te ? 'ప్రస్తుతం టాప్ స్టోరీస్ లేవు.' : 'No Top Stories right now.',
    };
    if (stories.isEmpty) {
      if (_topStories.loading) return const SpotlightShimmerCard();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              if (failure != null && failure.status != 400)
                TextButton(
                  onPressed: _refreshVisibleFeed,
                  child: Text(te ? 'మళ్లీ ప్రయత్నించండి' : 'Retry'),
                ),
              TextButton(
                onPressed: () => _selectTopStories(false),
                child: Text(te
                    ? 'స్పాట్‌లైట్‌కు తిరిగి వెళ్లండి'
                    : 'Back to Spotlight'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
          child: RefreshIndicator(
            onRefresh: _refreshVisibleFeed,
            child: FlipPageView(
              key: ValueKey('top_stories_${_topStories.filterKey}'),
              controller: _topPageController,
              itemCount: stories.length,
              onPageChanged: (index) {
                _topPage.value = index;
                SpotlightMediaCoordinator.instance.stopAll();
                _controller.hideOverlay();
              },
              itemBuilder: (context, index) => ValueListenableBuilder<int>(
                valueListenable: _topPage,
                builder: (context, page, _) =>
                    _buildItemFor(context, index, index == page),
              ),
            ),
          ),
        ),
        if (failure != null)
          Positioned(
            top: _topBarHeight + 8,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(message,
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: Listenable.merge([_controller, _topStories]),
      builder: (context, _) {
        final state = _controller.state;
        final statusBarHeight = MediaQuery.paddingOf(context).top;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              // 0. Status bar band — one fixed black strip under the clock
              // and icons. It lives here, not in each card: a band baked
              // into a card showed as a black strip above the image of
              // every card sliding in during a swipe.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: statusBarHeight,
                child: const AnnotatedRegion<SystemUiOverlayStyle>(
                  // Light icons on the black band, in both themes.
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.black,
                    statusBarIconBrightness: Brightness.light,
                    statusBarBrightness: Brightness.dark,
                  ),
                  child: ColoredBox(color: Colors.black),
                ),
              ),

              // 1. Swiping Feed — starts exactly below the status bar. Top
              // padding is removed for the pages so they lay out from their
              // own top edge; anything that offset itself by padding.top
              // lands in the same place on screen as before.
              Positioned.fill(
                top: statusBarHeight,
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: GestureDetector(
                    onTap: _controller.toggleOverlay,
                    behavior: HitTestBehavior.opaque,
                    child: _showTopStories
                        ? _buildTopStoriesFeed()
                        : state.isLoading && state.feed.isEmpty
                            ? const SpotlightShimmerCard()
                            : state.feed.isEmpty
                                ? state.isLocalNews &&
                                        !AppState.instance.hasValidLocation &&
                                        state.errorMessage == null
                                    ? _buildLocationFallback()
                                    : _buildEmptyFeedState(state.isLocalNews)
                                : ScrollConfiguration(
                                    // Android 12+ stretch overscroll swallows the
                                    // overscroll notification RefreshIndicator
                                    // needs, so the pull did nothing on device
                                    // while passing in tests. Drop the indicator
                                    // here; the refresh spinner is the feedback.
                                    behavior: const MaterialScrollBehavior()
                                        .copyWith(overscroll: false),
                                    child: RefreshIndicator(
                                      // refreshFeed() is the same call the
                                      // bottom-bar button already makes.
                                      onRefresh: _controller.refreshFeed,
                                      child: FlipPageView(
                                        key: ValueKey(
                                            'feed_${state.isLocalNews}_${state.locationName}_${state.generation}'),
                                        controller: _pageController,
                                        itemCount: state.feed.length,
                                        onPageChanged: _handlePageChanged,
                                        itemBuilder: _buildItem,
                                      ),
                                    ),
                                  ),
                  ),
                ),
              ),

              // Small floating 3D ad that comes and goes with active use
              // (AdPacer). Above the story's action row, under the chrome.
              // Spotlight has full-page ads already, so no bottom banner.
              Positioned.fill(
                child: PacedAdsOverlay(
                  bottomInset: MediaQuery.paddingOf(context).bottom +
                      _bottomBarHeight +
                      96,
                  showSticky: false,
                  // The 3D ad is the app-wide corner ad (main.dart).
                  showFloating: false,
                  floatingSize: 104,
                ),
              ),

              // 2-4. Chrome. Listens to overlayVisible rather than the
              // controller, so showing or hiding it repaints only these
              // bars and never rebuilds the feed underneath.
              ValueListenableBuilder<bool>(
                valueListenable: _controller.overlayVisible,
                builder: (context, showOverlays, _) => Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      top: showOverlays ? 0 : -140,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        opacity: showOverlays ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !showOverlays,
                          child: _keepChromeAlive(_buildTopOverlay(state)),
                        ),
                      ),
                    ),

                    // 3. Local Location Strip (Only visible when Local mode is active and overlays shown)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      top: (showOverlays &&
                              state.isLocalNews &&
                              !_showTopStories)
                          ? MediaQuery.of(context).padding.top +
                              _topBarHeight +
                              4
                          : -100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          opacity: (showOverlays &&
                                  state.isLocalNews &&
                                  !_showTopStories)
                              ? 1.0
                              : 0.0,
                          child: IgnorePointer(
                            ignoring: !(showOverlays &&
                                state.isLocalNews &&
                                !_showTopStories),
                            child: _keepChromeAlive(_buildLocationStrip()),
                          ),
                        ),
                      ),
                    ),

                    // 4. Bottom Docked Control Bar Overlay (< Back on left, Refresh on right)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      bottom: showOverlays ? 0 : -140,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        opacity: showOverlays ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !showOverlays,
                          child: _keepChromeAlive(_buildBottomOverlay()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    // Embedded as Home's own tab content, back navigation belongs to
    // HomeScreen's PopScope — a second one here would fire alongside it on
    // every back press instead of instead of it.
    if (widget.embedded) {
      return content;
    }

    final canPop = Navigator.of(context).canPop();
    return ImpressionScope(
        log: _impressions,
        child: PopScope(
          canPop: canPop && !_showTopStories,
          onPopInvokedWithResult: (didPop, _) {
            AppTtsService.instance.stop();
            if (!didPop) {
              _closeSpotlight();
            }
          },
          child: content,
        ));
  }
}
