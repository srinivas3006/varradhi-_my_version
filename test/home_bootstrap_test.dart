import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/models/search_result.dart';
import 'package:vaaradhi/repositories/home_feed_repository.dart';
import 'package:vaaradhi/services/analytics_queue.dart';
import 'package:vaaradhi/services/sharing/share_content_builder.dart';
import 'package:vaaradhi/utils/share_service.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final (int, Object) Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter a) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = a;

Map<String, dynamic> _article(String id) =>
    {'id': id, 'slug': 's-$id', 'title': 'T $id', 'feed_item_type': 'article'};

Map<String, dynamic> _homeBody() => {
      'data': {
        'sections': {
          'personalized': [_article('p1'), _article('p2')],
          'local': {'items': [_article('l1')]},
        },
        'cache_ttl_seconds': 120,
        'offline_support': {
          'analytics_bulk_endpoint': '/api/v1/analytics/events/bulk/',
        },
      },
      'meta': {},
      'errors': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('home bootstrap parsing', () {
    test('Home items carry their slug in metadata — it is lifted', () {
      // Shape returned by production /api/v1/feed/home/ (2026-09-27): no
      // top-level slug. An empty slug meant the detail screen could not
      // call /api/v1/articles/{slug}/ and fell back to the id.
      final b = HomeBootstrap.parse({
        'data': {
          'sections': [
            {
              'key': 'personalized',
              'items': [
                {
                  'id': '0d421f79-a530-4b8d-91a5-54a09a0c2723',
                  'type': 'article',
                  'title': 't',
                  'summary': '',
                  'metadata': {
                    'slug': 'article-c80adb24b8d8',
                    'share_url':
                        'https://vaaradhinews.com/article/article-c80adb24b8d8/',
                    'is_breaking': true,
                  },
                },
              ],
            },
          ],
        },
      }, lite: false);
      final a = b.personalized.single;
      expect(a.slug, 'article-c80adb24b8d8');
      expect(a.slug, isNot(a.id));
      expect(a.shareUrl,
          'https://vaaradhinews.com/article/article-c80adb24b8d8/');
      expect(a.isBreaking, isTrue);
    });

    test('a top-level slug still wins over metadata', () {
      final a = NewsArticle.fromJson({
        'id': '1',
        'title': 't',
        'slug': 'top',
        'metadata': {'slug': 'nested'},
      });
      expect(a.slug, 'top');
    });

    test('map-shaped sections', () {
      final b = HomeBootstrap.parse(_homeBody(), lite: false);
      expect(b.personalized.map((a) => a.id), ['p1', 'p2']);
      expect(b.local.single.id, 'l1');
      expect(b.cacheTtlSeconds, 120);
      expect(b.analyticsBulkEndpoint, '/api/v1/analytics/events/bulk/');
    });

    test('list-shaped sections', () {
      final b = HomeBootstrap.parse({
        'data': {
          'sections': [
            {'key': 'personalized', 'items': [_article('a')]},
            {'type': 'local', 'results': [_article('b')]},
          ],
        },
      }, lite: true);
      expect(b.personalized.single.id, 'a');
      expect(b.local.single.id, 'b');
      expect(b.lite, isTrue);
      expect(b.cacheTtlSeconds, 60, reason: 'defaults when absent');
    });

    test('malformed items are skipped, not fatal', () {
      final b = HomeBootstrap.parse({
        'data': {
          'sections': {
            'personalized': ['junk', 42, _article('ok')],
          },
        },
      }, lite: false);
      expect(b.personalized.single.id, 'ok');
    });
  });

  group('home bootstrap repository', () {
    test('sends location, mode and limit — and no scope', () async {
      final a = _Adapter((_) => (200, _homeBody()));
      final repo = HomeFeedRepository.forTesting(_dio(a));
      await repo.fetch(viewer: 'guest',
          lang: 'te',
          state: 'Telangana',
          district: 'Suryapet',
          subdistrict: 'Jajireddygudem',
          village: 'Kesaram');
      final q = a.requests.single.queryParameters;
      expect(a.requests.single.path, '/api/v1/feed/home/');
      expect(q['lang'], 'te');
      expect(q['state'], 'Telangana');
      expect(q['district'], 'Suryapet');
      expect(q['subdistrict'], 'Jajireddygudem');
      expect(q['village'], 'Kesaram');
      // /feed/home/ builds both the main and the local section itself.
      expect(q.containsKey('scope'), isFalse);
      expect(q['mode'], 'normal');
      expect(q['limit'], '10');
    });

    test('honours cache_ttl_seconds, refresh bypasses it', () async {
      final a = _Adapter((_) => (200, _homeBody()));
      final repo = HomeFeedRepository.forTesting(_dio(a));
      Future<HomeBootstrap?> go({bool force = false}) => repo.fetch(viewer: 'guest',
          state: 'Telangana',
          district: 'Suryapet',
          subdistrict: '',
          village: '',
          forceRefresh: force);
      await go();
      await go();
      expect(a.requests, hasLength(1));
      await go(force: true);
      expect(a.requests, hasLength(2));
    });

    test('the last response is kept on the device for an instant start',
        () async {
      final a = _Adapter((_) => (200, _homeBody()));
      await HomeFeedRepository.forTesting(_dio(a)).fetch(viewer: 'guest',
          state: 'Telangana', district: 'Suryapet', subdistrict: '', village: '');

      // A fresh repository (new app launch) with no network.
      final offline = HomeFeedRepository.forTesting(
          _dio(_Adapter((_) => (500, {}))));
      final cached = await offline.cached(viewer: 'guest',
          state: 'Telangana', district: 'Suryapet', subdistrict: '', village: '');
      expect(cached, isNotNull);
      expect(cached!.fromDeviceCache, isTrue);
      expect(cached.personalized, hasLength(2));
    });

    test('an unavailable endpoint returns null so Home falls back', () async {
      final repo = HomeFeedRepository.forTesting(
          _dio(_Adapter((_) => (404, {'detail': 'Not found.'}))));
      expect(
          await repo.fetch(viewer: 'guest',
              state: '', district: '', subdistrict: '', village: ''),
          isNull);
    });
  });

  group('offline analytics', () {
    test('queues, then flushes to the bulk endpoint on 202', () async {
      final a = _Adapter((_) => (202, {'data': {'accepted_count': 2}}));
      final q = AnalyticsQueue.forTesting(_dio(a));
      await q.track('feed_refresh', metadata: {'mode': 'lite'});
      await q.track('article_open', metadata: {'article_id': 'x'});
      expect(q.pending, hasLength(2));

      await q.flush();
      expect(q.pending, isEmpty);
      final body = a.requests.single.data as Map;
      expect(a.requests.single.path, '/api/v1/analytics/events/bulk/');
      final events = body['events'] as List;
      expect(events.first['event_type'], 'feed_refresh');
      expect(events.first['metadata'], {'mode': 'lite'});
      expect(events.first, contains('session_id'));
      expect(events.first, contains('language'));
      expect(events.first, contains('device_type'));
    });

    test('keeps events when the network is down', () async {
      final q = AnalyticsQueue.forTesting(
          _dio(_Adapter((_) => (503, {'detail': 'down'}))));
      await q.track('feed_refresh');
      await q.flush();
      expect(q.pending, hasLength(1));
    });

    test('survives a restart', () async {
      final q = AnalyticsQueue.forTesting(
          _dio(_Adapter((_) => (503, {}))));
      await q.track('feed_refresh');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('analytics_event_queue_v1'),
          contains('feed_refresh'));
    });
  });

  group('search suggestions', () {
    test('zero results still carry suggestions', () {
      final r = SearchResult.parse({
        'data': {
          'results': [],
          'suggestions': ['Suryapet', {'text': 'Kodad'}, 'Suryapet'],
          'filters': {},
          'cache_ttl_seconds': 30,
        },
      });
      expect(r.results, isEmpty);
      expect(r.suggestions, ['Suryapet', 'Kodad']);
      expect(r.cacheTtlSeconds, 30);
    });

    test('the screen offers "try another keyword" and the chips', () {
      final src = File('lib/screens/search_screen.dart').readAsStringSync();
      expect(src, contains('Try another keyword'));
      expect(src, contains('search_suggestion_'));
    });
  });

  group('share_url from the API', () {
    test('used when it is on the brand domain', () {
      final a = NewsArticle.fromJson({
        ..._article('1'),
        'share_url': 'https://vaaradhinews.com/article/s-1/',
      });
      expect(ShareService.buildWebArticleUrl(a),
          'https://vaaradhinews.com/article/s-1/');
      expect(ShareContentBuilder.fromArticle(a).canonicalUrl,
          'https://vaaradhinews.com/article/s-1/');
    });

    test('a foreign or insecure share_url is ignored', () {
      expect(ShareContentBuilder.trustedShareUrl('https://evil.example/x'),
          isNull);
      expect(
          ShareContentBuilder.trustedShareUrl(
              'http://vaaradhinews.com/article/x/'),
          isNull);
      expect(
          ShareContentBuilder.trustedShareUrl(
              'https://vaaradhinews.com.evil.example/x'),
          isNull);
    });
  });

  test('home header: Search and Notifications only, no Spotlight button',
      () {
    final src = File('lib/screens/news_feed_tab.dart').readAsStringSync();
    expect(src, isNot(contains('Icons.auto_awesome_rounded')));
    expect(src, isNot(contains('SpotlightScreen')));
    expect(src, contains('Icons.search_rounded'));
    expect(src, contains('NotificationsScreen()'));
  });
}
