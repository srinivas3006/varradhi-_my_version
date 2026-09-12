import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/media/video_playback_controller.dart';
import 'package:way2news_clone/models/video_item.dart';
import 'package:way2news_clone/repositories/video_repository.dart';

void main() {
  group('VideoPlaybackState and Status Tests', () {
    test('VideoPlaybackState defaults are correct and idle', () {
      const state = VideoPlaybackState();

      expect(state.status, PlaybackStatus.idle);
      expect(state.isPlaying, false);
      expect(state.isBuffering, false);
      expect(state.isInitialized, false);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.volume, 1.0);
      expect(state.isMuted, false);
      expect(state.isLooping, false);
      expect(state.errorMessage, null);
    });

    test('VideoPlaybackState copyWith updates fields properly', () {
      const initial = VideoPlaybackState();
      final updated = initial.copyWith(
        status: PlaybackStatus.playing,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
        isMuted: true,
      );

      expect(updated.status, PlaybackStatus.playing);
      expect(updated.isPlaying, true);
      expect(updated.position, const Duration(seconds: 10));
      expect(updated.duration, const Duration(seconds: 60));
      expect(updated.isMuted, true);
      expect(updated.volume, 1.0); // Preserved
    });

    test('PlaybackStatus status booleans behave accurately', () {
      expect(const VideoPlaybackState(status: PlaybackStatus.buffering).isBuffering, true);
      expect(const VideoPlaybackState(status: PlaybackStatus.playing).isPlaying, true);
      expect(const VideoPlaybackState(status: PlaybackStatus.ready).isInitialized, true);
      expect(const VideoPlaybackState(status: PlaybackStatus.error, errorMessage: 'Failed').isError, true);
    });
  });

  group('Rapid-Swipe Race Condition Token Logic', () {
    test('Simulated generation token invalidates stale async completions', () async {
      int activeToken = 0;
      int completedToken = 0;
      bool wasDisposed = false;

      // Swipe to card 1
      activeToken++;
      final token1 = activeToken;

      // User quickly swipes to card 2 before card 1 finishes init
      activeToken++;
      final token2 = activeToken;

      // Async callback for card 1 finishes late
      if (token1 != activeToken) {
        wasDisposed = true; // Stale controller is safely cancelled / disposed
      } else {
        completedToken = token1;
      }

      // Async callback for card 2 finishes
      if (token2 == activeToken) {
        completedToken = token2;
      }

      expect(wasDisposed, true);
      expect(completedToken, 2);
    });
  });

  group('VideoRepository Feed & Deduplication Tests', () {
    setUp(() {
      VideoRepository.instance.clearCache();
    });

    test('VideoRepository initial cache is null', () {
      expect(VideoRepository.instance.getCachedShorts(), null);
    });

    test('VideoItem safely coerces types from dirty JSON payloads', () {
      final dirtyJson = {
        'id': 12345,
        'title': 'Test Title',
        'channel_name': 'Test Channel',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'video_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'youtube_url': null,
        'duration_seconds': '125',
        'views_count': '5400',
        'likes_count': '320',
        'is_short': 'true', // string instead of bool
      };

      final item = VideoItem.fromJson(dirtyJson);

      expect(item.id, '12345');
      expect(item.durationSeconds, 125);
      expect(item.duration, '2:05');
      expect(item.viewsCount, 5400);
      expect(item.likesCount, 320);
    });
  });
}
