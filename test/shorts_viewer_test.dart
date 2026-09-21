import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/video_item.dart';
import 'package:way2news_clone/screens/shorts_viewer_screen.dart';

VideoItem _short(String id) => VideoItem.fromJson({
      'id': id,
      'title': 'Short $id',
      'is_short': true,
      'thumbnail_url': '',
      'youtube_url': 'https://youtube.com/shorts/$id',
    });

void main() {
  final shorts = [_short('a'), _short('b'), _short('c')];

  // The placeholder spinner animates indefinitely, so pumpAndSettle would
  // never return; frames are pumped explicitly instead.
  Future<void> pumpViewer(WidgetTester tester, {int initialIndex = 0}) async {
    await tester.pumpWidget(MaterialApp(
      home: ShortsViewerScreen(shorts: shorts, initialIndex: initialIndex),
    ));
    await tester.pump();
  }

  group('the viewer is a vertical 9:16 pager', () {
    testWidgets('it renders at 9:16, not landscape', (tester) async {
      await pumpViewer(tester);
      final ratios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(ratios, contains(9 / 16),
          reason: 'a Short is portrait; the landscape player letterboxed it');
    });

    testWidgets('it opens on the tapped Short, not the first', (tester) async {
      await pumpViewer(tester, initialIndex: 2);
      expect(find.text('Short c'), findsOneWidget);
    });

    testWidgets('swiping up advances to the next Short', (tester) async {
      await pumpViewer(tester);
      expect(find.text('Short a'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Short b'), findsOneWidget);
    });

    testWidgets('swiping down returns to the previous Short', (tester) async {
      await pumpViewer(tester, initialIndex: 1);

      await tester.drag(find.byType(PageView), const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Short a'), findsOneWidget);
    });

    testWidgets('the first Short cannot swipe past the start', (tester) async {
      await pumpViewer(tester);
      await tester.drag(find.byType(PageView), const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Short a'), findsOneWidget);
    });

    testWidgets('the last Short cannot swipe past the end', (tester) async {
      await pumpViewer(tester, initialIndex: 2);
      await tester.drag(find.byType(PageView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Short c'), findsOneWidget);
    });

    testWidgets('an empty list does not crash', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: ShortsViewerScreen(shorts: [])));
      await tester.pump();
      expect(find.text('No shorts available'), findsOneWidget);
    });
  });

  group('back returns to the originating screen', () {
    testWidgets('the viewer pops rather than routing Home', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => ShortsViewerScreen(shorts: shorts))),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      // Route transitions need a few frames; the spinner rules out settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ShortsViewerScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('open'), findsOneWidget,
          reason: 'back must return where the reader came from');
    });
  });

  group('wiring', () {
    final tab = File('lib/screens/video_tab.dart').readAsStringSync();

    test('the Video tab opens the vertical viewer, not the flat player', () {
      expect(tab, contains('ShortsViewerScreen('));
      expect(tab, isNot(contains('VideoPlayerScreen(')));
    });

    test('the tapped Short becomes the initial page', () {
      expect(tab, contains('initialIndex:'));
    });

    test('the Video tab carries no Live TV — that lives on Home', () {
      expect(tab, isNot(contains('_liveStreams')));
      expect(tab, isNot(contains('getLiveNews')));
      expect(tab, isNot(contains('LiveNewsScreen')));
    });

    test('no Short is consumed as a fake featured live item', () {
      expect(tab, isNot(contains('video: featuredVideo')));
      expect(tab, isNot(contains('On air now')));
    });

    test('Home still carries Live TV in the Breaking News hero', () {
      final home = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      expect(home, contains('HeroCardItem.live('));
      expect(home, contains('isLiveActive'));
      expect(home, contains('LiveNewsScreen()'));
    });

    test('the viewer reuses the existing pager and player', () {
      final src =
          File('lib/screens/shorts_viewer_screen.dart').readAsStringSync();
      expect(src, contains('FlipPageView'));
      expect(src, contains('VideoPlayerWidget'));
      expect(src, contains('isShort: true'));
    });

    test('controllers are bounded, not one per Short', () {
      final src =
          File('lib/screens/shorts_viewer_screen.dart').readAsStringSync();
      expect(src, contains('_controllers.remove'));
      expect(src, contains('dispose()'));
    });
  });

  group('the Video tab is the Reels viewer', () {
    final tab = File('lib/screens/video_tab.dart').readAsStringSync();
    final viewer =
        File('lib/screens/shorts_viewer_screen.dart').readAsStringSync();

    test('the tab renders the fullscreen viewer', () {
      expect(tab, contains('ShortsViewerScreen('));
      expect(tab, contains('isActive: widget.isActive'));
    });

    test('it hides the back button, since the bar is the way out', () {
      expect(tab, contains('showBackButton: false'));
    });

    test('pagination is handed to the viewer', () {
      expect(tab, contains('hasMore: _hasMore'));
      expect(tab, contains('onLoadMore:'));
    });
  });

  group('nothing plays outside the tab', () {
    final viewer =
        File('lib/screens/shorts_viewer_screen.dart').readAsStringSync();

    test('no controller is built while inactive', () {
      final fn = viewer.substring(viewer.indexOf('void _syncControllers()'));
      expect(fn.substring(0, 300), contains('if (!widget.isActive) return;'));
    });

    test('initState does not start playback when inactive', () {
      expect(viewer, contains('if (widget.isActive) _syncControllers();'));
    });

    test('leaving the tab releases the player, not just pauses it', () {
      // A backgrounded Short holding a webview is how audio keeps running
      // somewhere the reader cannot see it.
      expect(viewer, contains('if (oldWidget.isActive && !widget.isActive)'));
      expect(viewer, contains('_releaseAll()'));
      final release = viewer.substring(viewer.indexOf('void _releaseAll()'));
      expect(release.substring(0, 300), contains('c.pause()'));
      expect(release.substring(0, 300), contains('c.dispose()'));
    });

    test('returning to the tab starts the visible Short again', () {
      expect(viewer, contains('if (!oldWidget.isActive && widget.isActive)'));
    });
  });

  group('swiping hands playback to the new Short', () {
    final viewer =
        File('lib/screens/shorts_viewer_screen.dart').readAsStringSync();

    test('only the visible index keeps a controller', () {
      final fn = viewer.substring(viewer.indexOf('void _syncControllers()'));
      final body = fn.substring(0, 900);
      expect(body, contains('if (index != _current)'));
      expect(body, contains('_controllers.remove(index)?.dispose()'));
    });

    test('a page change re-syncs, so the old one stops', () {
      final fn = viewer.substring(viewer.indexOf('void _onPageChanged('));
      expect(fn.substring(0, 600), contains('_syncControllers()'));
    });

    test('more load before the reader hits the end', () {
      final fn = viewer.substring(viewer.indexOf('void _onPageChanged('));
      expect(fn.substring(0, 600), contains('widget.shorts.length - 3'));
    });

    test('a loading page is appended while more are coming', () {
      expect(viewer,
          contains('widget.shorts.length + (widget.hasMore ? 1 : 0)'));
    });
  });
}
