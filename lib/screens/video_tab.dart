import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/media/media_source.dart';
import '../core/media/video_playback_controller.dart';
import '../core/media/video_player_widget.dart';
import '../localization/app_translations.dart';
import '../models/video_item.dart';
import '../repositories/video_repository.dart';
import '../state/app_state.dart';

class VideoTab extends StatefulWidget {
  final bool isActive;
  const VideoTab({super.key, this.isActive = true});

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final List<VideoItem> _videos = [];
  bool _isLoading = true;
  String? _nextCursor;
  bool _hasMore = true;
  int _focusedIndex = 0;
  bool _isAppActive = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final isActive = state == AppLifecycleState.resumed;
    if (_isAppActive != isActive) {
      setState(() {
        _isAppActive = isActive;
      });
    }
  }

  Future<void> _refresh() async {
    VideoRepository.instance.clearCache();
    setState(() {
      _isLoading = true;
      _videos.clear();
      _nextCursor = null;
      _hasMore = true;
      _focusedIndex = 0;
    });
    await _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (!_hasMore && _videos.isNotEmpty) return;

    try {
      final List<VideoItem> fetched = [];
      String? nextCur;

      // 1. Fetch YouTube Shorts feed via VideoRepository
      try {
        final shortsResponse = await VideoRepository.instance.getShortsFeed(
          cursor: _nextCursor,
        );
        if (shortsResponse.data != null && shortsResponse.data!.isNotEmpty) {
          fetched.addAll(shortsResponse.data!);
          nextCur = shortsResponse.nextCursor;
        }
      } catch (e) {
        debugPrint('[VideoTab] Error fetching shorts feed: $e');
      }

      // 2. Also fetch regular video feed and merge
      try {
        final videoResponse = await VideoRepository.instance.getVideoFeed(
          cursor: nextCur ?? _nextCursor,
        );
        if (videoResponse.data != null && videoResponse.data!.isNotEmpty) {
          for (final item in videoResponse.data!) {
            if (!fetched.any((v) => v.id == item.id)) {
              fetched.add(item);
            }
          }
          nextCur ??= videoResponse.nextCursor;
        }
      } catch (e) {
        debugPrint('[VideoTab] Error fetching video feed: $e');
      }

      if (!mounted) return;

      setState(() {
        _videos.addAll(fetched);
        _nextCursor = nextCur;
        _hasMore = nextCur != null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedIndex = index;
    });
    if (index >= _videos.length - 3) {
      _loadVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _videos.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    if (_videos.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'No videos available right now',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your internet connection or try again',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        itemCount: _videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final isFocused = (index == _focusedIndex) && _isAppActive && widget.isActive;
          final isNext = index == _focusedIndex + 1;
          return VideoCardItem(
            key: ValueKey(_videos[index].id),
            video: _videos[index],
            isFocused: isFocused,
            isNext: isNext,
            isMuted: _isMuted,
            onToggleMute: () {
              setState(() => _isMuted = !_isMuted);
            },
          );
        },
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
  final VoidCallback onToggleMute;

  const VideoCardItem({
    super.key,
    required this.video,
    required this.isFocused,
    this.isNext = false,
    this.isMuted = false,
    required this.onToggleMute,
  });

  @override
  State<VideoCardItem> createState() => _VideoCardItemState();
}

class _VideoCardItemState extends State<VideoCardItem> with SingleTickerProviderStateMixin {
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
    if (source.type == MediaSourceType.unsupported || source.type == MediaSourceType.imageOnly) {
      return;
    }

    final ctrl = VideoPlaybackController.fromSource(source);
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

      if (widget.isFocused) {
        ctrl.play();
      }
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
    if (!AppState.instance.isLiked(widget.video.id)) {
      AppState.instance.toggleLike(widget.video.id);
    }

    setState(() => _showHeartAnimation = true);
    _heartAnimController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showHeartAnimation = false);
      });
    });
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    AppState.instance.toggleLike(widget.video.id);
  }

  void _shareVideo() {
    HapticFeedback.lightImpact();
    final link = widget.video.youtubeVideoId != null
        ? 'https://youtube.com/watch?v=${widget.video.youtubeVideoId}'
        : (widget.video.videoUrl ?? '');
    SharePlus.instance.share(
      ShareParams(text: 'Check out this news video on Vaaradhi: ${widget.video.title}\n$link'),
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
                  if (state.isInitialized && !state.isPlaying && !state.isBuffering) {
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
              bottom: 100, // Clears floating navbar
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
              bottom: 120,
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
          child: Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 56),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2.5),
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
                icon: widget.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                iconColor: widget.isMuted ? Colors.amberAccent : Colors.white,
                label: widget.isMuted ? 'Muted' : 'Sound',
                onTap: widget.onToggleMute,
              ),
              const SizedBox(height: 18),

              // Like Action
              _buildRailButton(
                icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
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
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                final comments = AppState.instance.getComments(widget.articleId);

                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.white70)),
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
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.text,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
