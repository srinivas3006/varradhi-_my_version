import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/widgets/watermark/watermark_banner.dart';

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
      // 1600x296 — laid out at its own shape rather than squeezed.
      expect(ar.aspectRatio, closeTo(1600 / 296, 0.001));
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
    test('on the spotlight card, the mark is overlaid on the media', () {
      // The card carries a faint rotated wordmark instead of the band, so it
      // must land in the media slot. (The logo avatar was removed to keep
      // the photo clean.)
      final src = File('lib/widgets/spotlight/spotlight_news_card.dart')
          .readAsStringSync();
      final media = src.indexOf('height: mediaHeight');
      final title = src.indexOf('article.title');
      for (final mark in ["'VAARADHI'"]) {
        final at = src.indexOf(mark);
        expect(at, greaterThan(media), reason: '$mark after the media slot');
        expect(at, lessThan(title), reason: '$mark before the headline');
      }
    });

    test('not on the article detail screen', () {
      // The masthead belongs on shared and downloaded images, not on the
      // reading screen.
      final src =
          File('lib/screens/news_detail_screen.dart').readAsStringSync();
      expect(src, isNot(contains('WatermarkBanner(')));
    });
  });

  group('exactly one mark per surface', () {
    // The overlay drew a corner logo AND rotated text; stacking the banner
    // on top of it meant three marks on one card.
    String code(String path) => File(path)
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    const bannerSurfaces = [
      'lib/widgets/spotlight/spotlight_news_card.dart',
      'lib/screens/news_detail_screen.dart',
      'lib/widgets/news_article_video_player.dart',
      'lib/widgets/article_media_carousel.dart',
    ];

    for (final path in bannerSurfaces) {
      test('${path.split('/').last} carries no floating overlay', () {
        expect(code(path), isNot(contains('ArticleWatermarkOverlay(')),
            reason: 'the banner is the watermark on this surface');
      });
    }

    test('the spotlight card has one wordmark, no logo, no band', () {
      final card = code(bannerSurfaces[0]);
      expect("'VAARADHI'".allMatches(card).length, 1);
      expect(card, isNot(contains('logo.png')));
      expect(card, isNot(contains('WatermarkBanner(')));
    });

    test('the detail screen has no banner', () {
      expect('WatermarkBanner('.allMatches(code(bannerSurfaces[1])).length, 0);
    });

    test('the overlay itself no longer draws a band', () {
      final overlay =
          code('lib/widgets/watermark/article_watermark_overlay.dart');
      expect(overlay, isNot(contains('WatermarkBanner(')));
    });

    test('each generated image carries a single banner', () {
      final share = code('lib/utils/share_service.dart');
      // The photo image paints the banner asset straight onto its canvas;
      // only the black no-image fallback card lays out the widget.
      expect("'assets/images/watermark_banner.png'".allMatches(share).length,
          1);
      expect('WatermarkBanner('.allMatches(share).length, 1);
      expect(share, isNot(contains('ArticleWatermarkOverlay(')));
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
