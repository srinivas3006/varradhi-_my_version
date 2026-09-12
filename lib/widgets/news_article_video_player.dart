import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/media/media_resolver.dart';
import '../core/media/media_source.dart';
import '../core/media/video_playback_controller.dart';
import '../core/media/video_player_widget.dart';
import '../models/news_article.dart';
import '../screens/video_player_screen.dart';
import '../theme/app_theme.dart';

/// Interactive video player widget for news articles.
/// Displays an authentic YouTube-style play button over the thumbnail.
/// When the user taps the video button, it smoothly loads and plays
/// the YouTube or direct MP4 video in-place ("like a YouTube thing").
class NewsArticleVideoPlayer extends StatefulWidget {
  final NewsArticle article;
  final bool isCurrent;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onDoubleTap;
  final bool allowFullscreen;

  const NewsArticleVideoPlayer({
    super.key,
    required this.article,
    this.isCurrent = true,
    this.height,
    this.fit = BoxFit.cover,
    this.onDoubleTap,
    this.allowFullscreen = true,
  });

  @override
  State<NewsArticleVideoPlayer> createState() => _NewsArticleVideoPlayerState();
}

class _NewsArticleVideoPlayerState extends State<NewsArticleVideoPlayer> {
  bool _isPlaying = false;
  MediaSource? _mediaSource;
  VideoPlaybackController? _playbackController;

  @override
  void initState() {
    super.initState();
    _resolveMediaSource();
  }

  void _resolveMediaSource() {
    final previewUrl = widget.article.imageUrl.isNotEmpty
        ? widget.article.imageUrl
        : (widget.article.imageUrls != null && widget.article.imageUrls!.isNotEmpty
            ? widget.article.imageUrls!.first
            : '');

    _mediaSource = MediaResolver.resolve(
      videoUrl: widget.article.videoUrl,
      thumbnailUrl: previewUrl,
      isVideoFlag: widget.article.isVideo,
    );
  }

  void _startPlayback() async {
    HapticFeedback.mediumImpact();
    if (_mediaSource == null || !_mediaSource!.isPlayable) return;

    setState(() {
      _isPlaying = true;
    });

    _playbackController?.dispose();
    final ctrl = VideoPlaybackController.fromSource(_mediaSource!);
    _playbackController = ctrl;

    try {
      await ctrl.initialize();
      if (mounted && _isPlaying) {
        ctrl.play();
        setState(() {});
      }
    } catch (e) {
      debugPrint('[NewsArticleVideoPlayer] Playback init error: $e');
    }
  }

  void _stopPlayback() {
    setState(() {
      _isPlaying = false;
    });
    _playbackController?.pause();
    _playbackController?.dispose();
    _playbackController = null;
  }

  @override
  void didUpdateWidget(covariant NewsArticleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-pause if the card is swiped away in Spotlight
    if (oldWidget.isCurrent && !widget.isCurrent && _isPlaying) {
      _playbackController?.pause();
    }

    if (oldWidget.article.videoUrl != widget.article.videoUrl) {
      _stopPlayback();
      _resolveMediaSource();
    }
  }

  @override
  void dispose() {
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
          videoUrl: widget.article.videoUrl,
          title: widget.article.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final previewUrl = article.imageUrl.isNotEmpty
        ? article.imageUrl
        : (article.imageUrls != null && article.imageUrls!.isNotEmpty
            ? article.imageUrls!.first
            : '');

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
                        child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
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
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
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
                child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
              ),
            )
          else
            Container(color: Colors.black),

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

          // YouTube Style Signature Play Button
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startPlayback,
                borderRadius: BorderRadius.circular(18),
                splashColor: Colors.white24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000), // Iconic YouTube red
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Watch Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
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
                    const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 12),
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
