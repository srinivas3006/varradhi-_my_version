import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'network_video_playback_controller.dart';
import 'video_playback_controller.dart';
import 'youtube_playback_controller.dart';

/// Production-ready Video Player Widget providing:
/// - Thumbnail-first rendering (never shows a blank black rectangle)
/// - Unified rendering of YouTube and native video
/// - Graceful loading, buffering, and single-item retry on failure
/// - Seamless gesture pass-through
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

            // 5. Error State Overlay with Single-Item Retry
            if (state.isError)
              Container(
                color: Colors.black.withValues(alpha: 0.75),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage ?? 'వీడియో అందుబాటులో లేదు',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: onRetry ?? () => controller.initialize(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('మళ్ళీ ప్రయత్నించండి'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF2300),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
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
        return FittedBox(
          fit: fit,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width * (16 / 9),
            child: IgnorePointer(
              ignoring: !showControls,
              child: YoutubePlayer(
                controller: ytCtrl,
                aspectRatio: controller.source.isShort ? 9 / 16 : 16 / 9,
              ),
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
