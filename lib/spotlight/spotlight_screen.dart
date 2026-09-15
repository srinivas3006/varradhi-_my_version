import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/navigation/auth_guard.dart';
import '../models/spotlight_item.dart';
import '../models/news_article.dart';
import '../widgets/ads/sponsored_spotlight_ad_card.dart';
import '../services/ad_delivery_service.dart';
import '../widgets/parallax_page_flip.dart';
import '../widgets/spotlight/spotlight_news_card.dart';
import '../widgets/spotlight/spotlight_promo_card.dart';
import '../widgets/spotlight/spotlight_shimmer_card.dart';
import '../widgets/spotlight/location_prompt_sheet.dart';
import '../widgets/poster_card.dart';
import '../widgets/info_card.dart';
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
  final ParallaxPageFlipController _flipController =
      ParallaxPageFlipController();
  int _lastPageIndex = 0;
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
    _scheduleGentleLocationPrompt();
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
    _controller.dispose();
    super.dispose();
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

    // Mutually exclusive playback: Stop active TTS/Video upon swiping
    SpotlightMediaCoordinator.instance.stopAll();

    // Auto-hide overlays on swipe for clean, immersive reading
    if (_controller.state.showOverlays) {
      _controller.hideOverlay();
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

  Widget _buildItem(
    BuildContext context,
    int index,
    bool isCurrent,
    double dragDelta,
    double dragProgress,
    double matchCutProgress,
  ) {
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
            isCurrent: isCurrent,
            dragDelta: dragDelta,
            dragProgress: dragProgress,
            matchCutProgress: matchCutProgress,
            onTap: _controller.toggleOverlay,
            onShare: () => _shareArticle(item.article!),
            onClose: _closeSpotlight);
        break;

      case SpotlightType.promo:
        child = SpotlightPromoCard(
          imageUrl: item.promoImageUrl ?? '',
        );
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
        break;

      case SpotlightType.poster:
        child = PosterCard(
          key: ValueKey('poster_${item.id}'),
          mediaUrl: item.mediaUrl ?? '',
          imageUrls: item.imageUrls ?? [],
          durationSeconds: 0,
          onClose: _flipController.next,
        );
        break;

      case SpotlightType.infoCard:
        child = InfoCard(
          title: item.title ?? '',
        );
        break;

      case SpotlightType.shimmer:
        child = const SpotlightShimmerCard();
        break;
    }

    return RepaintBoundary(
      key: ValueKey('spotlight-card-${item.id}-$index'),
      child: child,
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
                tooltip: 'Profile',
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
                  tooltip: 'Post News',
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF4A4A4A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
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
                tooltip: 'Back',
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _controller.resetOverlayTimer();
                  _controller.refreshFeed();
                },
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 26),
                tooltip: 'Refresh',
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
    final initialIndex = widget.initialStoryIndex ??
        _controller.findInitialIndex(widget.initialStoryId);

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
                          : ParallaxPageFlip(
                              key: ValueKey(
                                  'feed_${state.isLocalNews}_${state.locationName}_${state.generation}'),
                              controller: _flipController,
                              initialIndex: initialIndex < state.feed.length
                                  ? initialIndex
                                  : 0,
                              itemCount: state.feed.length,
                              onPageChanged: _handlePageChanged,
                              onSwipeStart: () {
                                SpotlightMediaCoordinator.instance.stopAll();
                                AppTtsService.instance.stop();
                              },
                              onTap: _controller.toggleOverlay,
                              itemBuilder: _buildItem,
                            ),
                ),

                // 2. Top Frosted Glass Overlay (Profile, [ ప్రధాన వార్తలు | స్థానికం ], + Button)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: state.showOverlays ? 0 : -140,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    opacity: state.showOverlays ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !state.showOverlays,
                      child: _buildTopOverlay(state),
                    ),
                  ),
                ),

                // 3. Local Location Strip (Only visible when Local mode is active and overlays shown)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: (state.showOverlays && state.isLocalNews)
                      ? MediaQuery.of(context).padding.top + 70
                      : -100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity:
                          (state.showOverlays && state.isLocalNews) ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !(state.showOverlays && state.isLocalNews),
                        child: _buildLocationStrip(),
                      ),
                    ),
                  ),
                ),

                // 4. Bottom Floating Capsule Overlay (< Back on left, Refresh on right)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  bottom: state.showOverlays
                      ? MediaQuery.of(context).padding.bottom + 16
                      : -100,
                  left: 20,
                  right: 20,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    opacity: state.showOverlays ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !state.showOverlays,
                      child: _buildBottomOverlay(),
                    ),
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
