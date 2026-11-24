import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/media/media_resolver.dart';
import '../../core/media/media_source.dart';
import '../../core/media/network_video_playback_controller.dart';
import '../../core/media/video_playback_controller.dart';
import '../../core/media/video_player_widget.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import '../../spotlight/spotlight_media_coordinator.dart';
import '../../theme/app_theme.dart';
import 'ad_video_preloader.dart';
import 'ad_viewability_detector.dart';
import 'full_screen_ad_image.dart';

/// Production video ad card.
///
/// Features:
/// - Reuses STEP 3 media infrastructure ([MediaResolver], [NetworkVideoPlaybackController])
/// - Poster display while loading or when video is absent
/// - Auto-plays when >= 70% visible (muted in a feed, with sound full
///   screen); pauses when scrolled out of view
/// - Registers active video with [AdManager] so interstitials are not triggered
/// - Properly disposes all video resources upon unmount
/// - Tracks viewability and clicks via [AdManager]
class VideoAdCard extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;

  /// Fills the page it is given: the video edge to edge (the same fill rule
  /// as full-screen images), title and call to action over a fade at the
  /// bottom. For full-page placements: Spotlight, interstitial, Shorts and
  /// Reels. Off, it is the feed card: 16:9 player above a white body.
  final bool fullScreen;

  /// Full screen only: false when the host draws its own title and call to
  /// action (the interstitial).
  final bool showDetails;

  /// Playback position and length, as the video plays, so a host's countdown
  /// follows the video rather than a clock of its own.
  final void Function(Duration position, Duration duration)? onProgress;

  /// The video played to its end (once). It is not restarted.
  final VoidCallback? onCompleted;

  /// The video could not be played (the poster is shown instead).
  final VoidCallback? onFailed;

  const VideoAdCard({
    super.key,
    required this.ad,
    this.placementZone = 'feed',
    this.exposureKey,
    this.fullScreen = false,
    this.showDetails = true,
    this.onProgress,
    this.onCompleted,
    this.onFailed,
  });

  /// The video has reached its end.
  static bool reachedEnd(VideoPlaybackState v) =>
      v.status == PlaybackStatus.completed ||
      (v.duration > Duration.zero &&
          v.isInitialized &&
          v.position >= v.duration);

  @override
  State<VideoAdCard> createState() => _VideoAdCardState();
}

class _VideoAdCardState extends State<VideoAdCard> with WidgetsBindingObserver {
  NetworkVideoPlaybackController? _playbackController;
  bool _isInitialized = false;

  /// The video could not be played: the poster stays instead.
  bool _videoFailed = false;

  /// Played to the end: it stays on its last frame and is not restarted
  /// (only the reader's Replay plays it again).
  bool _completed = false;
  bool _isDisposed = false;
  bool _isVisible = false;
  bool _active = true;
  bool _foreground = true;
  bool _registered = false;
  final Key _visibilityKey = UniqueKey();
  late final String _playbackId = 'ad:${_visibilityKey.toString()}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    SpotlightMediaCoordinator.instance.addListener(_onMediaChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = AdActivityScope.isActive(context);
    // A full-page ad opens its player as soon as its page is built, not when
    // it is on screen, so it starts on a frame rather than a spinner.
    if (widget.fullScreen && _playbackController == null) _initPlayer();
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  void _onMediaChanged() {
    if (_registered &&
        SpotlightMediaCoordinator.instance.activeVideoArticleId !=
            _playbackId) {
      _pause();
    }
  }

  void _pause() {
    _playbackController?.pause();
    if (_registered) {
      _registered = false;
      AdManager.instance.unregisterActiveVideo();
      SpotlightMediaCoordinator.instance.notifyVideoStopped(_playbackId);
    }
  }

  @override
  void didUpdateWidget(covariant VideoAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.videoUrl != widget.ad.videoUrl ||
        oldWidget.ad.id != widget.ad.id) {
      _pause();
      _playbackController?.removeListener(_onPlayback);
      _playbackController?.dispose();
      _playbackController = null;
      _isInitialized = false;
      _videoFailed = false;
      _completed = false;
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    final shouldPlay = _isVisible && _active && _foreground && !_isDisposed;
    if (shouldPlay && _playbackController == null && !_videoFailed) {
      _initPlayer();
    }
    if (_playbackController == null || !_isInitialized) return;
    if (shouldPlay && !_completed) {
      _playbackController!.play();
      if (!_registered) {
        _registered = true;
        AdManager.instance.registerActiveVideo();
        SpotlightMediaCoordinator.instance.notifyVideoStarted(_playbackId);
      }
    } else {
      _pause();
    }
  }

  void _initPlayer() {
    if (widget.ad.videoUrl.isEmpty || _videoFailed) return;

    // Opened ahead of time by the screen (Spotlight), if it got here first.
    final preloaded = AdVideoPreloader.instance.take(widget.ad.videoUrl);
    final NetworkVideoPlaybackController controller;
    final Future<void> ready;
    if (preloaded != null) {
      controller = preloaded.controller;
      ready = preloaded.ready;
    } else {
      final mediaSource = MediaResolver.resolve(
        videoUrl: widget.ad.videoUrl,
        thumbnailUrl: widget.ad.imageUrl,
      );
      if (mediaSource.type != MediaSourceType.networkVideo) return;
      controller = NetworkVideoPlaybackController(
        mediaSource,
        autoPlay: false,
        // Full-page ads play with sound (the reader can mute); a video in a
        // feed list stays muted, so scrolling the news never starts audio.
        isMuted: !widget.fullScreen,
        // Played once: looping restarted the ad the moment it ended.
        loop: false,
      );
      ready = controller.initialize();
    }
    _playbackController = controller;

    void settle({required bool failed}) {
      if (_isDisposed ||
          !mounted ||
          !identical(controller, _playbackController)) {
        return;
      }
      if (failed) {
        // The poster stays (or the page stays black without one); the ad
        // never shows a broken player.
        _playbackController = null;
        controller.dispose();
        setState(() => _videoFailed = true);
        widget.onFailed?.call();
        return;
      }
      // A preloaded player may have been opened looping by an older build.
      controller.setLooping(false);
      controller.addListener(_onPlayback);
      setState(() => _isInitialized = true);
      _onPlayback();
      _syncPlayback();
    }

    // initialize() reports a failure in its state rather than by throwing.
    ready.then<void>((_) {
      settle(failed: controller.value.status == PlaybackStatus.error);
    }).catchError((_) => settle(failed: true));
  }

  /// Follows the playing video: reports its progress, and at its end marks
  /// the ad completed once and leaves it on the last frame.
  void _onPlayback() {
    final controller = _playbackController;
    if (controller == null || _isDisposed || !_isInitialized) return;
    final v = controller.value;
    if (v.duration > Duration.zero) {
      widget.onProgress?.call(v.position, v.duration);
    }
    if (_completed || !_registered || !VideoAdCard.reachedEnd(v)) return;
    _completed = true;
    _pause();
    AdManager.instance.recordComplete(widget.ad,
        placementZone: widget.placementZone, contextKey: widget.exposureKey);
    if (mounted) setState(() {});
    widget.onCompleted?.call();
  }

  /// The reader asked to watch it again.
  Future<void> _replay() async {
    final controller = _playbackController;
    if (controller == null) return;
    await controller.seek(Duration.zero);
    if (!mounted || _isDisposed) return;
    setState(() => _completed = false);
    _syncPlayback();
  }

  Widget _replayButton() {
    return Center(
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
        child: IconButton(
          key: const Key('video_ad_replay'),
          onPressed: _replay,
          iconSize: 32,
          color: Colors.white,
          icon: Icon(_playbackController != null &&
                  _playbackController!.value.position > Duration.zero
              ? Icons.replay_rounded
              : Icons.play_arrow_rounded),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SpotlightMediaCoordinator.instance.removeListener(_onMediaChanged);
    _pause();
    _isDisposed = true;
    _playbackController?.removeListener(_onPlayback);
    if (_playbackController != null) {
      if (_registered) {
        AdManager.instance.unregisterActiveVideo();
      }
      _playbackController!.dispose();
      _playbackController = null;
    }
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_isDisposed || !mounted) return;

    final nowVisible = info.visibleFraction >= 0.7;
    if (nowVisible != _isVisible) {
      setState(() {
        _isVisible = nowVisible;
      });

      _syncPlayback();
    }
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    final destination = await AdManager.instance.resolveDestination(
      widget.ad, widget.placementZone);
    if (!mounted) return;

    final uri = Uri.tryParse(destination.trim());
    if (destination.trim().isEmpty || uri == null) return;
    // canLaunchUrl is advisory and answers false whenever package visibility
    // hides the handler; try the launch and fall back to the in-app browser.
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      debugPrint('[VideoAd] could not open destination: $e');
    }
  }

  void _toggleMute() {
    if (_playbackController != null && _isInitialized) {
      _playbackController!.setMuted(!_playbackController!.value.isMuted);
      setState(() {});
    }
  }

  Widget _muteButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          key: const Key('video_ad_mute'),
          onTap: _toggleMute,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Icon(
              _playbackController!.value.isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// The playing video over the whole page. Close to the page's ratio it
  /// fills it (trimming at most a sliver); far from it, it is shown whole
  /// over a blurred copy of the poster, so nothing important is cut off.
  Widget _fullScreenVideo(NetworkVideoPlaybackController controller) {
    return LayoutBuilder(builder: (context, c) {
      final pageRatio = c.maxHeight > 0 && c.maxWidth.isFinite
          ? c.maxWidth / c.maxHeight
          : 0.0;
      final fill =
          FullScreenAdImage.videoFills(controller.value.aspectRatio, pageRatio);
      final video = IgnorePointer(
        child: VideoPlayerWidget(
          key: Key(fill ? 'video_ad_fill' : 'video_ad_whole'),
          controller: controller,
          fit: fill ? BoxFit.cover : BoxFit.contain,
          showControls: false,
        ),
      );
      if (fill || widget.ad.imageUrl.isEmpty) return video;
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: CachedNetworkImage(
                imageUrl: widget.ad.imageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.5),
                colorBlendMode: BlendMode.darken,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          video,
        ],
      );
    });
  }

  Widget _fullScreenDetails(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final host = Uri.tryParse(widget.ad.destinationUrl.trim())?.host ?? '';
    final title = widget.ad.title.trim();
    return Container(
      key: const Key('video_ad_details'),
      padding: EdgeInsets.fromLTRB(16, 56, 16, bottom + 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            host.isNotEmpty ? 'Sponsored · $host' : 'Sponsored',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.ad.destinationUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('video_ad_cta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleTap,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Learn More',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullScreen(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final controller = _playbackController;
    final playing = _isInitialized && controller != null && !_videoFailed;
    return AdViewabilityDetector(
      ad: widget.ad,
      playback: controller,
      placementZone: widget.placementZone,
      exposureKey: widget.exposureKey,
      child: VisibilityDetector(
        key: _visibilityKey,
        onVisibilityChanged: _onVisibilityChanged,
        child: GestureDetector(
          key: const Key('video_ad_full_screen'),
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (playing)
                  _fullScreenVideo(controller)
                // The poster, by the same fill rule, until the video plays.
                else if (widget.ad.imageUrl.isNotEmpty)
                  FullScreenAdImage(imageUrl: widget.ad.imageUrl)
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                if (widget.showDetails)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _fullScreenDetails(context),
                  ),
                if (playing && _completed) _replayButton(),
                // Under the host's Skip / Close row at the top right.
                if (playing)
                  Positioned(top: top + 64, right: 16, child: _muteButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) return _buildFullScreen(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdViewabilityDetector(
      ad: widget.ad,
      playback: _playbackController,
      placementZone: widget.placementZone,
      exposureKey: widget.exposureKey,
      child: VisibilityDetector(
        key: _visibilityKey,
        onVisibilityChanged: _onVisibilityChanged,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: _handleTap,
            splashColor: AppColors.primary.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Media Frame (Video Player or Poster)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video Player Surface or Poster Image
                      if (_isInitialized && _playbackController != null)
                        VideoPlayerWidget(
                          controller: _playbackController!,
                          showControls: false,
                        )
                      else
                        CachedNetworkImage(
                          imageUrl: widget.ad.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDark ? Colors.white10 : AppColors.chipBg,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? Colors.white10 : AppColors.chipBg,
                            child: const Center(
                              child: Icon(Icons.campaign_rounded,
                                  size: 48, color: AppColors.textMuted),
                            ),
                          ),
                        ),

                      if (_isInitialized &&
                          _playbackController != null &&
                          _completed)
                        _replayButton(),

                      // Bottom gradient overlay
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.35),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Top-Left "Sponsored" Badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white24, width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_rounded,
                                      color: Colors.amber, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'SPONSORED VIDEO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Top-Right Actions: Mute button & Share button
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isInitialized &&
                                _playbackController != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: InkWell(
                                    onTap: _toggleMute,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white24, width: 0.8),
                                      ),
                                      child: Icon(
                                        _playbackController!.value.isMuted
                                            ? Icons.volume_off_rounded
                                            : Icons.volume_up_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Card Body & Call To Action
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ad.title.isNotEmpty
                            ? widget.ad.title
                            : 'Sponsored Promotion',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textDark,
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.ad.destinationUrl.isNotEmpty
                            ? 'Sponsored · ${Uri.tryParse(widget.ad.destinationUrl)?.host ?? widget.ad.destinationUrl}'
                            : 'Sponsored Partner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _handleTap,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Learn More',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, size: 15),
                                ],
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
}
