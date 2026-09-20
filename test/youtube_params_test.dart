import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const players = [
    'lib/core/media/youtube_playback_controller.dart',
    'lib/screens/live_news_screen.dart',
  ];

  group('the YouTube embed params stay on the working configuration', () {
    // Regression guard. 1aff663 fixed playback by using the nocookie host and
    // dropping the explicit origin; merge 37287da reverted both, and the
    // player silently stopped becoming ready. Code, not prose, is checked so
    // a comment mentioning the old values cannot pass this.
    String code(String path) => File(path)
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    for (final path in players) {
      test('$path sets privacyEnhancedMode true', () {
        expect(code(path), contains('privacyEnhancedMode: true'));
        expect(code(path), isNot(contains('privacyEnhancedMode: false')));
      });

      test('$path passes no explicit origin', () {
        // The package uses `origin` as the WebView baseUrl; pinning it breaks
        // the iframe postMessage handshake.
        expect(code(path), isNot(contains("origin: 'https://www.youtube.com'")));
      });
    }
  });

  group('the in-app webview fallback is still wired', () {
    final widget =
        File('lib/core/media/video_player_widget.dart').readAsStringSync();

    test('a restricted video can fall back to an embed', () {
      expect(widget, contains('_useInAppWebPlayer'));
      expect(widget, contains('youtube.com/embed/'));
    });

    test('restricted-embed errors are still recognised', () {
      final ctrl = File('lib/core/media/youtube_playback_controller.dart')
          .readAsStringSync();
      expect(ctrl, contains('notEmbeddable'));
      expect(ctrl, contains('sameAsNotEmbeddable'));
    });
  });

  group('playback intent still goes in at construction', () {
    test('no call site plays after setState instead of via autoPlay', () {
      for (final path in [
        'lib/widgets/news_article_video_player.dart',
        'lib/screens/video_player_screen.dart',
        'lib/screens/shorts_viewer_screen.dart',
      ]) {
        final code = File(path)
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(code, contains('autoPlay:'), reason: path);
        expect(code, isNot(contains('ctrl.play()')), reason: path);
      }
    });
  });

  group('the player stays inside its slot', () {
    final widget =
        File('lib/core/media/video_player_widget.dart').readAsStringSync();
    final card = File('lib/widgets/spotlight/spotlight_news_card.dart')
        .readAsStringSync();

    test('the embedded player is clipped', () {
      // A WebView-backed player sizes itself from its content and painted
      // over the chrome above the card.
      expect(widget, contains('ClipRect'));
    });

    test('aspect ratio is applied once, not nested', () {
      // YoutubePlayer already applies its own AspectRatio; wrapping it in
      // another let the inner one compute a size the slot could not hold.
      final surface = widget.substring(
          widget.indexOf('_buildActivePlayerSurface'));
      final yt = surface.substring(
          surface.indexOf('is YouTubePlaybackController'),
          surface.indexOf('is NetworkVideoPlaybackController'));
      expect(yt, contains('YoutubePlayer('));
      expect(yt, isNot(contains('AspectRatio(')),
          reason: 'the player owns its own aspect');
    });

    test('fullscreen-on-vertical-drag is off inside the vertical feed', () {
      expect(widget, contains('enableFullScreenOnVerticalDrag: false'));
      expect(widget, contains('autoFullScreen: false'));
    });

    test('the media slot clips its transformed contents', () {
      final slot = card.substring(card.indexOf('height: mediaHeight,'));
      expect(slot.substring(0, 600), contains('ClipRect'));
    });
  });

  group('only one picture shows at a time', () {
    final widget =
        File('lib/core/media/video_player_widget.dart').readAsStringSync();

    test('the poster frame is gated on the player not being up yet', () {
      // Regression: the thumbnail sat behind the player for the whole
      // session as an "ambient background", so it showed through the
      // letterbox bands while the video played.
      expect(widget, contains('if (!state.isInitialized &&'));
    });

    test('an initialised player gets black behind it, not an image', () {
      final stack = widget.substring(
          widget.indexOf('// 1. Poster frame'),
          widget.indexOf('// 2. Active Video Surface'));
      expect(stack, contains('Container(color: Colors.black)'));
      // The image is reachable only through the not-initialised branch.
      expect(stack.indexOf('CachedNetworkImage'),
          greaterThan(stack.indexOf('!state.isInitialized')));
    });
  });
}
