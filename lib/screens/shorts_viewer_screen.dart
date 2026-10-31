import 'package:flutter/material.dart';

import '../core/ads/ad_insertion.dart';
import '../core/ads/ad_placement.dart';
import '../core/ads/zone_ads.dart';
import '../core/media/media_source.dart';
import '../core/media/video_playback_controller.dart';
import '../core/media/video_player_widget.dart';
import '../core/widgets/flip_page_view.dart';
import '../models/ad_banner.dart';
import '../models/video_item.dart';
import '../widgets/ads/video_feed_ad_page.dart';

/// Full-screen vertical Shorts feed: one 9:16 Short at a time, swipe up for
/// the next and down for the previous.
///
/// Built on [FlipPageView] — the same vertical pager Spotlight uses — and
/// [VideoPlayerWidget], rather than a second player implementation.
///
/// Only the visible Short holds a controller. Everything else is released, so
/// a long feed cannot accumulate players.
class ShortsViewerScreen extends StatefulWidget {
  const ShortsViewerScreen({
    super.key,
    required this.shorts,
    this.initialIndex = 0,
    this.isActive = true,
    this.showBackButton = true,
    this.onLoadMore,
    this.hasMore = false,
  });

  final List<VideoItem> shorts;
  final int initialIndex;

  /// False while the host tab is off-screen. Nothing plays then: a Short must
  /// never be heard from Home or any other tab.
  final bool isActive;

  /// Hidden when the viewer *is* a tab rather than a pushed route.
  final bool showBackButton;

  /// Called as the reader nears the end, so the host can fetch another page.
  final VoidCallback? onLoadMore;
  final bool hasMore;

  @override
  State<ShortsViewerScreen> createState() => _ShortsViewerScreenState();
}

class _ShortsViewerScreenState extends State<ShortsViewerScreen> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);

  /// Controllers for the visible Short and its immediate neighbours only.
  /// Keyed by page index.
  final Map<int, VideoPlaybackController> _controllers = {};
  late int _current = widget.initialIndex;

  /// `video_feed` ads in use, and the pages: each a [VideoItem] or an
  /// [AdBanner] (at least 8 videos apart).
  List<AdBanner> _ads = const [];
  late List<Object> _pages = _buildPages(_ads);

  List<Object> _buildPages(List<AdBanner> ads) {
    if (ads.isEmpty) return List<Object>.of(widget.shorts);
    return [
      for (final item in insertAdsIntoFeed<VideoItem>(
        contentItems: widget.shorts,
        eligibleAds: ads,
        placementZone: AdPlacement.videoFeed,
        policy: AdFrequencyPolicy.videoFeed,
        contentKey: (v) => v.id,
      ))
        item.isAd ? item.ad! : item.content as VideoItem,
    ];
  }

  /// Ads arrive after the first Shorts are on screen. They are used only if
  /// the reader has not reached the first ad position yet, so the page on
  /// screen never shifts under them.
  Future<void> _loadAds() async {
    final ads = await ZoneAds.load(AdPlacement.videoFeed);
    if (!mounted || ads.isEmpty) return;
    final pages = _buildPages(ads);
    final firstAd = pages.indexWhere((p) => p is AdBanner);
    if (firstAd < 0 || _current >= firstAd) return;
    setState(() {
      _ads = ads;
      _pages = pages;
    });
  }

  void _skipAd() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _syncControllers();
    _loadAds();
  }

  @override
  void didUpdateWidget(covariant ShortsViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // More Shorts: the pages before them keep their places.
    if (widget.shorts.length != oldWidget.shorts.length ||
        !identical(widget.shorts, oldWidget.shorts)) {
      _pages = _buildPages(_ads);
    }

    // Leaving the tab releases the player outright rather than pausing it —
    // a backgrounded Short holding a webview is the thing that keeps audio
    // alive somewhere the reader cannot see it.
    if (oldWidget.isActive && !widget.isActive) {
      _releaseAll();
      return;
    }
    if (!oldWidget.isActive && widget.isActive) {
      _syncControllers();
    }

    // A new page arrived: the current index may now be mid-list.
    if (widget.shorts.length != oldWidget.shorts.length && widget.isActive) {
      _syncControllers();
    }
  }

  void _releaseAll() {
    for (final c in _controllers.values) {
      c.pause();
      c.dispose();
    }
    _controllers.clear();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  MediaSource? _sourceFor(VideoItem item) {
    final ytId = item.youtubeVideoId;
    if (ytId != null && ytId.isNotEmpty) {
      return MediaSource.youtube(
        videoId: ytId,
        rawUrl: item.youtubeUrl,
        thumbnailUrl: item.thumbnailUrl,
        isShort: true,
      );
    }
    final url = item.videoUrl;
    if (url != null && url.isNotEmpty) {
      return MediaSource.networkVideo(
        videoUrl: url,
        thumbnailUrl: item.thumbnailUrl,
        isShort: true,
      );
    }
    return null;
  }

  /// Keeps a controller for [_current] only, releasing the rest.
  ///
  /// Bounded on purpose: preloading the whole feed would leave one player per
  /// Short alive, and only one can ever be heard at a time anyway.
  void _syncControllers() {
    if (!widget.isActive) return;

    for (final index in _controllers.keys.toList()) {
      if (index != _current) {
        _controllers.remove(index)?.dispose();
      }
    }

    if (_controllers.containsKey(_current)) return;
    if (_current < 0 || _current >= _pages.length) return;
    final page = _pages[_current];
    if (page is! VideoItem) return; // an ad page plays its own creative

    final source = _sourceFor(page);
    if (source == null) return;

    // autoPlay is correct here and is not feed autoplay: this screen is only
    // reached by an explicit tap, and the player honours autoPlay when it
    // becomes ready — a play() call would race the surface mounting.
    final controller =
        VideoPlaybackController.fromSource(source, autoPlay: true);
    _controllers[_current] = controller;
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object e) {
      debugPrint('[ShortsViewer] init failed for index $_current: $e');
    });
  }

  void _onPageChanged(int index) {
    if (index == _current) return;
    setState(() => _current = index);
    // _syncControllers disposes every controller but the visible one, so the
    // Short being swiped away stops rather than playing on underneath.
    _syncControllers();

    // Fetch ahead so the feed does not stall at the last card.
    if (widget.hasMore && index >= _pages.length - 3) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shorts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No shorts available',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlipPageView(
            controller: _pageController,
            // One extra page while more are loading, so the feed ends on a
            // spinner rather than a wall.
            itemCount: _pages.length + (widget.hasMore ? 1 : 0),
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (index >= _pages.length) {
                return const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white70),
                );
              }

              final page = _pages[index];
              if (page is AdBanner) {
                return VideoFeedAdPage(
                  ad: page,
                  active: widget.isActive && index == _current,
                  onSkip: _skipAd,
                  exposureKey: 'video_feed_${page.id}_$index',
                );
              }
              final short = page as VideoItem;
              final controller = _controllers[index];

              return Center(
                child: AspectRatio(
                  // 9:16 — a Short is portrait, and letterboxing it into a
                  // landscape frame is what the regular player did.
                  aspectRatio: 9 / 16,
                  child: controller != null
                      ? VideoPlayerWidget(
                          controller: controller,
                          fit: BoxFit.cover,
                          showControls: true,
                        )
                      : _Placeholder(short: short),
                ),
              );
            },
          ),

          // Back returns to wherever the reader opened this from. Hidden
          // when the viewer is the tab itself — there is nothing to go back
          // to, and the bottom bar is the way out.
          if (widget.showBackButton)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
              ),
            ),

          // Title of the Short currently on screen.
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Text(
                _current < _pages.length && _pages[_current] is VideoItem
                    ? (_pages[_current] as VideoItem).title
                    : '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail shown while a Short's player is still coming up.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.short});
  final VideoItem short;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (short.thumbnailUrl.isNotEmpty)
            Image.network(short.thumbnailUrl, fit: BoxFit.cover),
          const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
