import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/widgets/watermark/watermark_banner.dart';

void main() {
  group('the banner is one widget, defined once', () {
    testWidgets('it renders the masthead asset', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: WatermarkBanner())));
      final img = tester.widget<Image>(find.byType(Image));
      expect((img.image as AssetImage).assetName,
          'assets/images/watermark_banner.png');
    });

    testWidgets('it keeps the artwork ratio when given no height',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: WatermarkBanner())));
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
      // 1162x215 — laid out at its own shape rather than squeezed.
      expect(ar.aspectRatio, closeTo(1162 / 215, 0.001));
    });

    testWidgets('a fixed height wins when supplied', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: WatermarkBanner(height: 26))));
      expect(find.byType(AspectRatio), findsNothing);
      expect(
          tester.widget<SizedBox>(find.byType(SizedBox).first).height, 26);
    });

    test('the asset exists and is a real png', () {
      final f = File('assets/images/watermark_banner.png');
      expect(f.existsSync(), isTrue);
      expect(f.readAsBytesSync().sublist(1, 4), [0x50, 0x4E, 0x47]);
    });
  });

  group('it sits between the media and the story', () {
    test('on the spotlight card', () {
      final src = File('lib/widgets/spotlight/spotlight_news_card.dart')
          .readAsStringSync();
      final banner = src.indexOf('WatermarkBanner(');
      expect(banner, greaterThan(src.indexOf('height: mediaHeight')),
          reason: 'after the media slot');
      expect(banner, lessThan(src.indexOf('article.title')),
          reason: 'before the headline');
    });

    test('on the article detail screen', () {
      final src =
          File('lib/screens/news_detail_screen.dart').readAsStringSync();
      expect(src.indexOf('WatermarkBanner('),
          lessThan(src.indexOf('article.title,')));
    });
  });

  group('a shared image carries the masthead', () {
    final overlay =
        File('lib/widgets/watermark/article_watermark_overlay.dart')
            .readAsStringSync();

    test('the band is drawn across the foot', () {
      expect(overlay, contains('WatermarkBanner('));
    });

    test('it sits on a scrim so it reads on any artwork', () {
      expect(overlay, contains('LinearGradient'));
    });

    test('the corner logo is still there too', () {
      expect(overlay, contains('assets/images/logo.png'));
    });
  });

  group('a video download still produces something branded', () {
    final share = File('lib/utils/share_service.dart').readAsStringSync();

    test('the control is offered for video stories', () {
      final fn = share.substring(share.indexOf('static bool canGeneratePoster'));
      expect(fn.substring(0, 600), contains('article.isVideo'));
    });

    test('a missing still falls back to the black card', () {
      expect(share, contains('_buildWatermarkOnlyFile'));
    });

    test('that card is black and carries the banner', () {
      final fn =
          share.substring(share.indexOf('_buildWatermarkOnlyFile(NewsArticle'));
      final body = fn.substring(0, 1200);
      expect(body, contains('color: Colors.black'));
      expect(body, contains('WatermarkBanner('));
    });

    test('it is still written as a png', () {
      final fn =
          share.substring(share.indexOf('_buildWatermarkOnlyFile(NewsArticle'));
      expect(fn.substring(0, 1600), contains('.png'));
    });
  });
}
