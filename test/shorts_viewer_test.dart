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
}
