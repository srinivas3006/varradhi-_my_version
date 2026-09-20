import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'video_playback_controller.dart';

/// Concrete controller implementation for YouTube streams and Shorts
/// powered by `youtube_player_flutter`.
class YouTubePlaybackController extends VideoPlaybackController {
  final bool autoPlay;
  final bool loop;

  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _streamSubscription;
  bool _isDisposed = false;

  YouTubePlaybackController(
    super.source, {
    this.autoPlay = false,
    super.isMuted,
    this.loop = true,
  });

  YoutubePlayerController? get rawController => _controller;

  @override
  Future<void> initialize() async {
    if (_isDisposed) return;
    final videoId = source.youtubeVideoId;

    if (videoId == null || videoId.isEmpty) {
      value = value.copyWith(
        status: PlaybackStatus.error,
        errorMessage: 'Invalid YouTube Video ID',
      );
      return;
    }

    value = value.copyWith(status: PlaybackStatus.initializing);

    try {
      final ctrl = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: autoPlay,
        params: YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: value.isMuted,
          loop: loop,
          enableCaption: false,
          enableJavaScript: true,
          playsInline: true,
          // youtube-nocookie.com, and no explicit origin.
          //
          // This is 1aff663's fix, which a later merge reverted back to
          // privacyEnhancedMode: false plus origin: youtube.com. The package
          // uses `origin` as the WebView's baseUrl, and pinning it to
          // youtube.com while the page has no real web origin breaks the
          // iframe's postMessage handshake: the player loads, never reports
          // ready, and nothing plays.
          privacyEnhancedMode: true,
          strictRelatedVideos: false,
        ),
      );

      _controller = ctrl;
      _streamSubscription = ctrl.stream.listen(_onControllerUpdate);

      value = value.copyWith(
        status: autoPlay ? PlaybackStatus.playing : PlaybackStatus.ready,
        aspectRatio: source.isShort ? 9 / 16 : 16 / 9,
      );
    } catch (e) {
      debugPrint('[YouTubePlaybackController] Initialization error: $e');
      if (!_isDisposed) {
        value = value.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'యూట్యూబ్ వీడియో లోడ్ చేయడం విఫలమైంది',
        );
      }
    }
  }

  void _onControllerUpdate(YoutubePlayerValue ctrlValue) {
    if (_isDisposed) return;

    if (ctrlValue.hasError) {
      debugPrint('[YouTubePlaybackController] YouTube error: ${ctrlValue.error}');
      final isRestricted = ctrlValue.error == YoutubeError.notEmbeddable ||
          ctrlValue.error == YoutubeError.sameAsNotEmbeddable ||
          ctrlValue.error == YoutubeError.sameAsNotEmbeddable2;
      value = value.copyWith(
        status: PlaybackStatus.error,
        errorMessage: isRestricted
            ? 'ఈ వీడియో కాపీరైట్ పరిమితుల వల్ల యూట్యూబ్‌లో మాత్రమే చూడగలరు.'
            : 'యూట్యూబ్ వీడియో ప్లే చేయడం సాధ్యపడలేదు.',
      );
      return;
    }

    PlaybackStatus newStatus;
    switch (ctrlValue.playerState) {
      case PlayerState.playing:
        newStatus = PlaybackStatus.playing;
        break;
      case PlayerState.paused:
        newStatus = PlaybackStatus.paused;
        break;
      case PlayerState.buffering:
        newStatus = PlaybackStatus.buffering;
        break;
      case PlayerState.ended:
        newStatus = PlaybackStatus.completed;
        break;
      case PlayerState.cued:
        newStatus = PlaybackStatus.ready;
        break;
      default:
        newStatus = value.status;
    }

    value = value.copyWith(
      status: newStatus,
      duration: ctrlValue.metaData.duration,
    );
  }

  @override
  Future<void> play() async {
    if (_isDisposed || _controller == null) return;
    try {
      await _controller!.playVideo();
      value = value.copyWith(status: PlaybackStatus.playing);
    } catch (e) {
      debugPrint('[YouTubePlaybackController] play() error: $e');
    }
  }

  @override
  Future<void> pause() async {
    if (_isDisposed || _controller == null) return;
    try {
      await _controller!.pauseVideo();
      value = value.copyWith(status: PlaybackStatus.paused);
    } catch (e) {
      debugPrint('[YouTubePlaybackController] pause() error: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isDisposed || _controller == null) return;
    try {
      await _controller!.seekTo(seconds: position.inSeconds.toDouble(), allowSeekAhead: true);
      value = value.copyWith(position: position);
    } catch (e) {
      debugPrint('[YouTubePlaybackController] seek() error: $e');
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (_isDisposed || _controller == null) return;
    value = value.copyWith(isMuted: muted);
    try {
      if (muted) {
        await _controller!.mute();
      } else {
        await _controller!.unMute();
      }
    } catch (e) {
      debugPrint('[YouTubePlaybackController] setMuted() error: $e');
    }
  }

  @override
  Future<void> setLooping(bool looping) async {
    // Handled in initialization parameters by youtube_player_flutter
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _streamSubscription?.cancel();
    _controller?.close();
    _controller = null;
    value = value.copyWith(status: PlaybackStatus.disposed);
    super.dispose();
  }
}
