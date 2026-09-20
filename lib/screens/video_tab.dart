import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/media/media_source.dart';
import '../core/navigation/app_navigator.dart';
import '../core/navigation/auth_guard.dart';
import '../core/media/video_playback_controller.dart';
import '../core/media/video_player_widget.dart';
import '../localization/app_translations.dart';
import '../models/ad_banner.dart';
import '../models/video_item.dart';
import '../repositories/video_repository.dart';
import '../services/ad_manager.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/bottom_sticky_ad_banner.dart';
import 'location_selection_screen.dart';
import 'search_screen.dart';
import 'spotlight_screen.dart';
import 'shorts_viewer_screen.dart';

class VideoTab extends StatefulWidget {
  final bool isActive;
  const VideoTab({super.key, this.isActive = true});

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab> {
  final ScrollController _scrollController = ScrollController();
  final List<VideoItem> _videos = [];
  bool _isLoading = true;
  String? _shortsCursor;
  bool _hasMoreShorts = true;
  bool _fetching = false;
  late String _language;
  String get _queryIdentity => [
        AppState.instance.contentLanguage,
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.city,
        AppState.instance.subdistrict,
        AppState.instance.village
      ].join('|');

  void _onPreferencesChanged() {
    final language = _queryIdentity;
    if (language == _language) return;
    _language = language;
    _videos.clear();
    _bottomAd = null;
    _bottomAdRequested = false;
    _refresh();
    if (widget.isActive) _loadBottomAd();
  }

  int _generation = 0;
  bool _hasMore = true;
  AdBanner? _bottomAd;
  bool _bottomAdRequested = false;
  bool _bottomAdDismissed = false;

  @override
  void initState() {
    super.initState();
    _language = _queryIdentity;
    AppState.instance.addListener(_onPreferencesChanged);
    _scrollController.addListener(_onScroll);
    _loadVideos();
    if (widget.isActive) {
      Future.microtask(_loadBottomAd);
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onPreferencesChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      setState(() {});
      if (widget.isActive) {
        Future.microtask(_loadBottomAd);
      }
    }
  }

  Future<void> _loadBottomAd() async {
    if (_bottomAdDismissed || _bottomAdRequested || _bottomAd != null) return;
    _bottomAdRequested = true;
    final identity = _queryIdentity;
    final ad = await _selectFirstAvailableAd(
      zones: const ['feed'],
      preferType: 'bottom_sticky',
    );
    if (!mounted || identity != _queryIdentity || ad == null) return;
    setState(() => _bottomAd = ad);
  }

  Future<AdBanner?> _selectFirstAvailableAd({
    required List<String> zones,
    required String preferType,
  }) async {
    for (final zone in zones) {
      final ads = await AdManager.instance.getAdsForZone(zone);
      final selected = AdManager.instance.selectAd(
        ads.where((ad) => ad.isBottomSticky).toList(),
      );
      if (selected != null) return selected;
    }
    return null;
  }

  Future<void> _refresh() async {
    ++_generation;
    _fetching = false;
    VideoRepository.instance.clearCache();
    setState(() {
      _isLoading = _videos.isEmpty;
      _shortsCursor = null;
      _hasMoreShorts = true;
      _hasMore = true;
    });
    await _loadVideos(refresh: true);
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (_fetching || !_hasMore) return;
    final generation = _generation;
    _fetching = true;
    final fetched = <VideoItem>[];
    String? failure;
    bool succeeded = false;
    try {
      // Shorts only. Regular videos live in the Home carousel, which reads
      // /video-feed/ separately.
      if (_hasMoreShorts) {
        try {
          final response = await VideoRepository.instance.getShortsFeed(
            cursor: _shortsCursor,
          );
          if (!mounted || generation != _generation) return;
          if (response.hasErrors) throw Exception(response.errorMessage);
          fetched.addAll(response.data ?? []);
          _shortsCursor = response.nextCursor;
          _hasMoreShorts = _shortsCursor != null;
          succeeded = true;
        } catch (e) {
          failure = e.toString();
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        if (refresh && succeeded) _videos.clear();
        final seen = _videos.map((video) => video.id).toSet();
        // isShort is the one classification both surfaces use. Filtering
        // here as well as at the endpoint means a regular video cannot leak
        // in through pagination or refresh.
        _videos.addAll(fetched
            .where((video) => video.isShort)
            .where((video) => seen.add(video.id)));
        _hasMore = _hasMoreShorts;
      });
      if (failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure)),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _fetching = false;
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 500) {
      _loadVideos();
    }
  }

  String _videoUrl(VideoItem video) {
    if ((video.youtubeUrl ?? '').isNotEmpty) return video.youtubeUrl!;
    if ((video.videoUrl ?? '').isNotEmpty) return video.videoUrl!;
    if ((video.youtubeVideoId ?? '').isNotEmpty) {
      return 'https://www.youtube.com/watch?v=${video.youtubeVideoId}';
    }
    return '';
  }

  void _openVideo(VideoItem video) {
    final url = _videoUrl(video);
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ఈ వీడియో లింక్ అందుబాటులో లేదు.')),
      );
      return;
    }
    HapticFeedback.selectionClick();

    // This tab holds Shorts, so open the vertical 9:16 viewer positioned on
    // the tapped item — not the landscape player, which letterboxed them.
    // The whole loaded list goes with it so swiping up and down works.
    final index = _videos.indexWhere((v) => v.id == video.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShortsViewerScreen(
          shorts: _videos,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _videos.isEmpty) {
      return Container(
        color: const Color(0xFFF8F7FB),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFC80022)),
        ),
      );
    }

    if (_videos.isEmpty) {
      return Container(
        color: const Color(0xFFF8F7FB),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_rounded,
                    color: Color(0xFF8A8A8A), size: 56),
                const SizedBox(height: 16),
                const Text(
                  'వీడియోలు లేవు',
                  style: TextStyle(
                      color: Color(0xFF161616),
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'కొన్ని క్షణాల్లో మళ్లీ ప్రయత్నించండి.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF767676), fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('మళ్లీ లోడ్ చేయండి'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC80022),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Every Short belongs in the Shorts feed now; the LIVE section above it
    // carries real broadcasts instead of borrowing the first Short.
    final bulletinVideos = _videos;
    final bottomPadding = (_bottomAd != null ? 162.0 : 94.0) +
        MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFFC80022),
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(
                  child: _buildSectionTitle(
                    isBulletin: true,
                    title: 'Shorts',
                    trailing: 'My district',
                    showDistrictIcon: true,
                    onTrailingTap: _changeLocation,
                  ),
                ),
                // Portrait tiles in a grid. Shorts are 9:16, and the wide
                // list card letterboxed every one of them with black bars
                // down both sides. Two columns also put four shorts on
                // screen where the list showed one and a half.
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                      // 9:16 for the thumbnail plus room for two title lines
                      // and the meta row beneath it.
                      childAspectRatio: 9 / 19.5,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = bulletinVideos[index];
                        return _ShortTile(
                          video: video,
                          onTap: () => _openVideo(video),
                        );
                      },
                      childCount: bulletinVideos.length,
                    ),
                  ),
                ),
                if (_hasMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFC80022))),
                    ),
                  ),
                SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
              ],
            ),
          ),
          if (_bottomAd != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 65,
              child: SafeArea(
                top: false,
                child: BottomStickyAdBanner(
                  key: ValueKey('video_bottom_${_bottomAd!.id}'),
                  ad: _bottomAd!,
                  placementZone: 'feed',
                  onDismiss: () {
                    if (mounted)
                      setState(() {
                        _bottomAdDismissed = true;
                        _bottomAd = null;
                      });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _changeLocation() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LocationSelectionScreen()),
    );
    if (changed == true && mounted) {
      setState(() {});
      _refresh();
    }
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 6,
            bottom: 10,
            left: 16,
            right: 16,
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

  Widget _buildSectionTitle({
    String? leading,
    required String title,
    String? trailing,
    bool isBulletin = false,
    bool showDistrictIcon = false,
    VoidCallback? onTrailingTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          if (leading != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFC80022),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(leading,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
          ] else if (isBulletin) ...[
            Container(
              width: 5,
              height: 18,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC80022),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Color(0xFF161616),
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900)),
          ),
          if (trailing != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: showDistrictIcon
                      ? const Color(0xFFEEF2F8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showDistrictIcon) ...[
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: Color(0xFF4B5563)),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      trailing,
                      style: TextStyle(
                        color: showDistrictIcon
                            ? const Color(0xFF374151)
                            : const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Individual Vertical Short Card with Unified Video Engine & Glass Controls
class VideoCardItem extends StatefulWidget {
  final VideoItem video;
  final bool isFocused;
  final bool isNext;
  final bool isMuted;
  final bool hasBottomAd;
  final VoidCallback onToggleMute;

  const VideoCardItem({
    super.key,
    required this.video,
    required this.isFocused,
    this.isNext = false,
    this.isMuted = false,
    this.hasBottomAd = false,
    required this.onToggleMute,
  });

  @override
  State<VideoCardItem> createState() => _VideoCardItemState();
}

class _VideoCardItemState extends State<VideoCardItem>
    with SingleTickerProviderStateMixin {
  VideoPlaybackController? _controller;
  int _generationToken = 0;

  // Heart Pulse Animation Setup
  bool _showHeartAnimation = false;
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnimation;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScaleAnimation = Tween<double>(begin: 0.2, end: 1.4).animate(
      CurvedAnimation(parent: _heartAnimController, curve: Curves.elasticOut),
    );

    if (widget.isFocused) {
      _initController();
    }
  }

  void _disposeController() {
    _generationToken++;
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _initController() async {
    _disposeController();
    final int token = ++_generationToken;

    final MediaSource source = widget.video.toMediaSource();
    if (source.type == MediaSourceType.unsupported ||
        source.type == MediaSourceType.imageOnly) {
      return;
    }

    // Hand the intent to the controller instead of calling play() after the
    // setState below: the player mounts a frame later, so that play() never
    // reached an attached YouTube surface. Focus behaviour is unchanged.
    final ctrl =
        VideoPlaybackController.fromSource(source, autoPlay: widget.isFocused);
    ctrl.setLooping(true);
    ctrl.setMuted(widget.isMuted);

    try {
      await ctrl.initialize();
      if (!mounted || token != _generationToken) {
        ctrl.dispose();
        return;
      }

      setState(() {
        _controller = ctrl;
      });


    } catch (e) {
      if (!mounted || token != _generationToken) {
        ctrl.dispose();
        return;
      }
      debugPrint('[VideoCardItem] Playback init error: $e');
    }
  }

  @override
  void didUpdateWidget(covariant VideoCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isMuted != oldWidget.isMuted) {
      _controller?.setMuted(widget.isMuted);
    }

    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        if (_controller == null) {
          _initController();
        } else {
          _controller?.play();
        }
      } else {
        // Immediately pause and dispose off-screen player to free native memory
        _disposeController();
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    _heartAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    HapticFeedback.selectionClick();
    _controller!.togglePlayPause();
  }

  void _triggerDoubleTapLike() {
    HapticFeedback.mediumImpact();
    requireAuth(context, () {
      if (!AppState.instance.isLiked(widget.video.id)) {
        AppState.instance.toggleLike(widget.video.id);
      }

      setState(() => _showHeartAnimation = true);
      _heartAnimController.forward(from: 0.0).then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showHeartAnimation = false);
        });
      });
    });
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    requireAuth(context, () => AppState.instance.toggleLike(widget.video.id));
  }

  void _shareVideo() {
    HapticFeedback.lightImpact();
    final link = widget.video.youtubeVideoId != null
        ? 'https://youtube.com/watch?v=${widget.video.youtubeVideoId}'
        : (widget.video.videoUrl ?? '');
    SharePlus.instance.share(
      ShareParams(
          text:
              'Check out this news video on Vaaradhi: ${widget.video.title}\n$link'),
    );
  }

  void _openCommentsBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(articleId: widget.video.id),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, child) {
        final isLiked = AppState.instance.isLiked(widget.video.id);
        final displayLikes = widget.video.likes + (isLiked ? 1 : 0);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Player Surface with Double-Tap Recognition
            GestureDetector(
              onTap: _togglePlayPause,
              onDoubleTap: _triggerDoubleTapLike,
              child: Container(
                color: Colors.black,
                child: _controller != null
                    ? VideoPlayerWidget(
                        controller: _controller!,
                        fit: BoxFit.cover,
                        showControls: false,
                        onRetry: _initController,
                      )
                    : _buildThumbnailPlaceholder(),
              ),
            ),

            // 2. Center Play Indicator when Paused
            if (_controller != null)
              ValueListenableBuilder<VideoPlaybackState>(
                valueListenable: _controller!,
                builder: (context, state, _) {
                  if (state.isInitialized &&
                      !state.isPlaying &&
                      !state.isBuffering) {
                    return Center(
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

            // 3. Animated Double-Tap Heart Pulse
            if (_showHeartAnimation)
              Center(
                child: ScaleTransition(
                  scale: _heartScaleAnimation,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.redAccent,
                    size: 110,
                  ),
                ),
              ),

            // 4. Bottom Vignette Masking
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black38,
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black87,
                      ],
                      stops: [0.0, 0.2, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 5. Metadata Overlay (Bottom-Left)
            Positioned(
              left: 16,
              bottom: widget.hasBottomAd ? 172 : 100,
              right: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.video.channel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.video.views} views · ${widget.video.duration}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),

            // 6. Frosted Glass Action Rail (Right Side)
            Positioned(
              right: 16,
              bottom: widget.hasBottomAd ? 190 : 120,
              child: _buildActionRail(isLiked, displayLikes),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThumbnailPlaceholder() {
    if (widget.video.thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.video.thumbnailUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.black),
        errorWidget: (_, __, ___) => const Center(
          child:
              Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 56),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
            color: Colors.redAccent, strokeWidth: 2.5),
      ),
    );
  }

  /// Right-hand Vertical Action Rail with Frosted Glass Shell
  Widget _buildActionRail(bool isLiked, int displayLikes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mute/Unmute Action
              _buildRailButton(
                icon: widget.isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                iconColor: widget.isMuted ? Colors.amberAccent : Colors.white,
                label: widget.isMuted ? 'Muted' : 'Sound',
                onTap: widget.onToggleMute,
              ),
              const SizedBox(height: 18),

              // Like Action
              _buildRailButton(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: isLiked ? Colors.redAccent : Colors.white,
                label: _formatCount(displayLikes),
                onTap: _toggleLike,
              ),
              const SizedBox(height: 18),

              // Comments Action
              _buildRailButton(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: Colors.white,
                label: tr('chat'),
                onTap: _openCommentsBottomSheet,
              ),
              const SizedBox(height: 18),

              // Share Action
              _buildRailButton(
                icon: Icons.share_rounded,
                iconColor: Colors.white,
                label: tr('share'),
                onTap: _shareVideo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRailButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Sliding Comments Bottom Sheet Component
// ==========================================
class CommentsBottomSheet extends StatefulWidget {
  final String articleId;
  const CommentsBottomSheet({super.key, required this.articleId});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!AppState.instance.isLoggedIn) {
      requireAuth(context, () {});
      return;
    }

    AppState.instance.addComment(widget.articleId, text);
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Comments',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                final comments =
                    AppState.instance.getComments(widget.articleId);

                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first!',
                        style: TextStyle(color: Colors.white70)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white10,
                          backgroundImage: NetworkImage(comment.avatarUrl),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.username,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.text,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Comment Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.redAccent),
                  onPressed: _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A Short as a portrait tile: 9:16 thumbnail, title, view count.
///
/// Replaces the wide list card, which letterboxed portrait content with
/// black bars down both sides.
class _ShortTile extends StatelessWidget {
  const _ShortTile({required this.video, required this.onTap});

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF1A1A1A)),
                  if (video.thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      // Cover, not contain: the tile is already the content's
                      // own shape, so there is nothing to letterbox.
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFF1A1A1A)),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.videocam_off_rounded,
                          color: Colors.white24),
                    ),
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white70, size: 34),
                  ),
                  if (video.duration.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.duration,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: Color(0xFF161616),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            video.views,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
