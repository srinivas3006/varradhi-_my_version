import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/ads/ad_event_queue.dart';
import 'package:vaaradhi/core/media/video_playback_controller.dart';
import 'package:vaaradhi/services/ad_manager.dart';
import 'package:vaaradhi/models/ad_banner.dart';
import 'package:vaaradhi/widgets/ads/ad_video_preloader.dart';
import 'package:vaaradhi/widgets/ads/full_screen_ad_image.dart';
import 'package:vaaradhi/widgets/ads/sponsored_spotlight_ad_card.dart';
import 'package:vaaradhi/widgets/ads/unified_ad_widget.dart';
import 'package:vaaradhi/widgets/ads/video_ad_card.dart';
import 'package:vaaradhi/widgets/ads/video_feed_ad_page.dart';
import 'package:visibility_detector/visibility_detector.dart';

AdBanner _ad(
        {String type = 'video', String video = 'https://cdn.test/a.mp4'}) =>
    AdBanner.fromJson({
      'id': 'ad-1',
      'title': 'Vaaradhi Ads',
      'image_url': 'https://cdn.test/poster.jpg',
      'video_url': video,
      'destination_url': 'https://example.com/offer',
      'ad_type': type,
    });

/// A phone-shaped screen, as on the reported device.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 6; i++) {
    AdEventQueue.instance.reset();
    await tester.pump(const Duration(seconds: 5));
  }
  AdEventQueue.instance.reset();
  await tester.pump();
}

const _screen = Size(360, 800);

void main() {
  setUp(() =>
      VisibilityDetectorController.instance.updateInterval = Duration.zero);

  group('Spotlight: a video ad is a full-screen ad', () {
    testWidgets('it fills the whole page, not a card in a 9:16 frame',
        (tester) async {
      await _pump(
          tester,
          SponsoredSpotlightAdCard(
              ad: _ad(), active: true, onClose: () {}, placementZone: 'feed'));
      final page = find.byKey(const Key('video_ad_full_screen'));
      expect(page, findsOneWidget);
      expect(tester.getSize(page), _screen);
      expect(find.text('SPONSORED VIDEO'), findsNothing,
          reason: 'the feed card is not used here');
      expect(find.byType(AspectRatio), findsNothing);
      await _teardown(tester);
    });

    testWidgets('title and Learn More sit over the bottom of the video',
        (tester) async {
      await _pump(
          tester,
          SponsoredSpotlightAdCard(
              ad: _ad(), active: true, onClose: () {}, placementZone: 'feed'));
      final details = find.byKey(const Key('video_ad_details'));
      expect(tester.getBottomLeft(details).dy, _screen.height);
      expect(find.text('Vaaradhi Ads'), findsOneWidget);
      expect(find.text('Sponsored · example.com'), findsOneWidget);
      expect(find.byKey(const Key('video_ad_cta')), findsOneWidget);
      // The disclosure and Skip still float on top.
      expect(find.text('Ad'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      await _teardown(tester);
    });
  });

  group('Shorts / Reels page', () {
    Widget page(AdBanner ad) =>
        VideoFeedAdPage(ad: ad, active: true, onSkip: () {});

    testWidgets('a video ad fills the page; Skip is at the top right',
        (tester) async {
      await _pump(tester, page(_ad()));
      final ad = find.byKey(const Key('video_ad_full_screen'));
      expect(tester.getSize(ad), _screen);
      final skip =
          tester.getTopRight(find.byKey(const Key('video_feed_ad_skip')));
      expect(skip.dy, lessThan(80));
      expect(skip.dx, greaterThan(_screen.width - 20));
      await _teardown(tester);
    });

    testWidgets('a poster with a video attached keeps its own layout',
        (tester) async {
      await _pump(tester, page(_ad(type: 'poster')));
      expect(find.byKey(const Key('video_ad_full_screen')), findsNothing);
      expect(find.byType(UnifiedAdWidget), findsOneWidget);
      await _teardown(tester);
    });
  });

  testWidgets('the interstitial draws its own title, so the video does not',
      (tester) async {
    await _pump(
        tester, VideoAdCard(ad: _ad(), fullScreen: true, showDetails: false));
    expect(find.byKey(const Key('video_ad_full_screen')), findsOneWidget);
    expect(find.byKey(const Key('video_ad_details')), findsNothing);
    await _teardown(tester);
  });

  testWidgets('feeds keep the card', (tester) async {
    // The default test screen: on a phone-narrow one the test font, larger
    // than real fonts, overflows the card's text.
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(child: VideoAdCard(ad: _ad())))));
    await tester.pump();
    expect(find.text('SPONSORED VIDEO'), findsOneWidget);
    expect(find.byKey(const Key('video_ad_full_screen')), findsNothing);
    await _teardown(tester);
  });

  group('fill rule for video', () {
    const phone = 9 / 20;
    test('a portrait video fills a tall phone', () {
      expect(FullScreenAdImage.videoFills(9 / 16, phone), isTrue);
      expect(FullScreenAdImage.videoFills(4 / 5, phone), isTrue);
    });
    test('a wide or square video is shown whole', () {
      expect(FullScreenAdImage.videoFills(16 / 9, phone), isFalse);
      expect(FullScreenAdImage.videoFills(1, phone), isFalse);
    });
    test('an unknown size never fills', () {
      expect(FullScreenAdImage.videoFills(0, phone), isFalse);
    });
  });

  group('Skip shows the seconds on a timed video ad', () {
    testWidgets('display_duration_seconds shows until the video reports',
        (tester) async {
      await _pump(
          tester,
          SponsoredSpotlightAdCard(
              ad: _ad(),
              active: true,
              durationSeconds: 10,
              onClose: () {},
              placementZone: 'feed'));
      expect(find.text('Skip 10'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('an image ad still counts down on its clock', (tester) async {
      await _pump(
          tester,
          SponsoredSpotlightAdCard(
              ad: _ad(type: 'full_screen', video: ''),
              active: true,
              durationSeconds: 10,
              onClose: () {},
              placementZone: 'feed'));
      expect(find.text('Skip 10'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Skip 9'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('no duration: plain Skip, never cut off', (tester) async {
      await _pump(
          tester,
          SponsoredSpotlightAdCard(
              ad: _ad(), active: true, onClose: () {}, placementZone: 'feed'));
      expect(find.text('Skip'), findsOneWidget);
      await _teardown(tester);
    });

    test('Spotlight gives an untimed video no 5 second limit', () {
      final src = File('lib/spotlight/spotlight_screen.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      expect(src, contains('videoUrl.trim().isNotEmpty ? 0 : 5'));
    });
  });

  group('the next ad is ready before it is reached', () {
    tearDown(AdVideoPreloader.instance.clear);

    test('each video opened once, at most two held', () {
      final p = AdVideoPreloader.instance;
      p.preload('https://cdn.test/1.mp4');
      p.preload('https://cdn.test/1.mp4');
      expect(p.readyCount, 1);
      p.preload('https://cdn.test/2.mp4');
      p.preload('https://cdn.test/3.mp4');
      expect(p.readyCount, 2);
      expect(p.take('https://cdn.test/1.mp4'), isNull,
          reason: 'the oldest was closed');
      final taken = p.take('https://cdn.test/3.mp4');
      expect(taken, isNotNull);
      taken!.controller.dispose();
      expect(p.readyCount, 1);
    });

    test('nothing for an ad without a video', () {
      AdVideoPreloader.instance.preload('');
      expect(AdVideoPreloader.instance.readyCount, 0);
    });

    test('Spotlight preloads the ads ahead and closes them on exit', () {
      final src = File('lib/spotlight/spotlight_screen.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      expect(src, contains('AdVideoPreloader.instance.preload(ad.videoUrl)'));
      expect(src, contains('CachedNetworkImageProvider(ad.imageUrl)'));
      expect('AdVideoPreloader.instance.clear()'.allMatches(src).length, 2);
    });
  });

  test('splash: impression only once the ad is on screen', () {
    final src = File('lib/screens/splash_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final show = src.substring(src.indexOf('Future<void> _showSplashAd'),
        src.indexOf('showGeneralDialog'));
    expect(show, isNot(contains('recordImpression')));
    expect(src, contains("exposureKey: 'splash_"),
        reason: 'the viewability detector sends it');
    expect(src, isNot(contains('await canLaunchUrl(')));
  });

  test('full-page ad video plays with sound; a feed card stays muted', () {
    String read(String p) =>
        File(p).readAsStringSync().replaceAll('\r\n', '\n');
    expect(read('lib/widgets/ads/video_ad_card.dart'),
        contains('isMuted: !widget.fullScreen'));
    expect(read('lib/widgets/ads/ad_video_preloader.dart'),
        contains('isMuted: false'));
    final splash = read('lib/screens/splash_screen.dart');
    final init = splash.substring(splash.indexOf('void _initVideoPlayer'));
    expect(init.substring(0, 700), contains('isMuted: false'));
  });

  group('a video ad plays once, in step with its countdown', () {
    String read(String p) =>
        File(p).readAsStringSync().replaceAll('\r\n', '\n');

    test('no player loops an ad video', () {
      for (final p in [
        'lib/widgets/ads/video_ad_card.dart',
        'lib/widgets/ads/ad_video_preloader.dart',
        'lib/screens/splash_screen.dart',
      ]) {
        final src = read(p);
        expect(src, isNot(contains('loop: true')), reason: p);
        expect(src, contains('loop: false'), reason: p);
      }
    });

    test('Skip shows the video time left, rounded up', () {
      int left(int posMs, int durMs) => SponsoredSpotlightAdCard.secondsLeft(
          Duration(milliseconds: posMs), Duration(milliseconds: durMs));
      expect(left(0, 15000), 15);
      expect(left(200, 15000), 15);
      expect(left(1000, 15000), 14);
      expect(left(14100, 15000), 1);
      expect(left(15000, 15000), 0);
    });

    test('the end of the video is recognised', () {
      const playing = VideoPlaybackState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 3),
          duration: Duration(seconds: 15));
      expect(VideoAdCard.reachedEnd(playing), isFalse);
      expect(
          VideoAdCard.reachedEnd(playing.copyWith(
              status: PlaybackStatus.paused,
              position: const Duration(seconds: 15))),
          isTrue);
      expect(
          VideoAdCard.reachedEnd(
              playing.copyWith(status: PlaybackStatus.completed)),
          isTrue);
      expect(VideoAdCard.reachedEnd(const VideoPlaybackState()), isFalse,
          reason: 'nothing loaded yet is not an ended video');
    });

    test('completion is remembered once per exposure', () {
      final ad = _ad();
      expect(AdManager.instance.hasCompleted(ad, contextKey: 'x1'), isFalse);
      AdManager.instance.recordComplete(ad, contextKey: 'x1');
      expect(AdManager.instance.hasCompleted(ad, contextKey: 'x1'), isTrue);
      expect(AdManager.instance.hasCompleted(ad, contextKey: 'x2'), isFalse);
    });

    test('Spotlight follows the video, then moves on at its end', () {
      final src = read('lib/widgets/ads/sponsored_spotlight_ad_card.dart');
      expect(src, contains('onProgress: _onVideoProgress'));
      expect(src, contains('onCompleted: _onVideoCompleted'));
      expect(src, contains('onFailed: _onVideoFailed'));
    });
  });

  test('the interstitial asks for the full-screen video', () {
    final src = File('lib/widgets/ads/interstitial_ad_overlay.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final call = src.substring(src.indexOf('? VideoAdCard('));
    expect(call.substring(0, 300), contains('fullScreen: true'));
  });
}
