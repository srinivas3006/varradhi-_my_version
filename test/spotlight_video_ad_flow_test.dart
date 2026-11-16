import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vaaradhi/core/ads/ad_event_queue.dart';
import 'package:vaaradhi/core/widgets/flip_page_view.dart';
import 'package:vaaradhi/models/ad_banner.dart';
import 'package:vaaradhi/spotlight/spotlight_media_coordinator.dart';
import 'package:vaaradhi/widgets/ads/ad_video_preloader.dart';
import 'package:vaaradhi/widgets/ads/sponsored_spotlight_ad_card.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A video player that "opens" a 20 s clip and records what it was told.
class _FakePlayer extends VideoPlayerPlatform with MockPlatformInterfaceMixin {
  _FakePlayer({this.fails = false});

  /// Every video fails to open (as when the phone cannot decode it).
  final bool fails;
  int _next = 0;
  final created = <int>[];
  final disposed = <int>[];
  final played = <int>[];
  final seeks = <int, List<Duration>>{};
  final _events = <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _next++;
    created.add(id);
    _events[id] = StreamController<VideoEvent>();
    if (fails) {
      scheduleMicrotask(() => _events[id]!.addError(PlatformException(
          code: 'VideoError', message: 'MediaCodec could not be opened')));
      return id;
    }
    scheduleMicrotask(() => _events[id]!.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 20),
          size: const Size(1080, 1920),
        )));
    return id;
  }

  @override
  Future<int?> create(DataSource dataSource) =>
      createWithOptions(VideoCreationOptions(
          dataSource: dataSource, viewType: VideoViewType.textureView));

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async => disposed.add(playerId);

  @override
  Future<void> play(int playerId) async => played.add(playerId);

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      (seeks[playerId] ??= []).add(position);

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      ColoredBox(key: Key('fake_video_${options.playerId}'), color: Colors.red);

  @override
  Widget buildView(int playerId) =>
      buildViewWithOptions(VideoViewOptions(playerId: playerId));
}

final _video = AdBanner.fromJson({
  'id': '04ca299e',
  'image_url': '',
  'video_url': 'https://cdn.test/ad.mp4',
  'destination_url': 'https://example.com',
  'ad_type': 'video',
  'placement_zone': 'feed',
  'display_frequency': 5,
  'display_duration_seconds': 20,
});

/// Spotlight in miniature: the same pager, current-page notifier, media
/// stop and ad preloading as SpotlightScreen._handlePageChanged.
class _MiniSpotlight extends StatefulWidget {
  const _MiniSpotlight({required this.pages, this.onClose});
  final List<AdBanner?> pages;
  final VoidCallback? onClose;
  @override
  State<_MiniSpotlight> createState() => _MiniSpotlightState();
}

class _MiniSpotlightState extends State<_MiniSpotlight> {
  final controller = PageController();
  final current = ValueNotifier<int>(0);

  void _changed(int index) {
    current.value = index;
    SpotlightMediaCoordinator.instance.stopAll();
    for (var i = index + 1; i <= index + 2 && i < widget.pages.length; i++) {
      final ad = widget.pages[i];
      if (ad != null) AdVideoPreloader.instance.preload(ad.videoUrl);
    }
  }

  @override
  void initState() {
    super.initState();
    _changed(0);
  }

  @override
  void dispose() {
    controller.dispose();
    AdVideoPreloader.instance.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FlipPageView(
        controller: controller,
        itemCount: widget.pages.length,
        onPageChanged: _changed,
        itemBuilder: (context, index) => ValueListenableBuilder<int>(
          valueListenable: current,
          builder: (context, page, _) {
            final ad = widget.pages[index];
            if (ad == null) {
              return ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text('story $index')));
            }
            return SponsoredSpotlightAdCard(
              key: ValueKey('ad_$index'),
              ad: ad,
              active: page == index,
              durationSeconds: 20,
              exposureKey: 'test_$index',
              onClose: widget.onClose ?? () {},
            );
          },
        ),
      );
}

void main() {
  late _FakePlayer player;
  setUp(() {
    player = _FakePlayer();
    VideoPlayerPlatform.instance = player;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<void> swipeUp(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(0, -500), 1500);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
      'scrolling onto a video ad shows and plays it, from the start once',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: _MiniSpotlight(pages: [null, null, _video, null]))));
    await tester.pump(const Duration(milliseconds: 100));

    await swipeUp(tester); // story 1
    await swipeUp(tester); // the ad

    expect(find.byKey(const Key('video_ad_full_screen')), findsOneWidget);
    final shown = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('fake_video_'));
    expect(shown, findsOneWidget, reason: 'the video itself is on screen');
    expect(player.played, isNotEmpty, reason: 'it plays');
    final playing = player.played.last;
    expect(player.disposed, isNot(contains(playing)));
    expect(player.seeks[playing] ?? const [], isEmpty,
        reason: 'never sent back to the start');

    // Watching on: nothing replaces or restarts the player.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(player.played.toSet(), {playing},
        reason: 'one player for the ad, not a second one started later');
    expect(player.disposed, isNot(contains(playing)));

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 6; i++) {
      AdEventQueue.instance.reset();
      await tester.pump(const Duration(seconds: 5));
    }
  });

  testWidgets('a video that cannot play, with no poster, is skipped',
      (tester) async {
    VideoPlayerPlatform.instance = _FakePlayer(fails: true);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var closed = 0;

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: _MiniSpotlight(
                pages: [null, null, _video, null], onClose: () => closed++))));
    await tester.pump(const Duration(milliseconds: 100));
    await swipeUp(tester);
    expect(closed, 0, reason: 'not before the reader gets there');
    await swipeUp(tester);
    expect(closed, 1, reason: 'no black page with a spinner');

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 6; i++) {
      AdEventQueue.instance.reset();
      await tester.pump(const Duration(seconds: 5));
    }
  });
}
