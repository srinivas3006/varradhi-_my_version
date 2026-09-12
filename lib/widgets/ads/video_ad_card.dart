import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/media/media_resolver.dart';
import '../../core/media/media_source.dart';
import '../../core/media/network_video_playback_controller.dart';
import '../../core/media/video_player_widget.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/share_service.dart';
import 'ad_viewability_detector.dart';

/// Production video ad card.
///
/// Features:
/// - Reuses STEP 3 media infrastructure ([MediaResolver], [NetworkVideoPlaybackController])
/// - Poster display while loading or when video is absent
/// - Auto-plays (muted) when >= 70% visible; pauses when scrolled out of view
/// - Registers active video with [AdManager] so interstitials are not triggered
/// - Properly disposes all video resources upon unmount
/// - Tracks viewability and clicks via [AdManager]
class VideoAdCard extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;

  const VideoAdCard({
    super.key,
    required this.ad,
    this.placementZone = 'feed',
    this.exposureKey,
  });

  @override
  State<VideoAdCard> createState() => _VideoAdCardState();
}

class _VideoAdCardState extends State<VideoAdCard> {
  NetworkVideoPlaybackController? _playbackController;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    if (widget.ad.videoUrl.isEmpty) return;

    final mediaSource = MediaResolver.resolve(
      videoUrl: widget.ad.videoUrl,
      thumbnailUrl: widget.ad.imageUrl,
    );

    if (mediaSource.type == MediaSourceType.networkVideo) {
      _playbackController = NetworkVideoPlaybackController(
        mediaSource,
        autoPlay: false,
        isMuted: true,
        loop: true,
      );

      _playbackController!.initialize().then((_) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isInitialized = true;
          });
          if (_isVisible) {
            _playbackController!.play();
            AdManager.instance.registerActiveVideo();
          }
        }
      }).catchError((_) {
        // Fallback to poster on failure
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_playbackController != null) {
      if (_playbackController!.value.isPlaying) {
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

      if (_playbackController != null && _isInitialized) {
        if (nowVisible) {
          _playbackController!.play();
          AdManager.instance.registerActiveVideo();
        } else {
          _playbackController!.pause();
          AdManager.instance.unregisterActiveVideo();
        }
      }
    }
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    AdManager.instance.recordClick(widget.ad, placementZone: widget.placementZone);

    if (widget.ad.destinationUrl.isNotEmpty) {
      final uri = Uri.tryParse(widget.ad.destinationUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _handleShare() {
    HapticFeedback.lightImpact();
    final shareText = widget.ad.destinationUrl.isNotEmpty
        ? '${widget.ad.title}\n${widget.ad.destinationUrl}'
        : widget.ad.title;
    ShareService.shareText(shareText);
  }

  void _toggleMute() {
    if (_playbackController != null && _isInitialized) {
      _playbackController!.setMuted(!_playbackController!.value.isMuted);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.placementZone,
      exposureKey: widget.exposureKey,
      child: VisibilityDetector(
        key: Key('video_ad_visibility_${widget.ad.id}_${widget.exposureKey ?? "0"}'),
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
                SizedBox(
                  height: 210,
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
                            if (_isInitialized && _playbackController != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: InkWell(
                                    onTap: _toggleMute,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: InkWell(
                                  onTap: _handleShare,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white24, width: 0.8),
                                    ),
                                    child: const Icon(Icons.share_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ),
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
                                padding: const EdgeInsets.symmetric(vertical: 10),
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
