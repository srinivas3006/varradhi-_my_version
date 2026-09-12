import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/network/api_response.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/repositories/news_article_repository.dart';
import 'package:way2news_clone/widgets/news_feed_card.dart';

class TestMockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  TestMockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody jsonResponse(dynamic body, int statusCode) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

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
      ApiClient.instance.dio.httpClientAdapter = TestMockAdapter((options) async {
        if (options.path.contains('hello-world')) {
          return TestMockAdapter.jsonResponse({
            'data': {
              'id': 'art-hw',
              'title': 'Hello World Article',
              'slug': 'hello-world',
              'summary': 'This is a detailed summary for the mock article.',
              'content': '<p>full rich-text HTML content here</p>',
              'category': 'General',
              'is_video': false,
            }
          }, 200);
        }
        return TestMockAdapter.jsonResponse({'errors': {'code': 404, 'message': 'Not Found'}}, 404);
      });
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
