import 'package:flutter/foundation.dart';
import 'media_source.dart';
import 'network_video_playback_controller.dart';
import 'youtube_playback_controller.dart';

/// Discrete, predictable video playback statuses.
enum PlaybackStatus {
  idle,
  initializing,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
  disposed,
}

/// Immutable state snapshot of video playback.
class VideoPlaybackState {
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool isMuted;
  final double volume;
  final bool isLooping;
  final double aspectRatio;
  final String? errorMessage;

  const VideoPlaybackState({
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isMuted = false,
    this.volume = 1.0,
    this.isLooping = false,
    this.aspectRatio = 16 / 9,
    this.errorMessage,
  });

  factory VideoPlaybackState.initial({bool isMuted = false, double aspectRatio = 16 / 9}) =>
      VideoPlaybackState(
        status: PlaybackStatus.idle,
        isMuted: isMuted,
        volume: isMuted ? 0.0 : 1.0,
        aspectRatio: aspectRatio,
      );

  bool get isInitialized =>
      status != PlaybackStatus.idle &&
      status != PlaybackStatus.initializing &&
      status != PlaybackStatus.error &&
      status != PlaybackStatus.disposed;

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isPaused => status == PlaybackStatus.paused;
  bool get isBuffering => status == PlaybackStatus.buffering;
  bool get isError => status == PlaybackStatus.error;
  bool get isDisposed => status == PlaybackStatus.disposed;
  bool get isCompleted => status == PlaybackStatus.completed;

  VideoPlaybackState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? isMuted,
    double? volume,
    bool? isLooping,
    double? aspectRatio,
    String? errorMessage,
  }) {
    return VideoPlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      isLooping: isLooping ?? this.isLooping,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Common abstraction over native VideoPlayer and YouTubePlayer.
/// Exposes uniform operations and state updates to UI widgets.
abstract class VideoPlaybackController extends ValueNotifier<VideoPlaybackState> {
  final MediaSource source;

  VideoPlaybackController(this.source, {bool isMuted = false, double aspectRatio = 16 / 9})
      : super(VideoPlaybackState.initial(isMuted: isMuted, aspectRatio: aspectRatio));

  /// Factory resolving and instantiating the appropriate concrete controller.
  factory VideoPlaybackController.fromSource(
    MediaSource source, {
    bool autoPlay = false,
    bool isMuted = false,
    bool loop = true,
  }) {
    if (source.isYouTube) {
      return YouTubePlaybackController(
        source,
        autoPlay: autoPlay,
        isMuted: isMuted,
        loop: loop,
      );
    } else {
      return NetworkVideoPlaybackController(
        source,
        autoPlay: autoPlay,
        isMuted: isMuted,
        loop: loop,
      );
    }
  }

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setMuted(bool muted);
  Future<void> setLooping(bool looping);

  Future<void> togglePlayPause() async {
    if (value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  bool get isDisposed => value.isDisposed;
}
