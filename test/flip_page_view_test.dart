import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/widgets/flip_page_view.dart';
import 'package:way2news_clone/models/spotlight_item.dart';

void main() {
  group('FlipPageView transition maths', () {
    test('a settled card gets no scale, so text is never on a scaled layer', () {
      expect(FlipPageView.incomingScaleAt(0), 1.0);
    });

    test('the incoming card starts slightly small and settles to natural size', () {
      final atStart = FlipPageView.incomingScaleAt(1.0);
      expect(atStart, lessThan(1.0));
      expect(atStart, greaterThan(0.95),
          reason: 'scale is a finishing touch, not the effect');
      expect(FlipPageView.incomingScaleAt(1.0),
          lessThan(FlipPageView.incomingScaleAt(0.5)));
    });

    test('tilt is barely perceptible', () {
      expect(FlipPageView.maxTiltDegrees, lessThan(2.0));
      expect(FlipPageView.tiltAt(0), 0.0);
      expect(FlipPageView.tiltAt(1), greaterThan(0));
    });

    test('scrim deepens as the outgoing card leaves', () {
      expect(FlipPageView.scrimAt(0), 0.0);
      expect(FlipPageView.scrimAt(1), greaterThan(FlipPageView.scrimAt(0.5)));
      expect(FlipPageView.scrimAt(1), lessThanOrEqualTo(1.0));
    });

    test('the incoming card lags the pager, which is what reveals it', () {
      expect(FlipPageView.revealLagAt(0, 800), 0.0);
      expect(FlipPageView.revealLagAt(1, 800), greaterThan(0));
    });

    test('progress beyond the gesture is clamped', () {
      expect(FlipPageView.scrimAt(5), FlipPageView.scrimAt(1));
      expect(FlipPageView.tiltAt(-3), FlipPageView.tiltAt(0));
    });
  });

  group('FlipPageView scrolls vertically on real physics', () {
    testWidgets('it is a vertical PageView with clamping physics', (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlipPageView(
              controller: controller,
              itemCount: 3,
              itemBuilder: (context, i) => Center(child: Text('page $i')),
            ),
          ),
        ),
      );

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.scrollDirection, Axis.vertical);
      expect(pageView.physics, isA<ClampingScrollPhysics>());
      expect(find.text('page 0'), findsOneWidget);
    });

    testWidgets('a swipe advances the page', (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      var changed = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlipPageView(
              controller: controller,
              itemCount: 3,
              onPageChanged: (i) => changed = i,
              itemBuilder: (context, i) => Center(child: Text('page $i')),
            ),
          ),
        ),
      );

      await tester.fling(find.byType(PageView), const Offset(0, -400), 1200);
      await tester.pumpAndSettle();

      expect(changed, 1);
      expect(find.text('page 1'), findsOneWidget);
    });
  });


  testWidgets('pulling down past the first story triggers refresh',
      (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    var refreshed = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async => refreshed++,
          child: FlipPageView(
            controller: controller,
            itemCount: 3,
            itemBuilder: (context, i) => Center(child: Text('story $i')),
          ),
        ),
      ),
    ));

    await tester.fling(find.byType(PageView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(refreshed, 1);
  });
}
