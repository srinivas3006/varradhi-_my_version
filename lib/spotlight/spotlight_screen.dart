import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/navigation/auth_guard.dart';
import '../models/spotlight_item.dart';
import '../models/news_article.dart';
import '../widgets/ads/sponsored_spotlight_ad_card.dart';
import '../services/ad_delivery_service.dart';
import '../core/widgets/flip_page_view.dart';
import '../widgets/spotlight/spotlight_news_card.dart';
import '../widgets/spotlight/spotlight_shimmer_card.dart';
import '../widgets/spotlight/news_language_sheet.dart';
import '../widgets/spotlight/location_prompt_sheet.dart';
import '../widgets/poster_card.dart';
import '../widgets/info_card.dart';
import '../widgets/poll_card.dart';
import '../core/widgets/fit_or_scroll.dart';
import '../widgets/spotlight/spotlight_trending_strip.dart';
import '../screens/news_detail_screen.dart';
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
import 'spotlight_media_coordinator.dart';

class SpotlightScreenView extends StatefulWidget {
  final String? initialStoryId;
  final int? initialStoryIndex;
  final String? initialCategory;
  final bool isLocal;


  const SpotlightScreenView({
    super.key,
    this.initialStoryId,
    this.initialStoryIndex,
    this.initialCategory,
    this.isLocal = false,
  });

  @override
  State<SpotlightScreenView> createState() => _SpotlightScreenViewState();
}

class _SpotlightScreenViewState extends State<SpotlightScreenView>
    with WidgetsBindingObserver {
  late final SpotlightController _controller;
  // A real PageController: the feed rides Flutter's own scroll physics
  // (momentum, fling, settle) instead of the hand-rolled vertical drag
  // handlers it used before, which had none of them — that is what made the
  // swipe feel like it caught.
  final PageController _pageController = PageController();
  int _lastPageIndex = 0;

  /// Which page is settled. A notifier rather than setState: only the two
  /// cards whose isCurrent actually flips need to rebuild, not the feed.
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  Timer? _dwellTimer;
  Timer? _locationPromptTimer;
  bool _hasPromptedLocationThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = SpotlightController(
      initialCategory: widget.initialCategory,
      isLocal: widget.isLocal,
      initialStoryId: widget.initialStoryId,
    );
    // Ask which news language before anything location-related: it decides
    // what the very first feed request asks for.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NewsLanguageSheet.showIfNeeded(context);
    });
    _scheduleGentleLocationPrompt();
    // A deep link can ask for a specific story. The feed is empty at this
    // point, so jump once as soon as it arrives.
    _controller.addListener(_jumpToInitialStoryOnce);
  }

  bool _jumpedToInitialStory = false;

  void _jumpToInitialStoryOnce() {
    if (_jumpedToInitialStory) return;
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SpotlightMediaCoordinator.instance.stopAll();
    AppTtsService.instance.stop();
    _dwellTimer?.cancel();
    _locationPromptTimer?.cancel();
    _controller.removeListener(_jumpToInitialStoryOnce);
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

  void _scheduleGentleLocationPrompt() {
    final state = AppState.instance;
    if (state.hasValidLocation || _hasPromptedLocationThisSession) {
      return;
    }

    // Prompt location gently 1.8 seconds after app enters Spotlight if location is not set yet
    _locationPromptTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (AppState.instance.hasValidLocation ||
          _hasPromptedLocationThisSession) {
        return;
      }
      if (AppTtsService.instance.isPlaying) return;

      _hasPromptedLocationThisSession = true;
      _showGentleLocationPrompt();
    });
  }

  Future<void> _showGentleLocationPrompt() async {
    final state = AppState.instance;
    state.markLocationPrompted();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationPromptSheet(),
    );

    if (result == true && mounted) {
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

    _dwellTimer?.cancel();

    // Dwell logic: only consider meaningful read if user forward-swipes and stays >= 2 seconds
    if (!isSwipingBack && index < _controller.state.feed.length) {
      // After user actively reads past the first 2 stories, gently prompt for location
      if (index >= 2 &&
          !AppState.instance.locationPrompted &&
          !AppState.instance.hasValidLocation &&
          !_hasPromptedLocationThisSession) {
        _hasPromptedLocationThisSession = true;
        _locationPromptTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted && !AppTtsService.instance.isPlaying) {
            _showGentleLocationPrompt();
          }
        });
      }
    }
  }

  void _closeSpotlight() {
    SpotlightMediaCoordinator.instance.stopAll();
    AppTtsService.instance.stop();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) =>
              const HomeScreen(openSpotlightOnStart: false),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  void _shareArticle(NewsArticle article) {
    ShareService.shareArticle(article);
  }

  void _openArticle(NewsArticle article) {
    _controller.resetOverlayTimer();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(
          article: article,
          slug: article.slug.isNotEmpty ? article.slug : article.id,
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
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 76),
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
      padding.top + (state.isLocalNews ? 124 : 76),
      16,
      // When a trending strip sits below, it already owns the bottom of the
      // page. Reserving the chrome height here too double-counted it and
      // squeezed the card enough to give its FitOrScroll real scroll extent
      // — and a vertical scrollable inside a vertical pager wins the drag,
      // which is exactly how a page ends up refusing to advance.
      reserveBottomChrome ? padding.bottom + 88 : 8,
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

  Widget _buildItemFor(BuildContext context, int index, bool isCurrent) {
    const dragDelta = 0.0;
    const dragProgress = 0.0;
    const matchCutProgress = 0.0;

    final state = _controller.state;
    if (index >= state.feed.length) return const SizedBox();

    final item = state.feed[index];

    Widget child;

    switch (item.type) {
      case SpotlightType.standard:
      case SpotlightType.ugc:
        if (item.article == null) return const SizedBox();
        child = SpotlightNewsCard(
          article: item.article!,
          pageIndex: index,
          pageCount: state.feed.length,
          isCurrent: isCurrent,
          dragDelta: dragDelta,
          dragProgress: dragProgress,
          matchCutProgress: matchCutProgress,
          onTap: _controller.toggleOverlay,
          onShare: () => _shareArticle(item.article!),
          onClose: _closeSpotlight,
        );
        break;

      case SpotlightType.carousel:
        if (item.article == null) return const SizedBox();
        child = SpotlightNewsCard(
            article: item.article!,
            pageIndex: index,
            pageCount: state.feed.length,
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
            exposureKey:
                'spotlight_${_controller.state.generation}_${item.id}',
            onClose: () => _controller.removeAdAt(index),
            durationSeconds: item.adBanner!.displayDurationSeconds > 0
                ? item.adBanner!.displayDurationSeconds
                : 5,
            placementZone: 'feed');
        // Same treatment as the poll: a sponsored card leaves most of a tall
        // screen unused, so the remainder goes to trending rather than blank.
        child = _withTrending(index, child);
        break;

      case SpotlightType.poster:
        child = PosterCard(
          key: ValueKey('poster_${item.id}'),
          posterId: item.id,
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
                        ? '${AppState.instance.displayLocation} కోసం ప్రస్తుతం స్థానిక వార్తలు అందుబాటులో లేవు. వేరే జిల్లా లేదా మండలాన్ని ఎంచుకోండి.'
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

  Widget _buildTopOverlay(SpotlightState state) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: Colors.black.withValues(alpha: 0.50),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Profile Icon on Left -> Opens Profile screen
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _controller.resetOverlayTimer();
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
                    color: Colors.white, size: 28),
                tooltip: 'ప్రొఫైల్',
              ),

              // 2. Animated Sliding Toggle Pill: [ ప్రధాన వార్తలు | స్థానికం ]
              Container(
                width: 200,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(21),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: !state.isLocalNews
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
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
                              _controller.toggleMode(false);
                            },
                            child: Center(
                              child: Text(
                                tr('tab_main'), // 'ప్రధాన వార్తలు' in Telugu
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: !state.isLocalNews
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
                              _controller.toggleMode(true);
                              if (!AppState.instance.hasValidLocation) {
                                _showGentleLocationPrompt();
                              }
                            },
                            child: Center(
                              child: Text(
                                tr('tab_local'), // 'స్థానికం' in Telugu
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: state.isLocalNews
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Create Post Action Button (+) in Red Circle
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FF3B30),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'వార్తను పోస్ట్ చేయండి',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _controller.resetOverlayTimer();
                    requireAuth(
                      context,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreatePostScreen()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 28),
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
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: bottomPadding > 0 ? bottomPadding : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.50),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const Key('spotlight_home_btn'),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _closeSpotlight();
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 22),
                tooltip: 'వెనుకకు',
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _controller.resetOverlayTimer();
                  _controller.refreshFeed();
                },
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 26),
                tooltip: 'తాజాకరించండి',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        AppTtsService.instance.stop();
        if (!didPop) {
          _closeSpotlight();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final state = _controller.state;

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Stack(
              children: [
                // 1. Swiping Fullscreen Feed
                GestureDetector(
                  onTap: _controller.toggleOverlay,
                  behavior: HitTestBehavior.opaque,
                  child: state.isLoading && state.feed.isEmpty
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
                                edgeOffset:
                                    MediaQuery.paddingOf(context).top,
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
                  top: (showOverlays && state.isLocalNews)
                      ? MediaQuery.of(context).padding.top + 70
                      : -100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity:
                          (showOverlays && state.isLocalNews) ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !(showOverlays && state.isLocalNews),
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
      ),
    );
  }
}
