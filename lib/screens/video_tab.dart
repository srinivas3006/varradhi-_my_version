import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
  final List<VideoItem> _videos = [];
  bool _isLoading = true;
  String? _nextCursor;
  bool _hasMore = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (!_hasMore) return;
    
    final response = await ApiService.instance.getVideoFeed(cursor: _nextCursor);
    if (!mounted) return;
    
    setState(() {
      _videos.addAll(response.data ?? []);
      _nextCursor = response.nextCursor;
      _hasMore = _nextCursor != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    
    if (_videos.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(child: Text('No videos available', style: TextStyle(color: Colors.white))),
      );
    }

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: _videos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == _videos.length - 1) {
              _loadVideos();
            }
          },
          itemBuilder: (context, index) {
            final video = _videos[index];
            return _VideoCard(
              video: video,
              isActive: index == _currentIndex,
            );
          },
        ),
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  final VideoItem video;
  final bool isActive;

  const _VideoCard({required this.video, required this.isActive});

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _showPlayIcon = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.video.videoUrl != null && widget.video.videoUrl!.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl!));
      try {
        await _controller!.initialize();
        if (mounted && widget.isActive) {
          _controller!.setLooping(true);
          _controller!.play();
          setState(() => _isPlaying = true);
        } else {
          setState(() {}); // trigger rebuild to show first frame if inactive
        }
      } catch (e) {
        debugPrint('Error loading video: $e');
      }
    }
  }

  @override
  void didUpdateWidget(covariant _VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller?.play();
        _isPlaying = true;
      } else {
        _controller?.pause();
        _isPlaying = false;
        _showPlayIcon = false;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_controller == null) return;
    
    setState(() {
      if (_isPlaying) {
        _controller!.pause();
        _isPlaying = false;
        _showPlayIcon = true;
      } else {
        _controller!.play();
        _isPlaying = true;
        _showPlayIcon = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    
    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (video.thumbnailUrl.isNotEmpty)
            Image.network(video.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox()),
            
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          
          if (_showPlayIcon || (_controller != null && !_controller!.value.isInitialized))
            const Center(
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white70, size: 72),
            ),
            
          // Right action rail
          Positioned(
            right: 12,
            bottom: 110,
            child: AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, child) {
                final isLiked = AppState.instance.isLiked(video.id);
                return Column(
                  children: [
                    _railButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: _formatCount(video.likes + (isLiked ? 1 : 0)),
                      color: isLiked ? const Color(0xFFE8412B) : Colors.white,
                      onTap: () => AppState.instance.toggleLike(video.id),
                    ),
                    const SizedBox(height: 18),
                    _railButton(
                      icon: Icons.mode_comment_outlined,
                      label: tr('chat'),
                      color: Colors.white,
                      onTap: () {},
                    ),
                    const SizedBox(height: 18),
                    _railButton(
                      icon: Icons.share_outlined,
                      label: tr('share'),
                      color: Colors.white,
                      onTap: () {},
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Bottom title/meta
          Positioned(
            left: 16,
            right: 90,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.channel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${video.views} · ${video.duration}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _railButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
