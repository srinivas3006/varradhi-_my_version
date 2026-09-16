import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/ads/ad_event_queue.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/widgets/ads/breaking_strip_ad_widget.dart';
import 'package:way2news_clone/widgets/ads/bottom_sticky_ad_banner.dart';
import 'package:way2news_clone/widgets/ads/rotating_breaking_strip.dart';

AdBanner _ad(String id, {String? dest}) => AdBanner.fromJson({
      'id': id,
      'title': 'Ad $id',
      'image_url': '',
      'destination_url': dest ?? 'https://example.com/$id',
      'ad_type': 'breaking_strip',
    });

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topCenter, child: child))),
    );

/// Tears the tree down and clears the AdEventQueue singleton.
///
/// Mounting an ad enqueues an impression, and the queue retries on a backing
/// off timer (500ms, 2s, 4s...) that outlives the widget by design. Without
/// this the harness flags that service timer as a leak from the test.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // _processQueue is async, so a single reset can be followed by an in-flight
  // continuation scheduling a fresh retry. Drain and clear repeatedly until
  // nothing reschedules.
  for (var i = 0; i < 6; i++) {
    AdEventQueue.instance.reset();
    await tester.pump(const Duration(seconds: 5));
  }
  AdEventQueue.instance.reset();
  await tester.pump();
}

void main() {
  group('RotatingBreakingStrip', () {
    testWidgets('a single creative renders without starting a timer', (tester) async {
      await _pump(tester, RotatingBreakingStrip(ads: [_ad('a')]));
      expect(find.byType(BreakingStripAdWidget), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('an empty pool renders nothing', (tester) async {
      await _pump(tester, const RotatingBreakingStrip(ads: []));
      expect(find.byType(BreakingStripAdWidget), findsNothing);
      await _teardown(tester);
    });

    testWidgets('cycles to the next creative on the timer', (tester) async {
      await _pump(
        tester,
        RotatingBreakingStrip(
          ads: [_ad('a'), _ad('b')],
          rotateEvery: const Duration(seconds: 1),
        ),
      );

      BreakingStripAdWidget shown() =>
          tester.widgetList<BreakingStripAdWidget>(find.byType(BreakingStripAdWidget)).last;
      expect(shown().ad.id, 'a');

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(shown().ad.id, 'b');

      // Wraps around rather than running off the end.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(shown().ad.id, 'a');

      await _teardown(tester);
    });
  });

  group('clickability', () {
    testWidgets('strip does not ripple when there is nowhere to go', (tester) async {
      await _pump(tester, BreakingStripAdWidget(ad: _ad('a', dest: '')));
      expect(tester.widget<InkWell>(find.byType(InkWell).first).onTap, isNull);
      await _teardown(tester);
    });

    testWidgets('strip is tappable when it has a destination', (tester) async {
      await _pump(tester, BreakingStripAdWidget(ad: _ad('a')));
      expect(tester.widget<InkWell>(find.byType(InkWell).first).onTap, isNotNull);
      await _teardown(tester);
    });

    testWidgets('sticky banner does not ripple without a destination', (tester) async {
      await _pump(tester, BottomStickyAdBanner(ad: _ad('a', dest: '')));
      final fill = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(Stack),
          matching: find.byType(InkWell),
        ).first,
      );
      expect(fill.onTap, isNull);
      await _teardown(tester);
    });
  });

  group('sticky dismiss', () {
    testWidgets('dismiss hides the banner and reports it once', (tester) async {
      var dismissed = 0;
      await _pump(
        tester,
        BottomStickyAdBanner(ad: _ad('a'), onDismiss: () => dismissed++),
      );
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(dismissed, 1);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await _teardown(tester);
    });

    testWidgets('dismiss target meets the 48dp minimum', (tester) async {
      await _pump(tester, BottomStickyAdBanner(ad: _ad('a')));
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
      await _teardown(tester);
    });
  });
}
