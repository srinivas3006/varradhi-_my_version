import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../theme/app_theme.dart';
import 'network_video_playback_controller.dart';
import 'video_playback_controller.dart';
import 'youtube_playback_controller.dart';

/// Production-ready Video Player Widget providing:
/// - Full interactive play, pause, seek, and replay controls
/// - Thumbnail-first rendering (never shows a blank black rectangle)
/// - Seamless card fitting without distortion
/// - Auto-hiding control overlays and tap-to-toggle play/pause
class VideoPlayerWidget extends StatefulWidget {
  final VideoPlaybackController controller;
  final BoxFit fit;
  final bool showControls;
  final VoidCallback? onRetry;
  final VoidCallback? onFullscreenToggle;

  const VideoPlayerWidget({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
    this.showControls = false,
    this.onRetry,
    this.onFullscreenToggle,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _useInAppWebPlayer = false;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _startAutoHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _playInAppYouTube() {
    final videoId = widget.controller.source.youtubeVideoId;
    if (videoId == null || videoId.isEmpty) return;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(
        Uri.parse(
            'https://www.youtube.com/embed/$videoId?autoplay=1&playsinline=1&controls=1&rel=0&modestbranding=1&origin=https://www.youtube.com'),
      );

    setState(() {
      _useInAppWebPlayer = true;
      _webViewController = controller;
    });
  }

  void _startAutoHideTimer() {
    _hideTimer?.cancel();
    if (!widget.showControls) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _startAutoHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _handleTapPlayPause() {
    HapticFeedback.lightImpact();
    widget.controller.togglePlayPause();
    setState(() {
      _controlsVisible = true;
    });
    _startAutoHideTimer();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openYouTubeExternal(VideoPlaybackController controller) async {
    final videoId = controller.source.youtubeVideoId;
    final rawUrl = controller.source.url;
    final targetUrl = (rawUrl != null && rawUrl.isNotEmpty)
        ? rawUrl
        : (videoId != null ? 'https://www.youtube.com/watch?v=$videoId' : null);

    if (targetUrl == null) return;
    final uri = Uri.tryParse(targetUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('[VideoPlayerWidget] Could not launch external YouTube URL: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlaybackState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Poster frame, shown only until the player surface is up.
              //
              // It used to stay behind the player for the whole session as an
              // "ambient background". The player letterboxes inside a slot
              // that is not 16:9, so the thumbnail showed through those bands
              // while the video was playing — two pictures at once. Black
              // behind the player is what a letterbox should be.
              if (!state.isInitialized &&
                  widget.controller.source.thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: widget.controller.source.thumbnailUrl,
                  fit: widget.fit,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.videocam_rounded,
                          color: Colors.white24, size: 48),
                    ),
                  ),
                )
              else
                Container(color: Colors.black),

              // 2. Active Video Surface
              if (state.isInitialized)
                _buildActivePlayerSurface(context, state),

              // 3. Tap surface to toggle controls visibility
              if (state.isInitialized && widget.showControls)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControlsVisibility,
                  ),
                ),

              // 4. Center Play / Pause / Replay Button Overlay
              if (state.isInitialized &&
                  widget.showControls &&
                  (_controlsVisible || !state.isPlaying || state.isCompleted))
                Center(
                  child: AnimatedOpacity(
                    opacity: (_controlsVisible || !state.isPlaying) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: GestureDetector(
                      onTap: () {
                        if (state.isCompleted) {
                          widget.controller.seek(Duration.zero);
                          widget.controller.play();
                        } else {
                          _handleTapPlayPause();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          state.isCompleted
                              ? Icons.replay_rounded
                              : (state.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Bottom Control Bar (Timeline, Play/Pause, Mute)
              if (state.isInitialized &&
                  widget.showControls &&
                  _controlsVisible)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Scrubbable Progress Line
                        if (state.duration.inMilliseconds > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (details) {
                                  final box = context.findRenderObject() as RenderBox?;
                                  if (box != null && box.size.width > 0) {
                                    final progress = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                                    final targetMs = (progress * state.duration.inMilliseconds).toInt();
                                    widget.controller.seek(Duration(milliseconds: targetMs));
                                  }
                                },
                                child: LinearProgressIndicator(
                                  value: (state.position.inMilliseconds /
                                          state.duration.inMilliseconds)
                                      .clamp(0.0, 1.0),
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFF0000)),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                          ),

                        // Bottom Action Icons and Time Display
                        Row(
                          children: [
                            // Play/Pause icon button
                            GestureDetector(
                              onTap: _handleTapPlayPause,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  state.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Time: current / total
                            Text(
                              '${_formatDuration(state.position)} / ${_formatDuration(state.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const Spacer(),

                            // Mute/Unmute
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.controller.setMuted(!state.isMuted);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  state.isMuted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),

                            // Fullscreen Toggle (if provided)
                            if (widget.onFullscreenToggle != null)
                              GestureDetector(
                                onTap: widget.onFullscreenToggle,
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.fullscreen_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // 6. Loading / Initializing Indicator
              if (state.status == PlaybackStatus.initializing ||
                  state.status == PlaybackStatus.idle)
                const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),

              // 7. Buffering Indicator
              if (state.isBuffering)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // 8. Error State Overlay
              if (state.isError)
                Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.white70, size: 44),
                        const SizedBox(height: 10),
                        Text(
                          state.errorMessage ?? 'వీడియో అందుబాటులో లేదు',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            if (widget.controller.source.isYouTube) ...[
                              ElevatedButton.icon(
                                onPressed: _playInAppYouTube,
                                icon: const Icon(Icons.play_circle_fill_rounded,
                                    size: 18),
                                label: const Text('యాప్‌లోనే ప్లే చేయండి'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 9),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _openYouTubeExternal(widget.controller),
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 16),
                                label: const Text('యూట్యూబ్‌లో చూడండి'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF0000),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                            ElevatedButton.icon(
                              onPressed: widget.onRetry ??
                                  () {
                                    setState(() => _useInAppWebPlayer = false);
                                    widget.controller.initialize();
                                  },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('మళ్ళీ ప్రయత్నించండి'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivePlayerSurface(
      BuildContext context, VideoPlaybackState state) {
    final playerAspect =
        widget.controller.source.isShort ? 9 / 16 : 16 / 9;

    if (_useInAppWebPlayer && _webViewController != null) {
      // Clipped: a WebView sizes itself from its content and will paint
      // outside the slot otherwise.
      return ClipRect(
        child: Center(
          child: AspectRatio(
            aspectRatio: playerAspect,
            child: WebViewWidget(controller: _webViewController!),
          ),
        ),
      );
    }

    if (widget.controller is YouTubePlaybackController) {
      final ytCtrl =
          (widget.controller as YouTubePlaybackController).rawController;
      if (ytCtrl != null) {
        // One aspect authority, not two. YoutubePlayer applies its own
        // AspectRatio internally, so wrapping it in another let the inner one
        // compute a size the slot could not hold — the player spilled past
        // the media area and over the chrome above it.
        //
        // ClipRect is the backstop: whatever the embedded surface decides,
        // it cannot paint outside its box.
        return ClipRect(
          child: Center(
            child: YoutubePlayer(
              controller: ytCtrl,
              aspectRatio: playerAspect,
              // This card sits inside a vertical PageView. Fullscreen-on-
              // vertical-drag would compete with the feed's own swipe, so
              // the reader gets the explicit fullscreen button instead.
              enableFullScreenOnVerticalDrag: false,
              autoFullScreen: false,
            ),
          ),
        );
      }
    } else if (widget.controller is NetworkVideoPlaybackController) {
      final nativeCtrl =
          (widget.controller as NetworkVideoPlaybackController).rawController;
      if (nativeCtrl != null && nativeCtrl.value.isInitialized) {
        return Center(
          child: FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: nativeCtrl.value.size.width > 0
                  ? nativeCtrl.value.size.width
                  : 16,
              height: nativeCtrl.value.size.height > 0
                  ? nativeCtrl.value.size.height
                  : 9,
              child: VideoPlayer(nativeCtrl),
            ),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }
}
