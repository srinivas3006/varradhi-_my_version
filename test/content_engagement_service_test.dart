import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/services/content_engagement_service.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Answers each request from [routes] ("METHOD path" → (status, body)).
/// Unrouted requests get 405 — "this server has no such route".
class _Adapter implements HttpClientAdapter {
  _Adapter(this.routes);
  final Map<String, (int, Object)> routes;
  final List<String> calls = [];
  final List<Object?> bodies = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies.add(options.data);
    final (status, body) =
        routes[key] ?? (405, {'detail': 'Method not allowed.'});
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

NewsArticle _story({required bool ugc}) => NewsArticle.fromJson({
      'id': ugc ? 'sub-1' : 'art-1',
      'slug': ugc ? 'sub-1' : 'desk-story',
      'title': 'Story',
      'feed_item_type': ugc ? 'ugc' : 'article',
    });

ContentEngagementService _service(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter;
  return ContentEngagementService.forTesting(dio);
}

Map<String, dynamic> _error(int code, String message) => {
      'data': null,
      'meta': {},
      'errors': {
        'code': code,
        'message': message,
        'details': {'detail': message},
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.resetBookmarksForTest();
    // Server calls are for accounts; a guest's bookmarks stay on the phone.
    AppState.instance.isLoggedIn = true;
  });

  tearDown(() => AppState.instance.isLoggedIn = false);

  group('report (handover §12, §17.1)', () {
    test('a desk article posts to the article report endpoint', () async {
      final a = _Adapter({
        'POST /api/v1/articles/art-1/report/': (201, {'data': {}}),
      });
      final out = await _service(a)
          .report(_story(ugc: false), reason: 'misinformation');
      expect(out, ReportOutcome.sent);
      expect((a.bodies.single as Map)['reason'], 'misinformation');
    });

    test('a citizen post sends the reason as-is (any string ≤100)', () async {
      final a = _Adapter({'POST /api/v1/ugc/report/': (201, {'data': {}})});
      final out =
          await _service(a).report(_story(ugc: true), reason: 'copyright');
      expect(out, ReportOutcome.sent);
      final body = a.bodies.single as Map;
      expect(body['submission_id'], 'sub-1');
      expect(body['reason'], 'copyright');
      expect(body.containsKey('notes'), isFalse);
    });

    test('"Article already reported by this user." is its own outcome',
        () async {
      final a = _Adapter({
        'POST /api/v1/articles/art-1/report/':
            (400, _error(400, 'Article already reported by this user.')),
      });
      expect(await _service(a).report(_story(ugc: false), reason: 'spam'),
          ReportOutcome.alreadyReported);
    });

    test('"Submission already reported by this user." too', () async {
      final a = _Adapter({
        'POST /api/v1/ugc/report/':
            (400, _error(400, 'Submission already reported by this user.')),
      });
      expect(await _service(a).report(_story(ugc: true), reason: 'spam'),
          ReportOutcome.alreadyReported);
    });

    test('404 "Article not found." is a failure, never the email fallback',
        () async {
      final a = _Adapter({
        'POST /api/v1/articles/art-1/report/':
            (404, _error(404, 'Article not found.')),
      });
      expect(await _service(a).report(_story(ugc: false), reason: 'spam'),
          ReportOutcome.failed);
    });

    test('only a server without the route (405) falls back, asked once',
        () async {
      final a = _Adapter({});
      final s = _service(a);
      expect(await s.report(_story(ugc: false), reason: 'spam'),
          ReportOutcome.unsupported);
      expect(await s.report(_story(ugc: false), reason: 'spam'),
          ReportOutcome.unsupported);
      expect(a.calls, hasLength(1));
    });
  });

  group('like / dislike on citizen posts (§17.2)', () {
    test('PUT returns the server counts', () async {
      final a = _Adapter({
        'PUT /api/v1/ugc/sub-1/reaction/': (200, {
          'data': {
            'submission_id': 'sub-1',
            'reaction_type': 'like',
            'my_reaction': 'like',
            'like_count': 12,
            'dislike_count': 1,
          }
        }),
      });
      final res = await _service(a).react(_story(ugc: true), 'like');
      expect(res['like_count'], 12);
      expect(res['my_reaction'], 'like');
      expect((a.bodies.single as Map)['reaction_type'], 'like');
    });

    test('"none" removes the reaction with DELETE', () async {
      final a = _Adapter({
        'DELETE /api/v1/ugc/sub-1/reaction/': (200, {
          'data': {'my_reaction': null, 'like_count': 11, 'dislike_count': 1}
        }),
      });
      final res = await _service(a).react(_story(ugc: true), 'none');
      expect(a.calls.single, 'DELETE /api/v1/ugc/sub-1/reaction/');
      expect(res['like_count'], 11);
    });

    test('404 "Submission not found." throws so the UI rolls back', () async {
      final a = _Adapter({
        'PUT /api/v1/ugc/sub-1/reaction/':
            (404, _error(404, 'Submission not found.')),
      });
      expect(() => _service(a).react(_story(ugc: true), 'like'),
          throwsA(isA<DioException>()));
    });

    test('429 throttled throws so the UI rolls back', () async {
      final a = _Adapter({
        'PUT /api/v1/ugc/sub-1/reaction/': (429, _error(429, 'Throttled.')),
      });
      expect(() => _service(a).react(_story(ugc: true), 'like'),
          throwsA(isA<DioException>()));
    });
  });

  group('bookmark citizen posts (handover §4)', () {
    test('server {bookmarked: true} is the final state', () async {
      final a = _Adapter({
        'POST /api/v1/ugc/sub-1/bookmark/toggle/':
            (201, {'data': {'bookmarked': true}}),
      });
      final saved =
          await _service(a).setBookmarked(_story(ugc: true), nowBookmarked: true);
      expect(saved, isTrue);
      expect(AppState.instance.isSavedOnDevice('sub-1'), isFalse,
          reason: 'the combined saved list includes citizen posts now');
    });

    test('the toggle can disagree with the guess — server wins', () async {
      final a = _Adapter({
        'POST /api/v1/ugc/sub-1/bookmark/toggle/':
            (200, {'data': {'bookmarked': false}}),
      });
      await AppState.instance.saveStoryOnDevice(_story(ugc: true));
      final saved =
          await _service(a).setBookmarked(_story(ugc: true), nowBookmarked: true);
      expect(saved, isFalse);
      expect(AppState.instance.isSavedOnDevice('sub-1'), isFalse,
          reason: 'a copy left by an older version is cleaned up');
    });

    test('404 is a failure (null), nothing saved', () async {
      final a = _Adapter({
        'POST /api/v1/ugc/sub-1/bookmark/toggle/':
            (404, _error(404, 'Submission not found.')),
      });
      expect(await _service(a).setBookmarked(_story(ugc: true), nowBookmarked: true),
          isNull);
    });

    test('a failed request is sent once, never retried', () async {
      final a = _Adapter({
        'POST /api/v1/ugc/sub-1/bookmark/toggle/':
            (500, _error(500, 'Server error.')),
      });
      expect(await _service(a).setBookmarked(_story(ugc: true), nowBookmarked: true),
          isNull);
      expect(a.calls, ['POST /api/v1/ugc/sub-1/bookmark/toggle/']);
    });
  });

  test('citizen feed engagement state reaches the article model (§17.4)', () {
    final a = NewsArticle.fromJson({
      'id': 'sub-9',
      'title': 'x',
      'feed_item_type': 'ugc',
      'like_count': 12,
      'dislike_count': 1,
      'my_reaction': 'like',
      'is_bookmarked': true,
    });
    expect(a.likes, 12);
    expect(a.dislikes, 1);
    expect(a.isLiked, isTrue);
    expect(a.isBookmarked, isTrue);
  });
}
