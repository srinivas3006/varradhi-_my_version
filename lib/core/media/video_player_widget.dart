import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'network_video_playback_controller.dart';
import 'video_playback_controller.dart';
import 'youtube_playback_controller.dart';

/// Production-ready Video Player Widget providing:
/// - Thumbnail-first rendering (never shows a blank black rectangle)
/// - Unified rendering of YouTube and native video
/// - Graceful loading, buffering, and single-item retry on failure
/// - Seamless gesture pass-through and fallback to external YouTube app
class VideoPlayerWidget extends StatelessWidget {
  final VideoPlaybackController controller;
  final BoxFit fit;
  final bool showControls;
  final VoidCallback? onRetry;

  const VideoPlayerWidget({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
    this.showControls = false,
    this.onRetry,
  });

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
      valueListenable: controller,
      builder: (context, state, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Thumbnail Layer (Always present under player as instant baseline)
            if (controller.source.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: controller.source.thumbnailUrl,
                fit: fit,
                placeholder: (_, __) => Container(color: Colors.black),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 48),
                  ),
                ),
              )
            else
              Container(color: Colors.black),

            // 2. Player Layer (Visible once initialized)
            if (state.isInitialized)
              _buildActivePlayerSurface(context, state),

            // 3. Loading / Initializing Indicator
            if (state.status == PlaybackStatus.initializing || state.status == PlaybackStatus.idle)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),

            // 4. Buffering Indicator
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

            // 5. Error State Overlay with Single-Item Retry & "Watch on YouTube"
            if (state.isError)
              Container(
                color: Colors.black.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 44),
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
                          ElevatedButton.icon(
                            onPressed: onRetry ?? () => controller.initialize(),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('మళ్ళీ ప్రయత్నించండి'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          if (controller.source.isYouTube)
                            ElevatedButton.icon(
                              onPressed: () => _openYouTubeExternal(controller),
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text('యూట్యూబ్‌లో చూడండి'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF0000),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActivePlayerSurface(BuildContext context, VideoPlaybackState state) {
    if (controller is YouTubePlaybackController) {
      final ytCtrl = (controller as YouTubePlaybackController).rawController;
      if (ytCtrl != null) {
        return Center(
          child: AspectRatio(
            aspectRatio: controller.source.isShort ? 9 / 16 : 16 / 9,
            child: YoutubePlayer(
              controller: ytCtrl,
              aspectRatio: controller.source.isShort ? 9 / 16 : 16 / 9,
            ),
          ),
        );
      }
    } else if (controller is NetworkVideoPlaybackController) {
      final nativeCtrl = (controller as NetworkVideoPlaybackController).rawController;
      if (nativeCtrl != null && nativeCtrl.value.isInitialized) {
        return FittedBox(
          fit: fit,
          child: SizedBox(
            width: nativeCtrl.value.size.width > 0 ? nativeCtrl.value.size.width : 16,
            height: nativeCtrl.value.size.height > 0 ? nativeCtrl.value.size.height : 9,
            child: VideoPlayer(nativeCtrl),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }
}
