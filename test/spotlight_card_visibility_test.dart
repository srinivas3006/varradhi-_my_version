import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/widgets/flip_page_view.dart';

/// Regression cover for the blank-screen bug.
///
/// Card opacity used to be derived from the pager's drag values:
///
///   textOpacity = isCurrent ? (1 - dragProgress) : dragProgress
///
/// Once FlipPageView took over the transition those values are always 0, so
/// any card that was not the settled one painted at opacity 0 — every story
/// after the first was a blank white screen. These assert the shape of the
/// fix: pages render regardless of which one is current.
void main() {
  Widget harness({required int itemCount, required PageController controller}) {
    return MaterialApp(
      home: Scaffold(
        body: FlipPageView(
          controller: controller,
          itemCount: itemCount,
          itemBuilder: (context, i) => Center(child: Text('story $i')),
        ),
      ),
    );
  }

  testWidgets('the neighbouring page is built and visible, not blank',
      (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(harness(itemCount: 5, controller: controller));

    // allowImplicitScrolling pre-builds the neighbour; it must not be
    // invisible while it is on screen.
    await tester.drag(find.byType(PageView), const Offset(0, -200));
    await tester.pump();

    expect(find.text('story 1'), findsOneWidget);
    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .where((o) => o.opacity == 0.0);
    expect(opacities, isEmpty,
        reason: 'nothing on screen mid-swipe may be fully transparent');

    await tester.pumpAndSettle();
  });

  testWidgets('every story is reachable and renders after settling',
      (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(harness(itemCount: 4, controller: controller));
    expect(find.text('story 0'), findsOneWidget);

    for (var i = 1; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(0, -400), 1200);
      await tester.pumpAndSettle();
      expect(find.text('story $i'), findsOneWidget,
          reason: 'story $i must render, not show blank');
    }
  });

  testWidgets('swiping back renders the earlier story again', (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(harness(itemCount: 3, controller: controller));
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1200);
    await tester.pumpAndSettle();
    expect(find.text('story 1'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, 400), 1200);
    await tester.pumpAndSettle();
    expect(find.text('story 0'), findsOneWidget);
  });
}
