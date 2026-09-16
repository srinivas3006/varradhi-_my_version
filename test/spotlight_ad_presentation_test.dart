import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/ads/ad_event_queue.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/widgets/ads/sponsored_spotlight_ad_card.dart';

AdBanner _ad({String image = 'https://cdn.example.com/creative.jpg'}) =>
    AdBanner.fromJson({
      'id': 'ad-1',
      'title': 'Homeocare International',
      'image_url': image,
      'destination_url': 'https://example.com',
      'ad_type': 'full_screen',
      'duration_seconds': 5,
    });

Future<void> _pump(WidgetTester tester, AdBanner ad) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SponsoredSpotlightAdCard(
          ad: ad,
          active: true,
          placementZone: 'feed',
          onClose: () {},
        ),
      ),
    ),
  );
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

void main() {
  group('the creative is never cropped', () {
    testWidgets('a full-screen ad is contained, not covered', (tester) async {
      await _pump(tester, _ad());

      final fits = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.fit)
          .toList();

      expect(fits, contains(BoxFit.contain),
          reason: 'the creative itself must show whole — its phone number '
              'and CTA sit near the edges');
      expect(fits, contains(BoxFit.cover),
          reason: 'the blurred backdrop still covers, to fill the letterbox');

      await _teardown(tester);
    });

    testWidgets('no backdrop is drawn when there is no creative',
        (tester) async {
      await _pump(tester, _ad(image: ''));
      expect(find.byType(ImageFiltered), findsNothing);
      await _teardown(tester);
    });
  });

  group('ad disclosure', () {
    testWidgets('is present and reads "Ad"', (tester) async {
      await _pump(tester, _ad());
      expect(find.text('Ad'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('survives a creative that fails to load', (tester) async {
      // A broken image must not take the disclosure with it.
      await _pump(tester, _ad(image: 'https://cdn.example.com/missing.jpg'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ad'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('sits above the creative in paint order', (tester) async {
      await _pump(tester, _ad());

      final stack = tester.widget<Stack>(find.byType(Stack).first);
      final labelIndex = stack.children.indexWhere(
        (w) => find
            .descendant(of: find.byWidget(w), matching: find.text('Ad'))
            .evaluate()
            .isNotEmpty,
      );
      expect(labelIndex, greaterThan(0),
          reason: 'a creative must never be able to paint over the label');

      await _teardown(tester);
    });
  });
}
