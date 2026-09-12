import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'video_playback_controller.dart';

/// Concrete controller implementation for direct network videos (.mp4, .mov, etc.)
/// powered by Flutter's official `video_player` plugin.
class NetworkVideoPlaybackController extends VideoPlaybackController {
  final bool autoPlay;
  final bool loop;

  VideoPlayerController? _controller;
  bool _isDisposed = false;

  NetworkVideoPlaybackController(
    super.source, {
    this.autoPlay = false,
    super.isMuted,
    this.loop = true,
  });

  VideoPlayerController? get rawController => _controller;

  @override
  Future<void> initialize() async {
    if (_isDisposed) return;
    final urlStr = source.url;
    if (urlStr == null || urlStr.trim().isEmpty) {
      value = value.copyWith(
        status: PlaybackStatus.error,
        errorMessage: 'Invalid video URL',
      );
      return;
    }

    final uri = Uri.tryParse(urlStr.trim());
    if (uri == null) {
      value = value.copyWith(
        status: PlaybackStatus.error,
        errorMessage: 'Malformed video URI',
      );
      return;
    }

    value = value.copyWith(status: PlaybackStatus.initializing);

    try {
      final ctrl = VideoPlayerController.networkUrl(uri);
      _controller = ctrl;

      await ctrl.initialize();
      if (_isDisposed) {
        await ctrl.dispose();
        return;
      }

      await ctrl.setLooping(loop);
      await ctrl.setVolume(value.isMuted ? 0.0 : 1.0);

      ctrl.addListener(_onControllerUpdate);

      final initialRatio = ctrl.value.aspectRatio > 0 ? ctrl.value.aspectRatio : 16 / 9;

      value = value.copyWith(
        status: autoPlay ? PlaybackStatus.playing : PlaybackStatus.ready,
        duration: ctrl.value.duration,
        position: ctrl.value.position,
        aspectRatio: initialRatio,
      );

      if (autoPlay) {
        await ctrl.play();
      }
    } catch (e) {
      debugPrint('[NetworkVideoPlaybackController] Initialization error: $e');
      if (!_isDisposed) {
        value = value.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'వీడియో లోడ్ చేయడం విఫలమైంది',
        );
      }
    }
  }

  void _onControllerUpdate() {
    if (_isDisposed || _controller == null) return;
    final ctrlValue = _controller!.value;

    if (ctrlValue.hasError) {
      value = value.copyWith(
        status: PlaybackStatus.error,
        errorMessage: ctrlValue.errorDescription ?? 'వీడియో ప్లేబ్యాక్ లోపం',
      );
      return;
    }

    PlaybackStatus newStatus;
    if (ctrlValue.isBuffering) {
      newStatus = PlaybackStatus.buffering;
    } else if (ctrlValue.isPlaying) {
      newStatus = PlaybackStatus.playing;
    } else if (ctrlValue.isCompleted) {
      newStatus = PlaybackStatus.completed;
    } else {
      newStatus = PlaybackStatus.paused;
    }

    value = value.copyWith(
      status: newStatus,
      position: ctrlValue.position,
      duration: ctrlValue.duration,
      aspectRatio: ctrlValue.aspectRatio > 0 ? ctrlValue.aspectRatio : value.aspectRatio,
    );
  }

  @override
  Future<void> play() async {
    if (_isDisposed || _controller == null || !value.isInitialized) return;
    try {
      await _controller!.play();
      value = value.copyWith(status: PlaybackStatus.playing);
    } catch (e) {
      debugPrint('[NetworkVideoPlaybackController] play() error: $e');
    }
  }

  @override
  Future<void> pause() async {
    if (_isDisposed || _controller == null || !value.isInitialized) return;
    try {
      await _controller!.pause();
      value = value.copyWith(status: PlaybackStatus.paused);
    } catch (e) {
      debugPrint('[NetworkVideoPlaybackController] pause() error: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isDisposed || _controller == null || !value.isInitialized) return;
    try {
      await _controller!.seekTo(position);
      value = value.copyWith(position: position);
    } catch (e) {
      debugPrint('[NetworkVideoPlaybackController] seek() error: $e');
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (_isDisposed) return;
    value = value.copyWith(isMuted: muted);
    if (_controller != null && value.isInitialized) {
      try {
        await _controller!.setVolume(muted ? 0.0 : 1.0);
      } catch (e) {
        debugPrint('[NetworkVideoPlaybackController] setMuted() error: $e');
      }
    }
  }

  @override
  Future<void> setLooping(bool looping) async {
    if (_isDisposed || _controller == null) return;
    try {
      await _controller!.setLooping(looping);
    } catch (e) {
      debugPrint('[NetworkVideoPlaybackController] setLooping() error: $e');
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    value = value.copyWith(status: PlaybackStatus.disposed);
    super.dispose();
  }
}
