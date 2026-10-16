import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

/// [n] letters of story: words "abcd" (4 letters + space = 5 each).
String _letters(int n) {
  final b = StringBuffer();
  var i = 0;
  while (b.length < n) {
    b.write(i % 5 == 4 ? ' ' : String.fromCharCode(0x61 + i % 5));
    i++;
  }
  return b.toString().trim();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('400–500 letter excerpt (what an ordinary counter shows)', () {
    test('500 letters or fewer: whole story, not truncated', () {
      final text = _letters(495);
      final e = SpotlightNewsCard.storyExcerpt(text);
      expect(e.truncated, isFalse);
      expect(e.text, text);
    });

    test('longer: cut at a word between 400 and 500 letters, with "…"', () {
      final e = SpotlightNewsCard.storyExcerpt(_letters(1500));
      expect(e.truncated, isTrue);
      expect(e.text.endsWith('…'), isTrue);
      expect(e.text.length - 1, inInclusiveRange(400, 500));
      expect(e.text, isNot(contains(' …')));
    });

    test('prefers ending on a full sentence inside the range', () {
      final text = '${_letters(450)}. ${_letters(900)}';
      final e = SpotlightNewsCard.storyExcerpt(text);
      expect(e.truncated, isTrue);
      expect(e.text, '${_letters(450)}.');
    });

    test('a sentence end before 400 letters is not used', () {
      final text = '${_letters(100)}. ${_letters(1200)}';
      final e = SpotlightNewsCard.storyExcerpt(text);
      expect(e.text.length, greaterThanOrEqualTo(400));
    });

    test('Telugu: about 60 words fit; a cluster is never split', () {
      final sixty = List.filled(60, 'వార్త').join(' '); // 359 letters
      expect(SpotlightNewsCard.storyExcerpt(sixty).truncated, isFalse);
      final long = List.filled(150, 'రాష్ట్రంలో').join(' ');
      final e = SpotlightNewsCard.storyExcerpt(long);
      expect(e.truncated, isTrue);
      expect(
          e.text.replaceAll('…', '').split(' ').every((w) => w == 'రాష్ట్రంలో'),
          isTrue);
    });

    test('type is exactly proportional to the screen width', () {
      expect(SpotlightNewsCard.typeScale(392), 1.0);
      expect(SpotlightNewsCard.typeScale(360), closeTo(360 / 392, 1e-9));
      expect(SpotlightNewsCard.typeScale(450), closeTo(450 / 392, 1e-9));
    });

    test('fitting: largest size that fits, within the allowed band', () {
      // Fits up to 19.0.
      final s = SpotlightNewsCard.fitBodySize(base: 18.5, fits: (x) => x <= 19);
      expect(s, lessThanOrEqualTo(19));
      expect(s, greaterThan(18.9));
      // Room to spare: grows only to the band's top.
      expect(SpotlightNewsCard.fitBodySize(base: 18.5, fits: (_) => true),
          closeTo(18.5 * SpotlightNewsCard.fitGrow, 1e-9));
      // Nothing fits: the band's bottom (the card then shows "…").
      expect(SpotlightNewsCard.fitBodySize(base: 18.5, fits: (_) => false),
          closeTo(18.5 * SpotlightNewsCard.fitShrink, 1e-9));
    });
  });

  group('Read more on the card', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppState.instance.language = 'Telugu';
    });

    Future<void> pump(WidgetTester tester, String body) async {
      // A tall screen: here only the letter limit decides Read more.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpotlightNewsCard(
            article: NewsArticle.fromJson({
              'id': 'w1',
              'title': 'శీర్షిక',
              'summary': body,
              'content': body,
              'feed_item_type': 'ugc', // no detail fetch in tests
              'published_at': DateTime.now().toIso8601String(),
            }),
            isCurrent: true,
            onTap: () {},
            onShare: () {},
            onClose: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    }

    testWidgets('a short story: no Read more', (tester) async {
      await pump(tester, _letters(300));
      expect(find.byKey(const Key('vaaradhi_logo_badge')), findsOneWidget);
      expect(find.text('ఇంకా చదవండి'), findsNothing);
      await done(tester);
    });

    testWidgets('a long story: excerpt and Read more', (tester) async {
      await pump(tester, '${_letters(1400)} ENDMARK');
      expect(find.text('ఇంకా చదవండి'), findsOneWidget);
      expect(find.textContaining('ENDMARK', findRichText: true), findsNothing);
      expect(find.textContaining('…', findRichText: true), findsOneWidget);
      await done(tester);
    });

    testWidgets('system font size does not change the card text',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Future<double> headlineHeight(double scale) async {
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(
              size: const Size(540, 2000),
              textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            home: Scaffold(
              body: SpotlightNewsCard(
                article: NewsArticle.fromJson({
                  'id': 'w2',
                  'title': 'శీర్షిక శీర్షిక శీర్షిక',
                  'content': _letters(200),
                  'feed_item_type': 'ugc',
                  'published_at': DateTime.now().toIso8601String(),
                }),
                onTap: () {},
                onShare: () {},
                onClose: () {},
              ),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        return tester.getSize(find.text('శీర్షిక శీర్షిక శీర్షిక')).height;
      }

      final normal = await headlineHeight(1.0);
      final large = await headlineHeight(1.3);
      expect(large, normal);
      await done(tester);
    });
  });
}
