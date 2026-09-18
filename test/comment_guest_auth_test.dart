import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/localization/app_translations.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/screens/comments_screen.dart';
import 'package:way2news_clone/state/app_state.dart';
import 'package:way2news_clone/widgets/news_feed_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Guest Comments & Friendly Auth Prompts', () {
    late NewsArticle testArticle;

    setUp(() {
      AppState.instance.isLoggedIn = false;
      AppState.instance.authToken = '';
      AppState.instance.userId = null;
      AppState.instance.userName = '';
      AppState.instance.language = 'English';

      testArticle = NewsArticle(
        id: 'article_test_123',
        title: 'Test Article Title',
        body: 'Test Article Body',
        summary: 'Test Article Summary',
        category: 'general',
        source: 'Test Source',
        publishedAt: DateTime.now(),
        imageUrl: '',
        comments: 5,
        likes: 10,
        shares: 2,
        readTimeMinutes: 2,
        viewCount: 100,
      );
    });

    test('Translations exist for comment login prompts', () {
      expect(tr('login_to_comment'), isNotEmpty);
      expect(tr('login_to_comment_desc'), isNotEmpty);
      expect(tr('maybe_later'), isNotEmpty);
    });

    testWidgets('NewsFeedCard allows opening comments without login',
        (tester) async {
      bool commentTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewsFeedCard(
              article: testArticle,
              onTap: () {},
              onLike: () {},
              onBookmark: () {},
              onShare: () {},
              onComment: () {
                commentTapped = true;
              },
            ),
          ),
        ),
      );

      // Tap the comment button on NewsFeedCard
      final commentBtn = find.byIcon(Icons.mode_comment_outlined);
      expect(commentBtn, findsOneWidget);

      await tester.tap(commentBtn);
      await tester.pump();

      // Ensure onComment callback was triggered without blocking
      expect(commentTapped, isTrue);
    });

    testWidgets('Guest typing comment and tapping send preserves text and shows login modal',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsScreen(
              article: testArticle,
              sheetMode: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the comment text field
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Enter comment text as guest
      const typedText = 'This is my guest comment';
      await tester.enterText(textField, typedText);
      await tester.pump();

      // Expect text is entered
      expect(find.text(typedText), findsOneWidget);

      // Tap send button
      final sendBtn = find.byIcon(Icons.send_rounded);
      expect(sendBtn, findsOneWidget);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      // Friendly login prompt modal should be shown
      expect(find.text(tr('login_to_comment')), findsWidgets);
      expect(find.text(tr('login_to_comment_desc')), findsOneWidget);
      expect(find.text(tr('maybe_later')), findsOneWidget);

      // Dismiss the modal
      await tester.tap(find.text(tr('maybe_later')));
      await tester.pumpAndSettle();

      // CRITICAL: Ensure typed comment text is still preserved in text field
      expect(find.text(typedText), findsOneWidget);
    });
  });
}
