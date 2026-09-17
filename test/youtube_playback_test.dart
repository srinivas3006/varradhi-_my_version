import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/media/media_source.dart';
import 'package:way2news_clone/core/media/video_playback_controller.dart';
import 'package:way2news_clone/core/media/youtube_playback_controller.dart';

void main() {
  group('controller construction', () {
    test('a YouTube source builds a YouTube controller', () {
      final src = MediaSource.youtube(videoId: 'dQw4w9WgXcQ', thumbnailUrl: '');
      expect(
        VideoPlaybackController.fromSource(src),
        isA<YouTubePlaybackController>(),
      );
    });

    test('defaults to paused — nothing plays just by being constructed', () {
      final src = MediaSource.youtube(videoId: 'dQw4w9WgXcQ', thumbnailUrl: '');
      final ctrl = VideoPlaybackController.fromSource(src);
      addTearDown(ctrl.dispose);
      expect(ctrl.value.status, isNot(PlaybackStatus.playing));
    });

    test('an invalid video id surfaces an error, not a silent dead player',
        () async {
      final src = MediaSource.youtube(videoId: '', thumbnailUrl: '');
      final ctrl = VideoPlaybackController.fromSource(src);
      addTearDown(ctrl.dispose);
      await ctrl.initialize();
      expect(ctrl.value.status, PlaybackStatus.error);
      expect(ctrl.value.errorMessage, isNotNull);
    });
  });

  group('the first tap is not lost', () {
    // Regression cover. play() used to be called straight after initialize(),
    // but the player surface only mounts on the next frame — so playVideo()
    // hit an unattached controller and was dropped, and the reader had to
    // interact a second time. Intent now goes in via autoPlay, which the
    // player honours once it is ready.
    String body(String path, String marker) {
      final src = File(path).readAsStringSync();
      final i = src.indexOf(marker);
      return src.substring(i, i + 1400);
    }

    test('feed player hands intent to autoPlay instead of calling play()', () {
      final b = body('lib/widgets/news_article_video_player.dart',
          'SpotlightMediaCoordinator.instance.notifyVideoStarted');
      expect(b, contains('autoPlay: true'));
      expect(b, isNot(contains('ctrl.play()')));
    });

    test('full-screen player does the same', () {
      final b = body('lib/screens/video_player_screen.dart',
          'VideoPlaybackController.fromSource');
      expect(b, contains('autoPlay: true'));
      expect(b, isNot(contains('ctrl.play()')));
    });

    test('video tab keeps focus-driven playback, without the lost command', () {
      final b = body('lib/screens/video_tab.dart',
          'VideoPlaybackController.fromSource');
      expect(b, contains('autoPlay: widget.isFocused'));
      expect(b, isNot(contains('ctrl.play()')));
    });
  });
}
