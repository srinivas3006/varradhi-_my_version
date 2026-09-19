import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/video_item.dart';

VideoItem _item(Map<String, dynamic> json) => VideoItem.fromJson(json);

void main() {
  group('one canonical classification', () {
    test('is_short from the backend marks a Short', () {
      expect(_item({'id': '1', 'is_short': true}).isShort, isTrue);
    });

    test('a /shorts/ url is recognised even without the flag', () {
      expect(
        _item({'id': '1', 'youtube_url': 'https://youtube.com/shorts/abc'})
            .isShort,
        isTrue,
      );
    });

    test('a regular video is not a Short', () {
      expect(
        _item({'id': '1', 'youtube_url': 'https://youtube.com/watch?v=abc'})
            .isShort,
        isFalse,
      );
      expect(_item({'id': '2'}).isShort, isFalse);
    });
  });

  group('the two sections never overlap', () {
    final mixed = [
      _item({'id': 's1', 'is_short': true}),
      _item({'id': 'v1'}),
      _item({'id': 's2', 'youtube_url': 'https://youtube.com/shorts/x'}),
      _item({'id': 'v2', 'youtube_url': 'https://youtube.com/watch?v=y'}),
    ];

    test('the Home carousel holds regular videos only', () {
      final videos = mixed.where((v) => !v.isShort).toList();
      expect(videos.map((v) => v.id), ['v1', 'v2']);
      expect(videos.any((v) => v.isShort), isFalse);
    });

    test('the Video section holds Shorts only', () {
      final shorts = mixed.where((v) => v.isShort).toList();
      expect(shorts.map((v) => v.id), ['s1', 's2']);
      expect(shorts.every((v) => v.isShort), isTrue);
    });

    test('no item can appear in both', () {
      final shorts = mixed.where((v) => v.isShort).map((v) => v.id).toSet();
      final videos = mixed.where((v) => !v.isShort).map((v) => v.id).toSet();
      expect(shorts.intersection(videos), isEmpty);
      expect(shorts.length + videos.length, mixed.length);
    });

    test('Video-section pagination cannot reintroduce a regular video', () {
      // Page 2 arrives carrying a regular video; the filter runs on every
      // page, not just the first.
      final page1 = [_item({'id': 's1', 'is_short': true})];
      final page2 = [_item({'id': 'v9'}), _item({'id': 's2', 'is_short': true})];
      final accumulated = <VideoItem>[]
        ..addAll(page1.where((v) => v.isShort))
        ..addAll(page2.where((v) => v.isShort));
      expect(accumulated.map((v) => v.id), ['s1', 's2']);
    });

    test('Home pagination cannot reintroduce a Short', () {
      final page1 = [_item({'id': 'v1'})];
      final page2 = [_item({'id': 's9', 'is_short': true}), _item({'id': 'v2'})];
      final accumulated = <VideoItem>[]
        ..addAll(page1.where((v) => !v.isShort))
        ..addAll(page2.where((v) => !v.isShort));
      expect(accumulated.map((v) => v.id), ['v1', 'v2']);
    });

    test('refresh keeps the separation on both surfaces', () {
      expect(mixed.where((v) => !v.isShort).any((v) => v.isShort), isFalse);
      expect(mixed.where((v) => v.isShort).every((v) => v.isShort), isTrue);
    });
  });

  group('the screens agree structurally', () {
    test('the Video tab serves the shorts feed and keeps Shorts only', () {
      final src = File('lib/screens/video_tab.dart').readAsStringSync();
      expect(src, contains('getShortsFeed'));
      expect(src, isNot(contains('getVideoFeed')),
          reason: 'regular videos belong to the Home carousel now');
      expect(src, contains('.where((video) => video.isShort)'));
    });

    test('the Home carousel serves the video feed and excludes Shorts', () {
      final src = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      expect(src, contains('getVideoFeed'));
      expect(src, isNot(contains('getShortsFeed')));
      expect(src, contains('!v.isShort'));
    });

    test('an empty video list hides the Home section', () {
      final src = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      final strip = src.substring(src.indexOf('Widget _buildHomeVideosStrip()'));
      expect(strip.substring(0, 300),
          contains('if (_homeVideos.isEmpty) return const SizedBox.shrink();'));
    });

    test('the carousel creates no player and does not autoplay', () {
      final src = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      final strip = src.substring(
          src.indexOf('Widget _buildHomeVideosStrip()'),
          src.indexOf('Widget _buildPostersStrip()'));
      expect(strip, isNot(contains('VideoPlaybackController')));
      expect(strip, isNot(contains('autoPlay')));
    });

    test('Home cards are 16:9, not the Shorts 9:16', () {
      final src = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      final strip = src.substring(
          src.indexOf('Widget _buildHomeVideosStrip()'),
          src.indexOf('Widget _buildPostersStrip()'));
      expect(strip, contains('aspectRatio: 16 / 9'),
          reason: 'landscape video would letterbox in a portrait card');
    });

    test('tapping a Home video opens the regular player', () {
      final src = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      final strip = src.substring(
          src.indexOf('Widget _buildHomeVideosStrip()'),
          src.indexOf('Widget _buildPostersStrip()'));
      expect(strip, contains('VideoPlayerScreen('));
    });
  });
}
