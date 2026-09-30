import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/widgets/flip_page_view.dart';

void main() {
  group('FlipPageView transition maths', () {
    test('a settled card is not moved', () {
      expect(FlipPageView.parallaxAt(0, 800), 0.0);
      expect(FlipPageView.scrimAt(0), 0.0);
    });

    test('no background gap opens between the cards mid-swipe', () {
      // Pager positions at progress p (screen coords, page height h):
      //   outgoing bottom = h - p*h + parallax
      //   incoming top    = h - p*h
      // The outgoing card must always reach down to the incoming one.
      const h = 800.0;
      for (var p = 0.0; p <= 1.0; p += 0.05) {
        final outgoingBottom = h - p * h + FlipPageView.parallaxAt(p, h);
        final incomingTop = h - p * h;
        expect(outgoingBottom, greaterThanOrEqualTo(incomingTop),
            reason: 'progress $p');
      }
    });

    test('the outgoing card drifts slower than the page', () {
      const h = 800.0;
      final netTravel = h - FlipPageView.parallaxAt(1, h);
      expect(netTravel, greaterThan(0));
      expect(netTravel, lessThan(h));
    });

    test('scrim deepens as the outgoing card is covered', () {
      expect(FlipPageView.scrimAt(1), greaterThan(FlipPageView.scrimAt(0.5)));
      expect(FlipPageView.scrimAt(1), lessThanOrEqualTo(1.0));
    });

    test('the incoming shadow is gone by the time the card lands', () {
      expect(FlipPageView.shadowAt(0), 0.0);
      expect(FlipPageView.shadowAt(0.5), greaterThan(0));
      expect(FlipPageView.shadowAt(0.05), lessThan(FlipPageView.shadowAt(0.5)));
    });

    test('progress beyond the gesture is clamped', () {
      expect(FlipPageView.scrimAt(5), FlipPageView.scrimAt(1));
      expect(FlipPageView.parallaxAt(-3, 800), 0.0);
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
