import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/video_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final List<VideoItem> _videos = [];
  bool _isLoading = false;
  String? _nextCursor;
  bool _hasMore = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final response = await ApiService.instance.getVideoFeed(cursor: _nextCursor);

    if (!mounted) return;
    setState(() {
      final newVideos = response.data ?? [];
      _videos.addAll(newVideos);
      _nextCursor = response.nextCursor;
      _hasMore = _nextCursor != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _videos.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                if (index == _videos.length - 2) {
                  _loadMore();
                }
              },
              itemBuilder: (context, index) {
                return _TikTokVideoCard(
                  video: _videos[index],
                  isCurrent: index == _currentIndex,
                );
              },
            ),
    );
  }
}

class _TikTokVideoCard extends StatefulWidget {
  final VideoItem video;
  final bool isCurrent;

  const _TikTokVideoCard({required this.video, required this.isCurrent});

  @override
  State<_TikTokVideoCard> createState() => _TikTokVideoCardState();
}

class _TikTokVideoCardState extends State<_TikTokVideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    if (widget.video.videoUrl != null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl!))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _controller!.setLooping(true);
              if (widget.isCurrent) {
                _controller!.play();
              }
            });
          }
        });
    }
  }

  @override
  void didUpdateWidget(_TikTokVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _controller?.play();
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.video.id),
      onVisibilityChanged: (info) {
        if (info.visibleFraction == 0) {
          _controller?.pause();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player or Thumbnail
          if (_isInitialized && _controller != null)
            GestureDetector(
              onTap: () {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
                setState(() {});
              },
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            )
          else
            Image.network(
              widget.video.thumbnailUrl,
              fit: BoxFit.cover,
            ),
            
          // Play/Pause Overlay
          if (_isInitialized && _controller != null && !_controller!.value.isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white70, size: 80),
            ),

          // Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // Video Info
          Positioned(
            bottom: 20,
            left: 16,
            right: 80, // Space for right actions
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${widget.video.channel.replaceAll(' ', '')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Right Actions
          Positioned(
            bottom: 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAction(Icons.favorite, widget.video.likes.toString()),
                const SizedBox(height: 16),
                _buildAction(Icons.comment, '1.2k'),
                const SizedBox(height: 16),
                _buildAction(Icons.share, 'Share'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 35),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
