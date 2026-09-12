import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/network/api_response.dart';
import 'package:way2news_clone/core/state/feed_state.dart';
import 'package:way2news_clone/core/utils/date_parser.dart';
import 'package:way2news_clone/core/utils/url_normalizer.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/repositories/feed_repository.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<dynamic>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(dynamic body, int statusCode) {
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

  group('ApiResponse Tests', () {
    test('1. List response with pagination cursor', () {
      final json = {
        'data': [
          {'id': 'a1', 'title': 'First'},
          {'id': 'a2', 'title': 'Second'},
        ],
        'meta': {
          'count': 50,
          'next': 'https://api.varadhi.com/feed/?cursor=cur_page_2',
          'previous': null,
        },
        'errors': null,
      };

      final res = ApiResponse<List<String>>.fromJson(
        json,
        (data) => (data as List).map((e) => (e as Map)['title'].toString()).toList(),
      );

      expect(res.isSuccess, isTrue);
      expect(res.data?.length, 2);
      expect(res.nextCursor, 'cur_page_2');
      expect(res.paginationMeta?.count, 50);
      expect(res.paginationMeta?.next, 'https://api.varadhi.com/feed/?cursor=cur_page_2');
    });

    test('2. Object response', () {
      final json = {
        'data': {'id': 'x1', 'title': 'Single Object'},
        'meta': {},
        'errors': null,
      };

      final res = ApiResponse<Map<String, dynamic>>.fromJson(
        json,
        (data) => Map<String, dynamic>.from(data as Map),
      );

      expect(res.isSuccess, isTrue);
      expect(res.data?['id'], 'x1');
      expect(res.hasErrors, isFalse);
    });

    test('3. Null data response', () {
      final json = {
        'data': null,
        'meta': {},
        'errors': null,
      };

      final res = ApiResponse<String>.fromJson(json, (d) => d.toString());
      expect(res.isSuccess, isFalse);
      expect(res.data, isNull);
    });

    test('4. Empty data response', () {
      final json = {
        'data': [],
        'meta': {'count': 0, 'next': null, 'previous': null},
        'errors': null,
      };

      final res = ApiResponse<List<String>>.fromJson(
        json,
        (data) => (data as List).map((e) => e.toString()).toList(),
      );

      expect(res.isSuccess, isTrue);
      expect(res.data, isEmpty);
      expect(res.nextCursor, isNull);
    });

    test('5. Error object parsing', () {
      final json = {
        'data': null,
        'meta': {},
        'errors': {
          'code': 400,
          'message': 'చెల్లని అభ్యర్థన',
          'details': {'field': 'Invalid cursor'},
        },
      };

      final res = ApiResponse<dynamic>.fromJson(json, (d) => d);
      expect(res.isSuccess, isFalse);
      expect(res.hasErrors, isTrue);
      expect(res.apiError?.code, 400);
      expect(res.apiError?.message, 'చెల్లని అభ్యర్థన');
      expect(res.errorMessage, 'చెల్లని అభ్యర్థన');
    });

    test('6. Malformed response gracefully handles unexpected types', () {
      final json = {
        'data': 'not a list',
        'meta': 'not a map',
        'errors': 12345,
      };

      final res = ApiResponse<String>.fromJson(json, (d) => d.toString());
      expect(res.data, 'not a list');
      expect(res.paginationMeta, isNull);
      expect(res.errorMessage, '12345');
    });
  });

  group('UrlNormalizer Tests', () {
    test('converts relative media path to absolute backend URL', () {
      final normalized = UrlNormalizer.normalize('/media/articles/photo.jpg');
      expect(normalized.startsWith('http'), isTrue);
      expect(normalized.endsWith('/media/articles/photo.jpg'), isTrue);
    });

    test('converts protocol-relative URL to https', () {
      final normalized = UrlNormalizer.normalize('//images.unsplash.com/photo.jpg');
      expect(normalized, 'https://images.unsplash.com/photo.jpg');
    });

    test('preserves valid absolute HTTPS URLs', () {
      final normalized = UrlNormalizer.normalize('https://cdn.example.com/pic.png');
      expect(normalized, 'https://cdn.example.com/pic.png');
    });

    test('handles null and empty strings gracefully', () {
      expect(UrlNormalizer.normalize(null), '');
      expect(UrlNormalizer.normalize('   '), '');
      expect(UrlNormalizer.normalizeNullable(null), isNull);
    });

    test('extracts YouTube thumbnail from video links', () {
      final thumb = UrlNormalizer.extractYoutubeThumbnail('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(thumb, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');

      final shortsThumb = UrlNormalizer.extractYoutubeThumbnail('https://youtube.com/shorts/abc123def45');
      expect(shortsThumb, 'https://i.ytimg.com/vi/abc123def45/hqdefault.jpg');
    });
  });

  group('DateParser Tests', () {
    test('safely parses ISO-8601 strings with timezone', () {
      final dt = DateParser.tryParse('2026-03-15T14:30:00+05:30');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
    });

    test('safely parses Unix epoch timestamps in seconds and milliseconds', () {
      final sec = DateParser.tryParse(1773565800);
      expect(sec, isNotNull);

      final ms = DateParser.tryParse(1773565800000);
      expect(ms, isNotNull);
    });

    test('returns null on invalid date strings without crashing', () {
      expect(DateParser.tryParse('invalid-date-string'), isNull);
      expect(DateParser.tryParse(null), isNull);
      expect(DateParser.tryParse(''), isNull);
    });
  });

  group('FeedState Machine Tests', () {
    test('1. Initial state', () {
      final state = FeedState<String>.initial();
      expect(state.status, FeedStatus.initial);
      expect(state.items, isEmpty);
      expect(state.hasData, isFalse);
      expect(state.isInitialLoading, isFalse);
    });

    test('2. Loading state', () {
      final state = FeedState<String>.loading();
      expect(state.status, FeedStatus.loading);
      expect(state.isInitialLoading, isTrue);
    });

    test('3. Success state', () {
      final state = FeedState<String>.success(
        items: ['item1', 'item2'],
        nextCursor: 'cur1',
      );
      expect(state.status, FeedStatus.success);
      expect(state.isSuccess, isTrue);
      expect(state.hasData, isTrue);
      expect(state.hasMore, isTrue);
      expect(state.nextCursor, 'cur1');
    });

    test('4. Empty state (0 items from backend)', () {
      final state = FeedState<String>.empty();
      expect(state.status, FeedStatus.empty);
      expect(state.isEmpty, isTrue);
      expect(state.hasData, isFalse);
    });

    test('5. Error state with no prior content', () {
      final state = FeedState<String>.error(message: 'నెట్‌వర్క్ లోపం');
      expect(state.status, FeedStatus.error);
      expect(state.isError, isTrue);
      expect(state.errorMessage, 'నెట్‌వర్క్ లోపం');
      expect(state.hasData, isFalse);
    });

    test('6. Refresh error preserves existing content without wiping', () {
      final state = FeedState<String>.error(
        message: 'రిఫ్రెష్ విఫలమైంది',
        previousItems: ['existing1', 'existing2'],
        previousCursor: 'old_cursor',
        previousHasMore: true,
      );

      // Must NOT be FeedStatus.error or empty list
      expect(state.status, FeedStatus.success);
      expect(state.items.length, 2);
      expect(state.hasData, isTrue);
      expect(state.hasRefreshError, isTrue);
      expect(state.refreshErrorMessage, 'రిఫ్రెష్ విఫలమైంది');
      expect(state.nextCursor, 'old_cursor');
    });
  });

  group('FeedRepository Tests', () {
    late Dio testDio;
    late FeedRepository repository;

    NewsArticle createArticle(String id, String title) {
      return NewsArticle(
        id: id,
        title: title,
        summary: 'Summary $id',
        body: 'Body $id',
        imageUrl: 'https://example.com/img.jpg',
        source: 'VARADHI',
        category: 'Local',
        publishedAt: DateTime(2026, 1, 1),
        likes: 10,
        comments: 2,
        shares: 1,
        readTimeMinutes: 2,
        viewCount: 100,
      );
    }

    setUp(() {
      testDio = Dio(BaseOptions(baseUrl: 'https://test.varadhi.com'));
      repository = FeedRepository(dio: testDio);
    });

    test('1. First page fetch and cache storage', () async {
      testDio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return MockHttpClientAdapter.json({
          'data': [
            createArticle('art_1', 'Story 1').toJson(),
            createArticle('art_2', 'Story 2').toJson(),
          ],
          'meta': {'next': 'https://test.varadhi.com/feed/?cursor=c2'},
          'errors': null,
        }, 200);
      });

      final state = await repository.getInitialFeed(scope: 'all', lang: 'te');

      expect(state.isSuccess, isTrue);
      expect(state.items.length, 2);
      expect(state.nextCursor, 'c2');
      expect(state.hasMore, isTrue);

      // Verify cache hit
      final cacheKey = repository.generateKey(scope: 'all', lang: 'te');
      final cached = repository.getCachedFeed(cacheKey);
      expect(cached, isNotNull);
      expect(cached!.items.length, 2);
    });

    test('2. Pagination with cursor and deduplication', () async {
      testDio.httpClientAdapter = MockHttpClientAdapter((options) async {
        if (options.queryParameters['cursor'] == 'c2') {
          return MockHttpClientAdapter.json({
            'data': [
              createArticle('art_2', 'Duplicate Story 2').toJson(), // Duplicate!
              createArticle('art_3', 'Story 3').toJson(),
            ],
            'meta': {'next': null},
            'errors': null,
          }, 200);
        }
        return MockHttpClientAdapter.json({
          'data': [
            createArticle('art_1', 'Story 1').toJson(),
            createArticle('art_2', 'Story 2').toJson(),
          ],
          'meta': {'next': 'c2'},
          'errors': null,
        }, 200);
      });

      final firstPage = await repository.getInitialFeed(scope: 'all', lang: 'te', forceRefresh: true);
      expect(firstPage.items.length, 2);

      final secondPage = await repository.loadNextPage(
        currentState: firstPage,
        scope: 'all',
        lang: 'te',
      );

      // Total must be 3 because art_2 is deduplicated!
      expect(secondPage.items.length, 3);
      expect(secondPage.items.map((e) => e.id).toList(), ['art_1', 'art_2', 'art_3']);
      expect(secondPage.hasMore, isFalse);
    });

    test('3. Refresh failure preserves existing items with non-blocking error', () async {
      final initialItems = [createArticle('art_1', 'Existing 1')];
      final currentState = FeedState<NewsArticle>.success(
        items: initialItems,
        nextCursor: 'cur_1',
      );

      testDio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return MockHttpClientAdapter.json({
          'data': null,
          'meta': {},
          'errors': {'message': 'Server timeout'},
        }, 500);
      });

      final refreshed = await repository.refreshFeed(
        currentState: currentState,
        scope: 'all',
        lang: 'te',
      );

      // Items must be preserved
      expect(refreshed.items.length, 1);
      expect(refreshed.items.first.id, 'art_1');
      expect(refreshed.hasRefreshError, isTrue);
      expect(refreshed.refreshErrorMessage, isNotEmpty);
    });

    test('4. Empty response returns FeedStatus.empty', () async {
      testDio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return MockHttpClientAdapter.json({
          'data': [],
          'meta': {'count': 0, 'next': null},
          'errors': null,
        }, 200);
      });

      final state = await repository.getInitialFeed(scope: 'local', lang: 'te', forceRefresh: true);
      expect(state.isEmpty, isTrue);
      expect(state.items, isEmpty);
    });
  });
}
