import 'package:flutter/foundation.dart';

import '../../core/media/media_resolver.dart';
import '../../core/media/media_source.dart';
import '../../core/media/network_video_playback_controller.dart';

/// A video ad's player, opened before its page is reached, so the ad starts
/// on a ready first frame instead of a black page with a spinner.
///
/// Holds at most [maxReady] players; the oldest is closed when another is
/// added. A card takes its player with [take] and owns it from then on.
class AdVideoPreloader {
  AdVideoPreloader._();
  static final AdVideoPreloader instance = AdVideoPreloader._();

  static const maxReady = 2;

  final Map<String,
          ({NetworkVideoPlaybackController controller, Future<void> ready})>
      _players = {};

  @visibleForTesting
  int get readyCount => _players.length;

  /// Starts opening [videoUrl] (paused, with sound: only full-page ads are
  /// preloaded, and those play with sound). Does nothing if it is
  /// already open or not a playable network video.
  void preload(String videoUrl) {
    final url = videoUrl.trim();
    if (url.isEmpty || _players.containsKey(url)) return;
    final source = MediaResolver.resolve(videoUrl: url, isVideoFlag: true);
    if (source.type != MediaSourceType.networkVideo) return;
    while (_players.length >= maxReady) {
      final oldest = _players.keys.first;
      _players.remove(oldest)!.controller.dispose();
    }
    // Played once, never looped (see VideoAdCard).
    final controller = NetworkVideoPlaybackController(source,
        autoPlay: false, isMuted: false, loop: false);
    _players[url] = (controller: controller, ready: controller.initialize());
  }

  /// The player opened for [videoUrl], if any. The caller disposes it.
  ({NetworkVideoPlaybackController controller, Future<void> ready})? take(
          String videoUrl) =>
      _players.remove(videoUrl.trim());

  /// Closes every player not yet taken (the screen that asked has closed).
  void clear() {
    for (final p in _players.values) {
      p.controller.dispose();
    }
    _players.clear();
  }
}
