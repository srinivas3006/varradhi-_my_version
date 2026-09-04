import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Small self-contained video preview — no shared video-preview widget
/// exists elsewhere in the app without refactor risk, so this is built
/// fresh for the admin console only.
class AdminVideoPreview extends StatefulWidget {
  final String videoUrl;
  const AdminVideoPreview({super.key, required this.videoUrl});

  @override
  State<AdminVideoPreview> createState() => _AdminVideoPreviewState();
}

class _AdminVideoPreviewState extends State<AdminVideoPreview> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio == 0 ? 16 / 9 : _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
            });
          },
          child: AnimatedOpacity(
            opacity: _controller!.value.isPlaying ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
          ),
        ),
      ],
    );
  }
}
