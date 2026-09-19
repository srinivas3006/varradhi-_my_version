import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/media/media_resolver.dart';
import '../core/media/media_source.dart';
import '../core/media/video_playback_controller.dart';
import '../core/media/video_player_widget.dart';
import '../core/utils/url_normalizer.dart';
import '../models/news_article.dart';
import '../screens/video_player_screen.dart';
import '../theme/app_theme.dart';

import '../spotlight/spotlight_media_coordinator.dart';

/// Interactive video player widget for news articles.
/// Displays an authentic YouTube-style play button over the thumbnail.
/// When the user taps the video button, it smoothly loads and plays
/// the YouTube or direct MP4 video in-place ("like a YouTube thing").
class NewsArticleVideoPlayer extends StatefulWidget {
  final NewsArticle article;
  final MediaItem? media;
  final bool isCurrent;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onDoubleTap;
  final bool allowFullscreen;

  const NewsArticleVideoPlayer({
    super.key,
    required this.article,
    this.media,
    this.isCurrent = true,
    this.height,
    this.fit = BoxFit.cover,
    this.onDoubleTap,
    this.allowFullscreen = true,
  });

  @override
  State<NewsArticleVideoPlayer> createState() => _NewsArticleVideoPlayerState();
}

class _NewsArticleVideoPlayerState extends State<NewsArticleVideoPlayer>
    with WidgetsBindingObserver {
  bool _isPlaying = false;
  MediaSource? _mediaSource;
  VideoPlaybackController? _playbackController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolveMediaSource();
    SpotlightMediaCoordinator.instance.addListener(_onMediaCoordinatorChanged);
  }

  void _onMediaCoordinatorChanged() {
    if (_isPlaying &&
        SpotlightMediaCoordinator.instance.activeVideoArticleId !=
            widget.article.id) {
      _stopPlayback();
    }
  }

  String _resolvePreviewUrl() {
    // 1. Explicit media item thumbnail if present
    final mediaThumb = widget.media?.thumbnailUrl.trim() ?? '';
    if (mediaThumb.isNotEmpty) return mediaThumb;

    // 2. MediaSource resolved thumbnail (handles YouTube URLs / IDs automatically)
    final sourceThumb = _mediaSource?.thumbnailUrl.trim() ?? '';
    if (sourceThumb.isNotEmpty) return sourceThumb;

    // 3. YouTube extraction from media url or article video url
    final vidUrl = (widget.media?.url.trim().isNotEmpty == true)
        ? widget.media!.url.trim()
        : widget.article.effectiveVideoUrl.trim();
    final ytThumb = UrlNormalizer.extractYoutubeThumbnail(vidUrl);
    if (ytThumb != null && ytThumb.isNotEmpty) return ytThumb;

    final ytId = MediaResolver.extractYoutubeVideoId(vidUrl);
    if (ytId != null && ytId.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$ytId/hqdefault.jpg';
    }

    // 4. Primary article image URL
    if (widget.article.imageUrl.trim().isNotEmpty) {
      return widget.article.imageUrl.trim();
    }

    // 5. Any image URL in article.imageUrls
    if (widget.article.imageUrls != null &&
        widget.article.imageUrls!.isNotEmpty) {
      final firstValid = widget.article.imageUrls!.firstWhere(
        (u) => u.trim().isNotEmpty,
        orElse: () => '',
      );
      if (firstValid.isNotEmpty) return firstValid.trim();
    }

    // 6. Any mediaItem with a thumbnail or image in article.mediaItems
    for (final m in widget.article.mediaItems) {
      if (m.thumbnailUrl.trim().isNotEmpty) return m.thumbnailUrl.trim();
      if (!m.isVideo && m.url.trim().isNotEmpty) return m.url.trim();
    }
    return '';
  }

  void _resolveMediaSource() {
    final effectiveVid = (widget.media?.url.isNotEmpty == true)
        ? widget.media!.url
        : widget.article.effectiveVideoUrl;

    final previewUrl = _resolvePreviewUrl();

    _mediaSource = MediaResolver.resolve(
      videoUrl: effectiveVid,
      thumbnailUrl: previewUrl,
      isVideoFlag: true,
    );
  }

  void _startPlayback() async {
    HapticFeedback.mediumImpact();
    if (_mediaSource == null || !_mediaSource!.isPlayable) {
      _resolveMediaSource();
      if (_mediaSource == null || !_mediaSource!.isPlayable) return;
    }

    SpotlightMediaCoordinator.instance.notifyVideoStarted(widget.article.id);

    setState(() {
      _isPlaying = true;
    });

    _playbackController?.dispose();

    // autoPlay: true is safe here and is *not* feed autoplay — this method
    // only ever runs from an explicit tap, so no controller exists until the
    // reader asks for one.
    //
    // It also has to be true: play() cannot work at this point. The player
    // surface mounts on the next frame, after the setState above, so calling
    // playVideo() here hits a controller with nothing attached and the
    // command is dropped — which is why the first tap appeared to do nothing
    // and a second interaction was needed. autoPlay is honoured by the
    // player when it becomes ready, so the tap is never lost.
    final ctrl =
        VideoPlaybackController.fromSource(_mediaSource!, autoPlay: true);
    _playbackController = ctrl;

    try {
      await ctrl.initialize();
      // Rebuild so the player widget mounts with the ready controller. The
      // identity check drops a stale init whose video was swiped past while
      // it was still loading.
      if (mounted && _isPlaying && identical(ctrl, _playbackController)) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[NewsArticleVideoPlayer] Playback init error: $e');
    }
  }

  void _stopPlayback() {
    final controller = _playbackController;
    _playbackController = null;
    _isPlaying = false;
    SpotlightMediaCoordinator.instance.notifyVideoStopped(widget.article.id);
    controller?.pause();
    controller?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _isPlaying) _stopPlayback();
  }

  @override
  void didUpdateWidget(covariant NewsArticleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-stop and release hardware texture if the card is swiped away in Spotlight
    if (oldWidget.isCurrent && !widget.isCurrent && _isPlaying) {
      _stopPlayback();
    }

    final oldVid = oldWidget.media?.url ?? oldWidget.article.effectiveVideoUrl;
    final newVid = widget.media?.url ?? widget.article.effectiveVideoUrl;
    final oldThumb =
        oldWidget.media?.thumbnailUrl ?? oldWidget.article.imageUrl;
    final newThumb = widget.media?.thumbnailUrl ?? widget.article.imageUrl;
    if (oldVid != newVid || oldThumb != newThumb) {
      _stopPlayback();
      _resolveMediaSource();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SpotlightMediaCoordinator.instance
        .removeListener(_onMediaCoordinatorChanged);
    SpotlightMediaCoordinator.instance.notifyVideoStopped(widget.article.id);
    _playbackController?.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    HapticFeedback.lightImpact();
    _stopPlayback();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: (widget.media?.url ?? widget.article.videoUrl),
          title: widget.article.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = _resolvePreviewUrl();

    return Container(
      height: widget.height,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. VIDEO PLAYER (When playing)
          if (_isPlaying && _playbackController != null)
            _buildActivePlayer()
          else
            // 2. THUMBNAIL + YOUTUBE PLAY BUTTON (When idle)
            _buildThumbnailWithPlayButton(previewUrl),

          // 3. TOP ACTION BAR (When playing: Close & Fullscreen)
          if (_isPlaying)
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.allowFullscreen)
                    GestureDetector(
                      onTap: _openFullscreen,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fullscreen_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  GestureDetector(
                    onTap: _stopPlayback,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivePlayer() {
    return Center(
      child: VideoPlayerWidget(
        controller: _playbackController!,
        fit: widget.fit,
        showControls: true,
        onRetry: _startPlayback,
        onFullscreenToggle: widget.allowFullscreen ? _openFullscreen : null,
      ),
    );
  }

  Widget _buildThumbnailWithPlayButton(String previewUrl) {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      onTap: _startPlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          if (previewUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: previewUrl,
              fit: widget.fit,
              placeholder: (context, url) => Container(color: AppColors.chipBg),
              errorWidget: (context, url, error) => Container(
                color: AppColors.chipBg,
                child: const Icon(Icons.image_not_supported_outlined,
                    color: AppColors.textMuted),
              ),
            )
          else
            Container(
              color: AppColors.cardDark,
              child: const Center(
                child: Icon(Icons.videocam_outlined,
                    color: AppColors.textMuted, size: 48),
              ),
            ),

          // Vignette shading
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),

          // Simple White Play Button Symbol
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),

          // Duration Badge in bottom-left
          if (widget.article.formattedVideoDuration.isNotEmpty)
            Positioned(
              bottom: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_fill,
                        color: Colors.redAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      widget.article.formattedVideoDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
