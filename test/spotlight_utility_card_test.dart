import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/widgets/fit_or_scroll.dart';
import 'package:way2news_clone/models/spotlight_item.dart';

void main() {
  group('SpotlightType.isImmersiveStory', () {
    test('story cards are immersive, so chrome may fade', () {
      expect(SpotlightType.standard.isImmersiveStory, isTrue);
      expect(SpotlightType.ugc.isImmersiveStory, isTrue);
      expect(SpotlightType.carousel.isImmersiveStory, isTrue);
    });

    test('full-bleed media is immersive too, so chrome clears the creative', () {
      for (final t in [
        SpotlightType.ad,
        SpotlightType.poster,
      ]) {
        expect(t.isImmersiveStory, isTrue, reason: t.name);
      }
    });

    test('interactive cards keep their chrome', () {
      for (final t in [
        SpotlightType.poll,
        SpotlightType.infoCard,
        SpotlightType.shimmer,
      ]) {
        expect(t.isImmersiveStory, isFalse, reason: t.name);
      }
    });
  });

  group('FitOrScroll', () {
    Future<ScrollController> pump(WidgetTester tester, double childHeight) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: PrimaryScrollController(
                controller: controller,
                child: FitOrScroll(child: SizedBox(height: childHeight)),
              ),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('content that fits leaves no scroll extent, so the pager keeps the swipe',
        (tester) async {
      await pump(tester, 200);
      final scrollable = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollable.physics, isA<ClampingScrollPhysics>());

      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.maxScrollExtent, 0.0);
    });

    testWidgets('content taller than the viewport still scrolls', (tester) async {
      await pump(tester, 1200);
      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.maxScrollExtent, greaterThan(0.0));
    });

    testWidgets('padding is counted against the available height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: FitOrScroll(
                padding: EdgeInsets.symmetric(vertical: 100),
                child: SizedBox(height: 300),
              ),
            ),
          ),
        ),
      );
      // 300 child + 200 padding = 500, still under 600: nothing to scroll.
      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.maxScrollExtent, 0.0);
    });
  });
}
