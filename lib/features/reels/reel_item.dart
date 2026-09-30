import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'reel_model.dart';

/// A stalled video shows Retry after this long (handover: ~10–15 s).
const kReelBufferTimeout = Duration(seconds: 12);

/// Zooms the YouTube frame slightly so YouTube's own title bar and "Shorts"
/// watermark fall off-screen. 1.0 = no crop.
const double kYoutubeCropZoom = 1.12;

/// One full-screen reel: the media, its title and channel, and the mute and
/// share buttons. Vertical drags always reach the pager.
class ReelItem extends StatelessWidget {
  const ReelItem({
    super.key,
    required this.reel,
    required this.isActive,
    required this.isMuted,
    required this.onToggleMute,
    required this.onShare,
  });

  final Reel reel;
  final bool isActive;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final media = switch (reel.mediaType) {
      ReelMediaType.native => NativeReelPlayer(
          url: reel.videoUrl,
          thumbnailUrl: reel.thumbnailUrl,
          isActive: isActive,
          isMuted: isMuted,
        ),
      ReelMediaType.youtube => YoutubeReelPlayer(
          videoId: reel.youtubeId!,
          thumbnailUrl: reel.thumbnailUrl,
          isActive: isActive,
          isMuted: isMuted,
        ),
      ReelMediaType.unavailable =>
        ReelUnavailable(thumbnailUrl: reel.thumbnailUrl),
    };
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          media,
          IgnorePointer(child: _InfoOverlay(reel: reel)),
          Positioned(
            right: 10,
            bottom: 110 + bottomInset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundButton(
                  key: const Key('reel_mute'),
                  icon: isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: isMuted ? 'శబ్దం ఆన్ చేయండి' : 'మ్యూట్ చేయండి',
                  onTap: onToggleMute,
                ),
                const SizedBox(height: 18),
                _RoundButton(
                  key: const Key('reel_share'),
                  icon: Icons.share_rounded,
                  label: 'షేర్ చేయండి',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared tap / spinner / retry / play-pause flash
// ---------------------------------------------------------------------------
mixin _PlayerChrome<T extends StatefulWidget> on State<T> {
  Timer? _bufferTimer;
  Timer? _flashTimer;
  bool timedOut = false;
  bool _showFlash = false;
  bool _flashPlaying = false;

  void startBufferWatch() {
    _bufferTimer?.cancel();
    _bufferTimer = Timer(kReelBufferTimeout, () {
      if (mounted) setState(() => timedOut = true);
    });
  }

  void stopBufferWatch() {
    _bufferTimer?.cancel();
    if (timedOut && mounted) setState(() => timedOut = false);
  }

  void flash(bool nowPlaying) {
    _flashTimer?.cancel();
    setState(() {
      _flashPlaying = nowPlaying;
      _showFlash = true;
    });
    _flashTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showFlash = false);
    });
  }

  Widget chrome({
    required VoidCallback onTap,
    required bool loading,
    required VoidCallback onRetry,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Claims taps only; vertical drags pass through to the pager.
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
        if (loading && !timedOut)
          const Center(
            child: SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
          ),
        if (timedOut)
          Center(
            child: FilledButton.icon(
              key: const Key('reel_retry'),
              style: FilledButton.styleFrom(backgroundColor: Colors.white24),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('మళ్ళీ ప్రయత్నించండి'),
            ),
          ),
        IgnorePointer(
          child: Center(
            child: AnimatedOpacity(
              opacity: _showFlash ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                child: Icon(
                  _flashPlaying
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void disposeChrome() {
    _bufferTimer?.cancel();
    _flashTimer?.cancel();
  }
}

// ---------------------------------------------------------------------------
// YouTube: full screen, no YouTube controls, never takes the swipe
// ---------------------------------------------------------------------------
class YoutubeReelPlayer extends StatefulWidget {
  const YoutubeReelPlayer({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    required this.isActive,
    required this.isMuted,
  });

  final String videoId;
  final String thumbnailUrl;
  final bool isActive;
  final bool isMuted;

  @override
  State<YoutubeReelPlayer> createState() => _YoutubeReelPlayerState();
}

class _YoutubeReelPlayerState extends State<YoutubeReelPlayer>
    with _PlayerChrome<YoutubeReelPlayer> {
  late final YoutubePlayerController _c;
  StreamSubscription<YoutubePlayerValue>? _sub;
  PlayerState _state = PlayerState.unknown;
  bool _started = false; // first real frame shown
  bool _loading = true;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    _c = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: widget.isActive,
      params: YoutubePlayerParams(
        mute: widget.isMuted,
        showControls: false,
        showFullscreenButton: false,
        showVideoAnnotations: false,
        enableCaption: false,
        playsInline: true,
        loop: false, // looped by hand on "ended"
        strictRelatedVideos: true,
        enableKeyboard: false,
        pointerEvents: PointerEvents.none, // the frame ignores touches
      ),
    );
    _sub = _c.listen(_onValue);
    if (widget.isActive) startBufferWatch();
  }

  void _onValue(YoutubePlayerValue v) {
    if (!mounted) return;
    if (v.error != YoutubeError.none) {
      _bufferTimer?.cancel();
      setState(() {
        _loading = false;
        timedOut = true;
      });
      return;
    }
    _state = v.playerState;
    switch (v.playerState) {
      case PlayerState.playing:
        if (!widget.isActive) {
          _c.pauseVideo(); // a neighbour must never play
          return;
        }
        stopBufferWatch();
        setState(() {
          _started = true;
          _loading = false;
        });
      case PlayerState.buffering:
        if (widget.isActive) {
          setState(() => _loading = true);
          startBufferWatch();
        }
      case PlayerState.ended:
        if (widget.isActive) {
          _c.seekTo(seconds: 0, allowSeekAhead: true);
          _c.playVideo();
        }
      case PlayerState.cued:
        if (widget.isActive && !_userPaused) _c.playVideo();
      default:
        break;
    }
  }

  @override
  void didUpdateWidget(YoutubeReelPlayer old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) {
      if (widget.isActive) {
        _userPaused = false;
        _c.playVideo();
        if (_state != PlayerState.playing) {
          setState(() => _loading = true);
          startBufferWatch();
        }
      } else {
        _c.pauseVideo();
        stopBufferWatch();
      }
    }
    if (old.isMuted != widget.isMuted) {
      widget.isMuted ? _c.mute() : _c.unMute();
    }
  }

  void _togglePlay() {
    if (_state == PlayerState.playing) {
      _userPaused = true;
      _c.pauseVideo();
      flash(false);
    } else {
      _userPaused = false;
      _c.playVideo();
      flash(true);
    }
  }

  void _retry() {
    _bufferTimer?.cancel();
    setState(() {
      timedOut = false;
      _loading = true;
    });
    _c.loadVideoById(videoId: widget.videoId);
    startBufferWatch();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c.close();
    disposeChrome();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverBox(
          aspectRatio: 9 / 16,
          zoom: kYoutubeCropZoom,
          child: IgnorePointer(
            child: YoutubePlayer(
              controller: _c,
              aspectRatio: 9 / 16,
              backgroundColor: Colors.black,
              // A vertical drag is the swipe to the next reel, never a
              // request for YouTube's fullscreen.
              enableFullScreenOnVerticalDrag: false,
              autoFullScreen: false,
            ),
          ),
        ),
        // The thumbnail hides YouTube's splash until the first real frame.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _started ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: ReelThumbnail(url: widget.thumbnailUrl),
          ),
        ),
        chrome(
          onTap: _togglePlay,
          loading: widget.isActive && _loading,
          onRetry: _retry,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Uploaded (native) video
// ---------------------------------------------------------------------------
class NativeReelPlayer extends StatefulWidget {
  const NativeReelPlayer({
    super.key,
    required this.url,
    required this.thumbnailUrl,
    required this.isActive,
    required this.isMuted,
  });

  final String url;
  final String thumbnailUrl;
  final bool isActive;
  final bool isMuted;

  @override
  State<NativeReelPlayer> createState() => _NativeReelPlayerState();
}

class _NativeReelPlayerState extends State<NativeReelPlayer>
    with _PlayerChrome<NativeReelPlayer> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    startBufferWatch();
    try {
      await c.initialize();
    } catch (_) {
      if (mounted && _c == c) {
        _bufferTimer?.cancel();
        setState(() {
          _loading = false;
          timedOut = true;
        });
      }
      return;
    }
    if (!mounted || _c != c) {
      c.dispose();
      return;
    }
    await c.setLooping(true); // shorts loop
    await c.setVolume(widget.isMuted ? 0 : 1);
    c.addListener(_onTick);
    stopBufferWatch();
    setState(() {
      _ready = true;
      _loading = false;
    });
    if (widget.isActive) c.play();
  }

  void _onTick() {
    final v = _c!.value;
    if (v.hasError && !timedOut) {
      _bufferTimer?.cancel();
      setState(() => timedOut = true);
      return;
    }
    final buffering = widget.isActive && v.isBuffering;
    if (buffering != _loading) {
      setState(() => _loading = buffering);
      buffering ? startBufferWatch() : stopBufferWatch();
    }
  }

  @override
  void didUpdateWidget(NativeReelPlayer old) {
    super.didUpdateWidget(old);
    final c = _c;
    if (c == null || !_ready) return;
    if (old.isActive != widget.isActive) {
      widget.isActive ? c.play() : c.pause();
    }
    if (old.isMuted != widget.isMuted) c.setVolume(widget.isMuted ? 0 : 1);
  }

  void _togglePlay() {
    final c = _c;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      c.pause();
      flash(false);
    } else {
      c.play();
      flash(true);
    }
  }

  void _retry() {
    _c?.removeListener(_onTick);
    _c?.dispose();
    setState(() {
      _ready = false;
      _loading = true;
      timedOut = false;
    });
    _init();
  }

  @override
  void dispose() {
    _c?.removeListener(_onTick);
    _c?.dispose();
    disposeChrome();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Stack(
      fit: StackFit.expand,
      children: [
        ReelThumbnail(url: widget.thumbnailUrl),
        if (_ready && c != null)
          // The last frame stays on screen while it rebuffers.
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          ),
        chrome(
          onTap: _togglePlay,
          loading: widget.isActive && _loading,
          onRetry: _retry,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sizes [child] to [aspectRatio] so it covers the whole screen (like
/// BoxFit.cover) without transforms, so a platform view (the WebView) stays
/// sharp and correctly placed.
class CoverBox extends StatelessWidget {
  const CoverBox(
      {super.key, required this.aspectRatio, required this.child, this.zoom = 1.0});

  final double aspectRatio; // width / height
  final double zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      double cw, ch;
      if (w / h > aspectRatio) {
        cw = w;
        ch = w / aspectRatio;
      } else {
        ch = h;
        cw = h * aspectRatio;
      }
      cw *= zoom;
      ch *= zoom;
      return ClipRect(
        child: OverflowBox(
          minWidth: cw,
          maxWidth: cw,
          minHeight: ch,
          maxHeight: ch,
          alignment: Alignment.center,
          child: SizedBox(width: cw, height: ch, child: child),
        ),
      );
    });
  }
}

class ReelThumbnail extends StatelessWidget {
  const ReelThumbnail({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const ColoredBox(color: Colors.black);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) => const ColoredBox(color: Colors.black),
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
    );
  }
}

class ReelUnavailable extends StatelessWidget {
  const ReelUnavailable({super.key, required this.thumbnailUrl});
  final String thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ReelThumbnail(url: thumbnailUrl),
        const ColoredBox(color: Colors.black54),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 44),
              SizedBox(height: 10),
              Text('వీడియో అందుబాటులో లేదు',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoOverlay extends StatelessWidget {
  const _InfoOverlay({required this.reel});
  final Reel reel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        // Clear of the system gesture area, and of the side buttons.
        padding: EdgeInsets.fromLTRB(
            16, 60, 76, 24 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reel.isLive || reel.isBreaking)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  reel.isLive ? 'LIVE' : 'BREAKING',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            if (reel.channelName.isNotEmpty)
              Text(reel.channelName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              reel.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
