import 'package:flutter/material.dart';

import '../core/media/media_resolver.dart';
import '../core/media/media_source.dart';
import '../core/media/video_playback_controller.dart';
import '../core/media/video_player_widget.dart';

/// Screen 12: VideoPlayerScreen
/// Fullscreen or standalone video player for news video or short.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? title;
  final String? thumbnailUrl;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.title,
    this.thumbnailUrl,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlaybackController? _controller;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() async {
    final MediaSource source = MediaResolver.resolve(
      videoUrl: widget.videoUrl,
      thumbnailUrl: widget.thumbnailUrl,
    );

    if (!source.isPlayable) return;

    // autoPlay at construction, not play() after setState: this screen is
    // only reached by an explicit tap, and the player surface does not exist
    // until the next frame — so a play() here is dropped for YouTube.
    final ctrl = VideoPlaybackController.fromSource(source, autoPlay: true);
    ctrl.setLooping(false);
    ctrl.setMuted(_isMuted);

    try {
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
      });
    } catch (e) {
      debugPrint('[VideoPlayerScreen] Playback init error: $e');
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    _controller!.togglePlayPause();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setMuted(_isMuted);
    });
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.title ?? 'Video Player',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleMute,
          ),
        ],
      ),
      body: Center(
        child: _controller != null
            ? GestureDetector(
                onTap: _togglePlayPause,
                child: VideoPlayerWidget(
                  controller: _controller!,
                  fit: BoxFit.contain,
                  showControls: true,
                  onRetry: _initPlayer,
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              ),
      ),
    );
  }
}
