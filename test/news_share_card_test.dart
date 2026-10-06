import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/utils/share_service.dart';
import 'package:vaaradhi/widgets/sharing/news_share_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('card text', () {
    test('summary first, else the body without HTML', () {
      final a = NewsArticle.fromJson({
        'id': '1',
        'title': 't',
        'summary': '',
        'content': '<p>తాండూరు:&nbsp;పట్టణంలో</p>  <b>నిమజ్జనం</b>',
      });
      expect(ShareService.shareSummary(a), 'తాండూరు: పట్టణంలో నిమజ్జనం');
    });

    test('meta is "category  |  date", no middle dot (font has none)', () {
      final a = NewsArticle.fromJson({
        'id': '1',
        'title': 't',
        'category': 'Weather',
        'published_at': '2026-10-06T09:00:00+05:30',
      });
      expect(ShareService.shareMeta(a), 'Weather  |  06 Oct 2026');
      expect(ShareService.shareMeta(a), isNot(contains('·')));
    });
  });

  group('card layout', () {
    Future<void> pump(WidgetTester tester, NewsShareCard card) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: card))));
    }

    testWidgets('photo, headline, summary, then the brand strip',
        (tester) async {
      final photo = Uint8List.fromList(
          img.encodePng(img.Image(width: 40, height: 30)));
      await pump(
          tester,
          NewsShareCard(
            headline: 'తెలుగు రాష్ట్రాల్లో భారీ వర్షాలు',
            summary: 'వాతావరణ శాఖ హెచ్చరించింది.',
            meta: 'Weather  |  06 Oct 2026',
            photo: photo,
          ));
      final y = {
        for (final k in [
          'share_card_photo',
          'share_card_headline',
          'share_card_summary',
          'share_card_brand'
        ])
          k: tester.getTopLeft(find.byKey(Key(k))).dy,
      };
      expect(y['share_card_photo']! < y['share_card_headline']!, isTrue);
      expect(y['share_card_headline']! < y['share_card_summary']!, isTrue);
      expect(y['share_card_summary']! < y['share_card_brand']!, isTrue);
      expect(tester.getSize(find.byType(NewsShareCard)).width, 1080);
    });

    testWidgets('no photo: still a full card, not a black box',
        (tester) async {
      await pump(
          tester,
          const NewsShareCard(
              headline: 'గణేష్ నిమజ్జనం', summary: 's', meta: ''));
      expect(find.byKey(const Key('share_card_photo')), findsNothing);
      expect(find.byKey(const Key('share_card_headline')), findsOneWidget);
      expect(find.byKey(const Key('share_card_brand')), findsOneWidget);
    });
  });
}
