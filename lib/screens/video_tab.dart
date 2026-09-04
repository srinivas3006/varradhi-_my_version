import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_item.dart';
import '../services/api_service.dart';
import '../localization/app_translations.dart';
import '../state/app_state.dart';

class VideoTab extends StatefulWidget {
  const VideoTab({super.key});

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab> {
  final PageController _pageController = PageController();
  final List<VideoItem> _videos = [];
  bool _isLoading = true;
  String? _nextCursor;
  bool _hasMore = true;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (!_hasMore) return;

    try {
      final response = await ApiService.instance.getVideoFeed(cursor: _nextCursor);
      if (!mounted) return;

      setState(() {
        _videos.addAll(response.data ?? []);
        _nextCursor = response.nextCursor;
        _hasMore = response.nextCursor != null;
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        child: const Center(child: Text('No videos available', style: TextStyle(color: Colors.white))),
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
          final isFocused = index == _focusedIndex;
          final isNext = index == _focusedIndex + 1;
          return VideoCardItem(
            key: ValueKey(_videos[index].id),
            video: _videos[index],
            isFocused: isFocused,
            isNext: isNext,
          );
        },
      ),
    );
  }
}

/// Individual Vertical Short Card with Dual Engine & Glass Controls
class VideoCardItem extends StatefulWidget {
  final VideoItem video;
  final bool isFocused;
  final bool isNext;

  const VideoCardItem({
    super.key,
    required this.video,
    required this.isFocused,
    this.isNext = false,
  });

  @override
  State<VideoCardItem> createState() => _VideoCardItemState();
}

class _VideoCardItemState extends State<VideoCardItem> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _ytController;
  
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _isYoutube = false;

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
      _initializeVideo();
    }
  }

  void _disposeControllers() {
    _videoController?.dispose();
    _videoController = null;
    _ytController?.close();
    _ytController = null;
    _isInitialized = false;
  }

  Future<void> _initializeVideo() async {
    if (_isInitialized) return;
    final video = widget.video;
    
    if (video.youtubeVideoId != null && video.youtubeVideoId!.isNotEmpty) {
      _isYoutube = true;
      _ytController = YoutubePlayerController(
        params: const YoutubePlayerParams(
          showControls: false,
          mute: false,
          loop: true,
          showFullscreenButton: false,
        ),
      );
      
      if (mounted) {
        _ytController!.loadVideoById(videoId: video.youtubeVideoId!);
        setState(() {
          _isInitialized = true;
          _isPlaying = widget.isFocused;
        });
        if (!widget.isFocused) {
          _ytController!.pauseVideo();
        }
      }
    } else if (video.videoUrl != null && video.videoUrl!.isNotEmpty) {
      _isYoutube = false;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(video.videoUrl!));
      
      try {
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        if (mounted) {
          setState(() => _isInitialized = true);
          if (widget.isFocused) {
            _videoController!.play();
            _isPlaying = true;
          } else {
            _isPlaying = false;
          }
        }
      } catch (e) {
        debugPrint('Error initializing video: $e');
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && !_isInitialized) {
      _initializeVideo();
    } else if (!widget.isFocused && oldWidget.isFocused) {
      _disposeControllers();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    } else if (widget.isFocused && _isInitialized) {
      _videoController?.play();
      _ytController?.playVideo();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    _heartAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_isPlaying) {
        _videoController?.pause();
        _ytController?.pauseVideo();
        _isPlaying = false;
      } else {
        _videoController?.play();
        _ytController?.playVideo();
        _isPlaying = true;
      }
    });
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
    SharePlus.instance.share(ShareParams(text: 'Check out this news video on Vaaradhi: ${widget.video.title}\n$link'));
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
                child: _isInitialized
                    ? _buildPlayerLayer()
                    : (widget.video.thumbnailUrl.isNotEmpty
                        ? Image.network(widget.video.thumbnailUrl, fit: BoxFit.cover)
                        : const Center(child: CircularProgressIndicator(color: Colors.redAccent))),
              ),
            ),

            // 2. Center Play/Pause Overlay Indicator
            if (_isInitialized && !_isPlaying)
              Center(
                child: IgnorePointer( // Let taps pass through to the detector
                    child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
                  ),
                ),
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
                        child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
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

  Widget _buildPlayerLayer() {
    if (_isYoutube && _ytController != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * (16 / 9),
          // Ignore pointer is crucial here so YouTube's iframe doesn't swallow
          // the double-tap and single-tap gestures of our parent GestureDetector.
          child: IgnorePointer(
            child: YoutubePlayer(
              controller: _ytController!,
              aspectRatio: 9 / 16,
            ),
          ),
        ),
      );
    } else if (_videoController != null && _videoController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      );
    }
    return const SizedBox.shrink();
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
              // Like Action
              _buildRailButton(
                icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: isLiked ? Colors.redAccent : Colors.white,
                label: _formatCount(displayLikes),
                onTap: _toggleLike,
              ),
              const SizedBox(height: 20),

              // Comments Action
              _buildRailButton(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: Colors.white,
                label: tr('chat'), // Using localization
                onTap: _openCommentsBottomSheet,
              ),
              const SizedBox(height: 20),

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
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
       // Ideally trigger login sheet here, but for simplicity:
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to comment')));
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
                  return const Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.white70)));
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
