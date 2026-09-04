import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/api_response.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/repositories/news_article_repository.dart';
import 'package:way2news_clone/widgets/news_feed_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel flutterTtsChannel = MethodChannel('flutter_tts');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(flutterTtsChannel, (MethodCall methodCall) async {
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(flutterTtsChannel, null);
  });

  group('NewsArticleRepository', () {
    setUp(() {
      NewsArticleRepository.instance.clearCache();
    });

    test('fetches article detail from mock backend using slug', () async {
      final article = await NewsArticleRepository.instance.getDetail('hello-world', forceRefresh: true);

      expect(article.slug, 'hello-world');
      expect(article.summary, 'This is a detailed summary for the mock article.');
      expect(article.body, contains('full rich-text HTML content'));
      expect(article.isVideo, isFalse);
    });

    test('fetches article detail using alias getArticleBySlug', () async {
      final article = await NewsArticleRepository.instance.getArticleBySlug('hello-world', forceRefresh: true);

      expect(article.slug, 'hello-world');
      expect(article.summary, 'This is a detailed summary for the mock article.');
    });

    test('ApiResponse extracts nested pagination next cursor properly', () {
      final response = ApiResponse.fromJson(
        {
          'data': [],
          'meta': {
            'pagination': {
              'next': 'cursor-123',
            }
          },
          'errors': null,
        },
        (json) => (json as List).map((i) => i).toList(),
      );

      expect(response.nextCursor, 'cursor-123');
    });
  });

  group('NewsFeedCard', () {
    testWidgets('renders video overlay and duration when article is video', (tester) async {
      final article = NewsArticle(
        id: 'video-1',
        title: 'Video Article',
        slug: 'video-article',
        summary: 'Video summary',
        body: 'Video body',
        imageUrl: 'https://example.com/poster.jpg',
        source: 'VARADHI',
        category: 'Local',
        publishedAt: DateTime.now(),
        likes: 0,
        comments: 0,
        shares: 0,
        readTimeMinutes: 2,
        viewCount: 0,
        mediaType: 'video',
        videoUrl: 'https://example.com/video.mp4',
        videoDurationSeconds: 90,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NewsFeedCard(
            article: article,
            onTap: () {},
            onLike: () {},
            onBookmark: () {},
            onShare: () {},
            onComment: () {},
          ),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.text('1:30'), findsWidgets);
    });
  });
}
