import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/navigation/app_navigator.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/repositories/ad_repository.dart';
import 'package:vaaradhi/repositories/home_feed_repository.dart';
import 'package:vaaradhi/repositories/most_viewed_repository.dart';
import 'package:vaaradhi/screens/home_screen.dart';
import 'package:vaaradhi/services/analytics_queue.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _ugcId = '11111111-1111-4111-8111-111111111111';
const _articleId = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> _ugc() => {
      'id': _ugcId,
      'type': 'ugc',
      'title': 'Citizen story',
      'summary': 'Citizen description',
      'thumbnail_url': 'https://cdn.test/ugc.jpg',
      'media_url': 'https://cdn.test/ugc.jpg',
      'created_at': '2026-11-05T10:30:00+05:30',
      'district': 'Vikarabad',
      'state': 'Telangana',
      'source': 'USER_UPLOAD',
      'uploader': {'id': 'u', 'display_name': 'Reporter'},
      'metadata': {'category': 'general', 'source_id': _ugcId},
      'view_count': 0,
      'period_view_count': 82,
    };

Map<String, dynamic> _article() => {
      'id': _articleId,
      'type': 'article',
      'title': 'Desk story',
      'summary': 'Desk summary',
      'thumbnail_url': 'https://cdn.test/a.jpg',
      'media_url': '',
      'created_at': '2026-11-05T10:00:00+05:30',
      'source': 'VARADHI News',
      'metadata': {'slug': 'desk-story', 'source_id': _articleId},
      'view_count': 1250,
      'period_view_count': 61,
    };

class _Api implements HttpClientAdapter {
  _Api(this.mostViewed);

  /// The current answer of the Most Viewed endpoint: (status, body).
  (int, Object) Function() mostViewed;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    requests.add(options);
    final (int, Object) answer;
    switch (options.path) {
      case MostViewedRepository.endpoint:
        answer = mostViewed();
      case '/api/v1/feed/':
        answer = (
          200,
          {
            'data': [
              {
                'id': 'latest-1',
                'type': 'article',
                'title': 'Latest story',
                'published_at': DateTime.now().toIso8601String(),
                'metadata': {'slug': 'latest-1'},
              },
            ],
            'meta': {'next': null},
          }
        );
      default:
        answer = (200, {'data': [], 'meta': {}, 'errors': null});
    }
    return ResponseBody.fromString(jsonEncode(answer.$2), answer.$1, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  Iterable<RequestOptions> get mostViewedCalls =>
      requests.where((r) => r.path == MostViewedRepository.endpoint);
}

(int, Object) _row() => (
      200,
      {
        'data': [_ugc(), _article()],
        'meta': {},
        'errors': null,
      }
    );

(int, Object) _empty() => (200, {'data': [], 'meta': {}, 'errors': null});

(int, Object) _error(int status) => (
      status,
      {
        'data': null,
        'meta': {},
        'errors': {'code': status, 'message': 'error'},
      }
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Api api;
  late MostViewedRepository repo;

  Future<MostViewedAnswer> fetch() => repo.fetch(
        viewer: 'guest',
        lang: 'te',
        state: '',
        district: '',
        city: '',
        subdistrict: '',
        village: '',
      );

  Future<List<MostViewedItem>> kept() => repo.cached(
        viewer: 'guest',
        lang: 'te',
        state: '',
        district: '',
        city: '',
        subdistrict: '',
        village: '',
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _Api(_row);
    repo = MostViewedRepository.forTesting(
        Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = api);
  });

  group('the items', () {
    test('kept in the backend\'s order, even with fewer views first', () {
      final items = MostViewedItem.parseList([
        {..._article(), 'period_view_count': 5},
        _ugc(),
      ]);
      expect(items.map((i) => i.periodViews), [5, 82]);
    });

    test('the count shown is period_view_count, not view_count', () {
      final article = MostViewedItem.parse(_article())!;
      expect(article.periodViews, 61);
      expect(article.story.viewCount, 1250);
    });

    test('citizen news opens by id; its views count as submission_id', () {
      final story = MostViewedItem.parse(_ugc())!.story;
      expect(story.isUgc, isTrue);
      expect(story.id, _ugcId);
      final event = AnalyticsQueue.contentIdOf(story)!;
      expect(event.key, 'submission_id');
      expect(event.value, _ugcId);
    });

    test('an article opens by slug; its views count as article_id', () {
      final story = MostViewedItem.parse(_article())!.story;
      expect(story.isUgc, isFalse);
      expect(story.slug, 'desk-story');
      expect(AnalyticsQueue.contentIdOf(story)!.key, 'article_id');
    });

    test('what cannot be opened is left out', () {
      expect(
          MostViewedItem.parse(
              {..._article(), 'metadata': <String, dynamic>{}}),
          isNull,
          reason: 'an article with no slug');
      expect(MostViewedItem.parse({..._article(), 'type': 'poll'}), isNull);
    });
  });

  group('the request', () {
    test('no location: only language, period and limit', () async {
      await fetch();
      expect(api.requests.single.queryParameters,
          {'lang': 'te', 'period': '24h', 'limit': '10'});
    });

    test('a saved location: every level that exists', () async {
      await repo.fetch(
        viewer: 'guest',
        lang: 'all',
        state: 'Telangana',
        district: 'Vikarabad',
        city: '',
        subdistrict: 'Mominpet',
        village: 'Velchal',
      );
      final query = api.requests.single.queryParameters;
      expect(query['lang'], 'all');
      expect(query['state'], 'Telangana');
      expect(query['district'], 'Vikarabad');
      expect(query['subdistrict'], 'Mominpet');
      expect(query['village'], 'Velchal');
      expect(query.containsKey('city'), isFalse);
    });
  });

  group('each answer', () {
    test('200 with data: shown and kept', () async {
      expect((await fetch()).items, hasLength(2));
      expect(await kept(), hasLength(2));
    });

    test('200 empty: hidden and forgotten', () async {
      await fetch();
      api.mostViewed = _empty;
      expect((await fetch()).items, isEmpty);
      expect(await kept(), isEmpty);
    });

    test('400: hidden', () async {
      await fetch();
      api.mostViewed = () => _error(400);
      expect((await fetch()).items, isEmpty);
    });

    test('429: keeps the row and asks for a retry', () async {
      await fetch();
      api.mostViewed = () => _error(429);
      final answer = await fetch();
      expect(answer.items, isNull);
      expect(answer.throttled, isTrue);
      expect(await kept(), hasLength(2));
    });

    for (final status in [500, 502, 503, 504]) {
      test('$status: keeps the row', () async {
        await fetch();
        api.mostViewed = () => _error(status);
        final answer = await fetch();
        expect(answer.items, isNull);
        expect(answer.throttled, isFalse);
        expect(await kept(), hasLength(2));
      });
    }

    test('an unexpected body: keeps the row', () async {
      await fetch();
      api.mostViewed = () => (200, {'data': 'nope'});
      expect((await fetch()).items, isNull);
      expect(await kept(), hasLength(2));
    });

    test('one reader\'s row is not kept for another', () async {
      await fetch();
      expect(
          await repo.cached(
            viewer: 'user:1',
            lang: 'te',
            state: '',
            district: '',
            city: '',
            subdistrict: '',
            village: '',
          ),
          isEmpty);
    });
  });

  group('on Home', () {
    final row = find.byKey(const Key('home_most_viewed'));

    setUp(() {
      // Impression checks run at once, leaving no timer behind.
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      AppState.instance
        ..hasValidLocation = false
        ..language = 'English';
      HomeFeedRepository.instance.resetForTesting();
      AdRepository.instance.clearCache();
      AppNavigator.resetDebounce();
      ApiClient.instance.dio.httpClientAdapter = api;
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    testWidgets('both kinds show, in order, with the period count',
        (tester) async {
      await open(tester);
      expect(api.mostViewedCalls, hasLength(1));
      expect(find.text('Most Viewed'), findsOneWidget);
      expect(find.text('Citizen story'), findsOneWidget);
      expect(find.textContaining('82 views'), findsOneWidget);
      final ugc = tester.getTopLeft(find.text('Citizen story')).dx;
      final article = tester.getTopLeft(find.text('Desk story')).dx;
      expect(ugc, lessThan(article));
    });

    testWidgets('nothing qualifies: no row, Home is fine', (tester) async {
      api.mostViewed = _empty;
      await open(tester);
      expect(row, findsNothing);
      expect(find.text('Most Viewed'), findsNothing);
      expect(find.text('Latest story'), findsOneWidget);
    });

    testWidgets('the endpoint fails: no row, Home is fine', (tester) async {
      api.mostViewed = () => _error(500);
      await open(tester);
      expect(row, findsNothing);
      expect(find.text('Latest story'), findsOneWidget);
    });

    testWidgets('offline with a kept row: the row stays', (tester) async {
      // Saved under the language Home asks for in this test.
      await tester.runAsync(() => repo.fetch(
            viewer: 'guest',
            lang: 'all',
            state: '',
            district: '',
            city: '',
            subdistrict: '',
            village: '',
          ));
      // The Home load fails, but the copy kept by the good answer shows.
      api.mostViewed = () => _error(503);
      await open(tester);
      expect(find.text('Citizen story'), findsOneWidget);
    });

    testWidgets('429 retries later, once', (tester) async {
      api.mostViewed = () => _error(429);
      await open(tester);
      expect(api.mostViewedCalls, hasLength(1));
      api.mostViewed = _row;
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(api.mostViewedCalls, hasLength(2));
      expect(find.text('Citizen story'), findsOneWidget);
    });
  });
}
