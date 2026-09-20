import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/widgets/watermark/article_watermark_overlay.dart';

void main() {
  group('ArticleWatermarkOverlay', () {
    testWidgets('renders on landscape dimensions without overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 675,
              child: ArticleWatermarkOverlay(
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      );

      expect(find.text('VAARADHI'), findsOneWidget);
      expect(find.byType(RotatedBox), findsOneWidget);
      final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
      expect(rotatedBox.quarterTurns, 3); // 270° clockwise = 90° bottom-to-top

      // Two marks now: the corner logo and the masthead band across the
      // foot. The corner one alone was nearly invisible at its clamped
      // opacity, so a reposted image carried no readable attribution.
      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => (w.image as AssetImage).assetName)
          .toList();
      expect(assets, contains('assets/images/logo.png'));
      expect(assets, contains('assets/images/watermark_banner.png'));
    });

    testWidgets('renders on portrait dimensions without overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: ArticleWatermarkOverlay(
                child: ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      );

      expect(find.text('VAARADHI'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('renders on square dimensions without overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 500,
              child: ArticleWatermarkOverlay(
                child: ColoredBox(color: Colors.grey),
              ),
            ),
          ),
        ),
      );

      expect(find.text('VAARADHI'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('respects opacity constraints (0.15-0.25 logo, 0.08-0.15 text)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ArticleWatermarkOverlay(
                logoOpacity: 0.20,
                textOpacity: 0.12,
              ),
            ),
          ),
        ),
      );

      final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
      expect(opacities.length, greaterThanOrEqualTo(2));

      // Check text opacity is within [0.08, 0.15]
      final textOpacityWidget = opacities.firstWhere(
        (o) => o.child is Text || o.child is RotatedBox || o.opacity <= 0.15,
      );
      expect(textOpacityWidget.opacity, inInclusiveRange(0.08, 0.15));

      // Check logo opacity is within [0.15, 0.25]
      final logoOpacityWidget = opacities.firstWhere(
        (o) => o.child is Image,
      );
      expect(logoOpacityWidget.opacity, inInclusiveRange(0.15, 0.25));
    });

    testWidgets('works as an overlay without child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: Stack(
                children: [
                  ColoredBox(color: Colors.red),
                  Positioned.fill(child: ArticleWatermarkOverlay()),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('VAARADHI'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
    });
  });
}
