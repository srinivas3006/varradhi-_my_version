import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

String _words(int n) => List.generate(n, (i) => 'పదం${i + 1}').join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('60-word excerpt', () {
    test('60 words or fewer: whole story, not truncated', () {
      final e = SpotlightNewsCard.wordExcerpt(_words(60));
      expect(e.truncated, isFalse);
      expect(e.text, _words(60));
    });

    test('61+ words: first 60 and "…"', () {
      final e = SpotlightNewsCard.wordExcerpt(_words(95));
      expect(e.truncated, isTrue);
      expect(e.text, '${_words(60)}…');
      expect(RegExp(r'\S+').allMatches(e.text).length, 60);
    });

    test('paragraph breaks inside the 60 words are kept', () {
      final text = '${_words(10)}\n\n${_words(70)}';
      final e = SpotlightNewsCard.wordExcerpt(text);
      expect(e.text, contains('\n\n'));
      expect(e.truncated, isTrue);
    });
  });

  group('Read more on the card', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppState.instance.language = 'Telugu';
    });

    Future<void> pump(WidgetTester tester, String body) async {
      // A tall screen: here only the word limit decides Read more.
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

    testWidgets('a 40-word story: no Read more', (tester) async {
      await pump(tester, _words(40));
      expect(find.text('ఇంకా చదవండి'), findsNothing);
      await done(tester);
    });

    testWidgets('a 90-word story: 60 words and Read more', (tester) async {
      await pump(tester, _words(90));
      expect(find.text('ఇంకా చదవండి'), findsOneWidget);
      expect(find.textContaining('పదం61', findRichText: true), findsNothing);
      expect(find.textContaining('పదం60…', findRichText: true), findsOneWidget);
      await done(tester);
    });
  });
}
