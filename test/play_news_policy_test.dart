import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/screens/news_detail_screen.dart' show publishedLine;
import 'package:vaaradhi/widgets/cms_contact_actions.dart';

/// Google Play News & Magazines policy (version code 12 was rejected):
/// a visible Contact Us with real email and phone, and a publishing source
/// on every story.
void main() {
  group('every story names its source', () {
    NewsArticle desk({String author = ''}) => NewsArticle.fromJson({
          'id': '1',
          'title': 't',
          'type': 'article',
          if (author.isNotEmpty) 'author_name': author,
        });
    NewsArticle ugc({String? uploader}) => NewsArticle.fromJson({
          'id': '2',
          'title': 't',
          'type': 'ugc',
          if (uploader != null) 'uploader': {'full_name': uploader},
        });

    test('desk story without author: Vaaradhi Telugu News', () {
      expect(desk().attributionLine(telugu: false),
          'Source: Vaaradhi Telugu News');
      expect(desk().attributionLine(telugu: true), 'మూలం: వారధి తెలుగు న్యూస్');
    });

    test('desk story with author: source and author', () {
      expect(desk(author: 'Ravi Kumar').attributionLine(telugu: false),
          'Source: Vaaradhi Telugu News · Author: Ravi Kumar');
    });

    test('citizen post: Citizen Reporter and uploader', () {
      expect(ugc(uploader: 'Chandrakanth reddy').attributionLine(telugu: false),
          'Source: Citizen Reporter · Uploader: Chandrakanth reddy');
      expect(ugc().attributionLine(telugu: false), 'Source: Citizen Reporter');
    });

    test('the desk placeholder is never shown as a person', () {
      expect(desk(author: 'Vaaradhi Desk').attributionLine(telugu: false),
          'Source: Vaaradhi Telugu News');
    });
  });

  group('third-party stories name their real source', () {
    NewsArticle ext({String name = 'Eenadu', String author = ''}) =>
        NewsArticle.fromJson({
          'id': '3',
          'title': 't',
          'type': 'article',
          'source_url': 'https://www.eenadu.net/story/1',
          'source_name': name,
          if (author.isNotEmpty) 'author_name': author,
        });

    test('source_url present: source_name is the publisher', () {
      final a = ext();
      expect(a.isExternal, isTrue);
      expect(a.attributionLine(telugu: false), 'Source: Eenadu');
      expect(a.attributionLine(telugu: true), 'మూలం: Eenadu');
    });

    test('never shown as Vaaradhi', () {
      expect(ext().attributionLine(telugu: false), isNot(contains('Vaaradhi')));
    });

    test('no source_name: the link' 's website is the publisher', () {
      expect(
          ext(name: '').attributionLine(telugu: false), 'Source: eenadu.net');
    });

    test('the outlet is not repeated as the author', () {
      expect(ext(author: 'Eenadu').attributionLine(telugu: false),
          'Source: Eenadu');
      expect(ext(author: 'Ramesh').attributionLine(telugu: false),
          'Source: Eenadu · Author: Ramesh');
    });

    test('home items carry source fields under metadata', () {
      final a = NewsArticle.fromJson({
        'id': '4',
        'type': 'article',
        'title': 't',
        'metadata': {
          'source_url': 'https://x.com/a',
          'source_name': 'Sakshi',
        },
      });
      expect(a.sourceLabel(telugu: false), 'Sakshi');
    });
  });

  group('the article screen shows the exact publish time', () {
    test('English and Telugu', () {
      final t = DateTime(2026, 10, 12, 15, 55);
      expect(
          publishedLine(t, telugu: false), 'Published: 12 Oct 2026, 3:55 PM');
      expect(
          publishedLine(t, telugu: true), 'ప్రచురణ: 12 అక్టోబర్ 2026, 3:55 PM');
      expect(publishedLine(DateTime(2026, 1, 3, 0, 5), telugu: false),
          'Published: 3 Jan 2026, 12:05 AM');
    });

    test('detail shows source, date and the original link', () {
      final src =
          File('lib/screens/news_detail_screen.dart').readAsStringSync();
      expect(src, contains('article_source'));
      expect(src, contains('article_published'));
      expect(src, contains('article_original_source'));
    });
  });

  group('Contact Us: contacts come from the CMS page, never the app', () {
    // A sample page as an admin might write it — the values are test data.
    const html = '''
<h1>Contact Us</h1>
<p>Email: <a href="mailto:help@example.com">help@example.com</a></p>
<p>Phone: +91 98765 43210</p>
<p>Office: 040 2345 6789</p>
<p>Website: <a href="https://example.com">example.com</a></p>
<p>Follow us: <a href="https://facebook.com/x">Facebook</a>
   <a href="https://wa.me/919876543210">WhatsApp</a></p>
<p>Founded 2026. Pincode 500001.</p>
''';

    test('email, phones and website are read from the HTML', () {
      final c = CmsContacts.fromHtml(html);
      expect(c.emails, ['help@example.com']);
      expect(c.phones, ['+91 98765 43210', '040 2345 6789']);
      expect(c.websites, ['https://example.com']);
    });

    test('social and WhatsApp links are not offered as a contact', () {
      final c = CmsContacts.fromHtml(html);
      expect(c.websites.any((w) => w.contains('facebook')), isFalse);
      expect(c.websites.any((w) => w.contains('wa.me')), isFalse);
    });

    test('years and pincodes are not mistaken for phone numbers', () {
      final c = CmsContacts.fromHtml('<p>Since 2026, PIN 500001</p>');
      expect(c.phones, isEmpty);
    });

    test('a tel: link counts, and one number is not listed twice', () {
      final c = CmsContacts.fromHtml(
          '<a href="tel:+919876543210">+91 98765 43210</a>');
      expect(c.phones.length, 1);
    });

    testWidgets('the actions show what the page lists, and nothing else',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CmsContactActions(html: html)),
        ),
      ));
      expect(find.text('help@example.com'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
    });

    testWidgets('a page without contacts shows no actions', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CmsContactActions(html: '<p>Hello</p>')),
      ));
      expect(find.byKey(const Key('cms_contact_actions')), findsNothing);
    });

    test('no contact details are written into the app', () {
      for (final f in [
        'lib/core/config/app_config.dart',
        'lib/screens/cms_page_screen.dart',
        'lib/widgets/cms_contact_actions.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, isNot(contains('@gmail.com')), reason: f);
        expect(src, isNot(contains('90140')), reason: f);
      }
      expect(File('lib/widgets/publisher_contact_card.dart').existsSync(),
          isFalse);
    });
  });
}
