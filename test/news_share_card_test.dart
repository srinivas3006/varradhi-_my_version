import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/utils/share_service.dart';
import 'package:vaaradhi/widgets/sharing/news_share_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('meta is "category  |  date" from the article data', () {
    final a = NewsArticle.fromJson({
      'id': '1',
      'title': 't',
      'category': 'Sports',
      'published_at': '2026-10-06T09:00:00+05:30',
    });
    expect(ShareService.shareMeta(a), 'Sports  |  06 Oct 2026');
    expect(ShareService.shareMeta(a), isNot(contains('·')));
  });

  test('4:3 at 1600×1200: photo 77%, strip 7%, text area the rest', () {
    expect(NewsShareCard.width / NewsShareCard.height, closeTo(4 / 3, 1e-9));
    expect(NewsShareCard.photoHeight, closeTo(924, 0.01));
    expect(NewsShareCard.stripHeight, closeTo(84, 0.01));
    expect(NewsShareCard.textAreaMinHeight, closeTo(192, 0.01));
  });

  group('card layout', () {
    Future<void> pump(WidgetTester tester, NewsShareCard card) async {
      tester.view.physicalSize = const Size(1600, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: card))));
    }

    testWidgets('photo → black strip → category row → headline',
        (tester) async {
      final photo =
          Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30)));
      await pump(
          tester,
          NewsShareCard(
            // Short: test fonts are wider than the real Ramabhadra.
            headline: 'Gold',
            meta: 'Sports  |  06 Oct 2026',
            photo: photo,
          ));
      double top(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      expect(top('share_card_photo'), 0);
      expect(top('share_card_brand'), closeTo(924, 0.5));
      expect(top('share_card_text_area'), closeTo(1008, 0.5));
      expect(top('share_card_meta') < top('share_card_headline'), isTrue);
      expect(
          tester.getSize(find.byType(NewsShareCard)), const Size(1600, 1200));
      // Watermark on the photo, reading bottom → top.
      expect(
          tester
              .widget<RotatedBox>(find.byKey(const Key('share_card_watermark')))
              .quarterTurns,
          3);
      // Logo, category row and headline share one left edge.
      final left =
          tester.getTopLeft(find.byKey(const Key('share_card_meta'))).dx;
      expect(left, NewsShareCard.sidePadding);
      expect(tester.getTopLeft(find.byKey(const Key('share_card_headline'))).dx,
          left);
    });

    testWidgets('a long headline makes the card taller, never cut',
        (tester) async {
      await pump(
          tester,
          NewsShareCard(
            headline: 'తెలుగు రాష్ట్రాల్లో ' * 20,
            meta: 'Weather  |  06 Oct 2026',
          ));
      final text =
          tester.widget<Text>(find.byKey(const Key('share_card_headline')));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.getSize(find.byType(NewsShareCard)).height,
          greaterThan(NewsShareCard.height));
    });

    testWidgets('no photo: the branded placeholder fills the photo area',
        (tester) async {
      await pump(
          tester, const NewsShareCard(headline: 'గణేష్ నిమజ్జనం', meta: ''));
      expect(find.byKey(const Key('share_card_placeholder')), findsOneWidget);
      expect(tester.getSize(find.byType(NewsShareCard)).height,
          NewsShareCard.height);
    });

    testWidgets('download: story text sits under the headline', (tester) async {
      await pump(
          tester,
          const NewsShareCard(
            headline: 'Gold',
            meta: 'Sports  |  06 Oct 2026',
            summary: 'హైదరాబాద్: ఆసియా క్రీడల్లో రెండు బంగారు పతకాలు',
          ));
      final head =
          tester.getTopLeft(find.byKey(const Key('share_card_headline')));
      final body =
          tester.getTopLeft(find.byKey(const Key('share_card_summary')));
      expect(body.dy, greaterThan(head.dy));
      expect(body.dx, head.dx, reason: 'same left edge');
      final text =
          tester.widget<Text>(find.byKey(const Key('share_card_summary')));
      expect(text.maxLines, 8);
      expect(text.style!.fontSize, 50, reason: 'readable on a phone');
    });

    testWidgets('share: no story text', (tester) async {
      await pump(
          tester,
          const NewsShareCard(
              headline: 'Gold', meta: 'Sports  |  06 Oct 2026'));
      expect(find.byKey(const Key('share_card_summary')), findsNothing);
    });

    testWidgets('no red banner and no tagline any more', (tester) async {
      await pump(tester,
          const NewsShareCard(headline: 'h', meta: 'Sports  |  06 Oct 2026'));
      expect(find.textContaining('ప్రతి వార్త'), findsNothing);
      expect(find.text('వారధి'), findsOneWidget); // the strip wordmark
    });
  });

  group('download is a tall portrait card with large text', () {
    test('1080 wide, at least 4:5, photo 4:3 on top', () {
      expect(NewsShareCard.portraitWidth, 1080);
      expect(NewsShareCard.portraitMinHeight / NewsShareCard.portraitWidth,
          closeTo(1.25, 1e-9));
      expect(NewsShareCard.portraitPhotoHeight, closeTo(810, 0.01));
      expect(NewsShareCard.portraitTextAreaMinHeight, closeTo(444, 0.01));
    });

    Future<void> pumpPortrait(WidgetTester tester, NewsShareCard card) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: card))));
    }

    testWidgets('portrait layout: taller than wide, story text large',
        (tester) async {
      await pumpPortrait(
          tester,
          const NewsShareCard(
            headline: 'Gold',
            meta: 'Cinema  |  08 Oct 2026',
            summary: 'Story text',
            portrait: true,
          ));
      final size = tester.getSize(find.byType(NewsShareCard));
      expect(size.width, 1080);
      expect(size.height, greaterThanOrEqualTo(1350));
      expect(size.height, greaterThan(size.width), reason: 'vertical');

      double top(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      expect(top('share_card_brand'), closeTo(810, 0.5));
      expect(top('share_card_text_area'), closeTo(906, 0.5));

      final summary =
          tester.widget<Text>(find.byKey(const Key('share_card_summary')));
      expect(summary.maxLines, NewsShareCard.portraitSummaryMaxLines);
      // 46 px on a 1080 px card is ~1.5× the landscape card's 50 px on 1600.
      expect(summary.style!.fontSize! / 1080, greaterThan(50 / 1600 * 1.3));
      final headline =
          tester.widget<Text>(find.byKey(const Key('share_card_headline')));
      expect(headline.style!.fontSize, 60);
    });

    test('Download asks for the portrait card, Share for landscape', () {
      final src = File('lib/utils/share_service.dart').readAsStringSync();
      expect(src, contains('portrait: forDownload'));
      expect(src, contains('width: cardWidget.cardWidth'));
    });
  });
}
