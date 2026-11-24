import 'dart:math';

import '../media/video_playback_controller.dart';

/// Counts forward media time while the reader can see actual playback.
class AdVideoMeasurement {
  AdVideoMeasurement({int? selectedDurationMs})
      : _durationMs = selectedDurationMs != null && selectedDurationMs > 0
            ? selectedDurationMs
            : null;

  int? _durationMs;
  int? _previousPosition;
  int? _previousTime;
  int _watchMs = 0;
  int _continuousMs = 0;
  int _positionMs = 0;
  final _reported = <String>{};

  int get continuousMs => _continuousMs;
  bool get hasWatched => _watchMs > 0;
  Map<String, num> get telemetry => {
        if (_durationMs != null) 'video_duration_ms': _durationMs!,
        'position_ms': _positionMs,
        'watch_time_ms': _watchMs,
      };

  void interrupt() {
    _previousPosition = null;
    _previousTime = null;
    _continuousMs = 0;
  }

  List<String> sample(VideoPlaybackState state, int timeMs,
      {required bool eligible}) {
    if (_durationMs == null && state.duration.inMilliseconds > 0) {
      _durationMs = state.duration.inMilliseconds;
    }
    if (!eligible) {
      interrupt();
      return const [];
    }
    if (state.isError) {
      interrupt();
      return _reported.add('video_error') ? ['video_error'] : const [];
    }
    final duration = _durationMs;
    if (duration == null || (!state.isPlaying && !state.isCompleted)) {
      interrupt();
      return const [];
    }

    final position = state.position.inMilliseconds.clamp(0, duration).toInt();
    final previous = _previousPosition;
    final elapsed = timeMs - (_previousTime ?? timeMs);
    _previousPosition = position;
    _previousTime = timeMs;
    _positionMs = position;
    if (previous == null) return const [];
    final advance = position - previous;
    // Playback callbacks may repeat the same position. Keep the baseline
    // until the player either progresses or actually leaves playing state.
    if (advance == 0 && state.isPlaying) {
      _previousTime = timeMs - elapsed;
      return const [];
    }
    if (advance <= 0 ||
        elapsed <= 0 ||
        elapsed > 1500 ||
        advance > elapsed + 100) {
      _continuousMs = 0;
      return const [];
    }
    final watched = min(advance, elapsed);
    _watchMs = min(duration, _watchMs + watched);
    _continuousMs += watched;
    final events = <String>[];
    if (_reported.add('video_start')) events.add('video_start');
    const milestones = {
      'video_25': 25,
      'video_50': 50,
      'video_75': 75,
      'video_complete': 90,
    };
    for (final entry in milestones.entries) {
      if (min(position, _watchMs) * 100 >= duration * entry.value &&
          _reported.add(entry.key)) {
        events.add(entry.key);
      }
    }
    return events;
  }
}
