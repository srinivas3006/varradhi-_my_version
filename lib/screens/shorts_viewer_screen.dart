import 'package:flutter/material.dart';

import '../core/media/media_source.dart';
import '../core/media/video_playback_controller.dart';
import '../core/media/video_player_widget.dart';
import '../core/widgets/flip_page_view.dart';
import '../models/video_item.dart';

/// Full-screen vertical Shorts feed: one 9:16 Short at a time, swipe up for
/// the next and down for the previous.
///
/// Built on [FlipPageView] — the same vertical pager Spotlight uses — and
/// [VideoPlayerWidget], rather than a second player implementation.
///
/// Only the visible Short holds a controller. Everything else is released, so
/// a long feed cannot accumulate players.
class ShortsViewerScreen extends StatefulWidget {
  const ShortsViewerScreen({
    super.key,
    required this.shorts,
    this.initialIndex = 0,
  });

  final List<VideoItem> shorts;
  final int initialIndex;

  @override
  State<ShortsViewerScreen> createState() => _ShortsViewerScreenState();
}

class _ShortsViewerScreenState extends State<ShortsViewerScreen> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);

  /// Controllers for the visible Short and its immediate neighbours only.
  final Map<int, VideoPlaybackController> _controllers = {};
  late int _current = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  MediaSource? _sourceFor(VideoItem item) {
    final ytId = item.youtubeVideoId;
    if (ytId != null && ytId.isNotEmpty) {
      return MediaSource.youtube(
        videoId: ytId,
        rawUrl: item.youtubeUrl,
        thumbnailUrl: item.thumbnailUrl,
        isShort: true,
      );
    }
    final url = item.videoUrl;
    if (url != null && url.isNotEmpty) {
      return MediaSource.networkVideo(
        videoUrl: url,
        thumbnailUrl: item.thumbnailUrl,
        isShort: true,
      );
    }
    return null;
  }

  /// Keeps a controller for [_current] only, releasing the rest.
  ///
  /// Bounded on purpose: preloading the whole feed would leave one player per
  /// Short alive, and only one can ever be heard at a time anyway.
  void _syncControllers() {
    for (final index in _controllers.keys.toList()) {
      if (index != _current) {
        _controllers.remove(index)?.dispose();
      }
    }

    if (_controllers.containsKey(_current)) return;
    if (_current < 0 || _current >= widget.shorts.length) return;

    final source = _sourceFor(widget.shorts[_current]);
    if (source == null) return;

    // autoPlay is correct here and is not feed autoplay: this screen is only
    // reached by an explicit tap, and the player honours autoPlay when it
    // becomes ready — a play() call would race the surface mounting.
    final controller =
        VideoPlaybackController.fromSource(source, autoPlay: true);
    _controllers[_current] = controller;
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object e) {
      debugPrint('[ShortsViewer] init failed for index $_current: $e');
    });
  }

  void _onPageChanged(int index) {
    if (index == _current) return;
    setState(() => _current = index);
    _syncControllers();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shorts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No shorts available',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlipPageView(
            controller: _pageController,
            itemCount: widget.shorts.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final short = widget.shorts[index];
              final controller = _controllers[index];

              return Center(
                child: AspectRatio(
                  // 9:16 — a Short is portrait, and letterboxing it into a
                  // landscape frame is what the regular player did.
                  aspectRatio: 9 / 16,
                  child: controller != null
                      ? VideoPlayerWidget(
                          controller: controller,
                          fit: BoxFit.cover,
                          showControls: true,
                        )
                      : _Placeholder(short: short),
                ),
              );
            },
          ),

          // Back returns to wherever the reader opened this from.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
            ),
          ),

          // Title of the Short currently on screen.
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Text(
                widget.shorts[_current].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail shown while a Short's player is still coming up.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.short});
  final VideoItem short;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (short.thumbnailUrl.isNotEmpty)
            Image.network(short.thumbnailUrl, fit: BoxFit.cover),
          const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
