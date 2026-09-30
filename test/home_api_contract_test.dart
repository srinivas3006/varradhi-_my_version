import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/navigation/app_navigator.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/repositories/ad_repository.dart';
import 'package:vaaradhi/repositories/home_feed_repository.dart';
import 'package:vaaradhi/screens/home_screen.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Records every request and answers by path.
class _Api implements HttpClientAdapter {
  _Api(this.handler);
  final (int, Object) Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];
  final Map<String, Completer<void>> gates = {};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
      Future<void>? __) async {
    requests.add(o);
    final gate = gates[o.path];
    if (gate != null) await gate.future;
    final (status, body) = handler(o);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  List<String> get paths => requests.map((r) => r.path).toList();
}

Dio _dio(_Api a) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = a;

Map<String, dynamic> _item(String id, {String type = 'article'}) =>
    {'id': id, 'type': type, 'title': 'T $id', 'metadata': {'slug': 's-$id'}};

Map<String, dynamic> _home(List<String> personalized, List<String> local) => {
      'data': {
        'sections': [
          {'key': 'personalized', 'items': personalized.map(_item).toList()},
          {'key': 'local', 'items': local.map(_item).toList()},
        ],
      },
      'meta': {},
      'errors': null,
    };

(int, Object) _everything(RequestOptions o) {
  switch (o.path) {
    case '/api/v1/feed/home/':
      return (200, _home(['p1', 'p2'], ['l1']));
    case '/api/v1/feed/':
      return (200, {
        'data': [_item('a1'), _item('u1', type: 'ugc'), _item('v1', type: 'live')],
        'meta': {'next': null},
      });
    default:
      return (200, {'data': [], 'meta': {}, 'errors': null});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeFeedRepository.instance.resetForTesting();
    AdRepository.instance.clearCache();
    AppNavigator.resetDebounce();
  });

  group('a Home load makes each call once, and only these', () {
    testWidgets('exact request list, ads requested once', (tester) async {
      final api = _Api(_everything);
      ApiClient.instance.dio.httpClientAdapter = api;

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final paths = api.paths;
      int count(String p) => paths.where((x) => x == p).length;

      expect(count('/api/v1/feed/home/'), 1);
      expect(count('/api/v1/feed/'), 1);
      expect(count('/api/v1/categories/'), 1);
      expect(count('/api/v1/ads/'), 1,
          reason: 'inline, strip and bottom sticky share one response');
      expect(count('/api/v1/polls/'), 1);
      expect(count('/api/v1/posters/'), 1);
      expect(count('/api/v1/articles/video-feed/'), 1);
      expect(count('/api/v1/quotes/random/'), 1);

      for (final retired in [
        '/api/v1/articles/feed/',
        '/api/v1/ugc/feed/',
        '/api/v1/articles/recommendations/',
        '/api/v1/articles/live/',
        '/api/v1/articles/featured/',
      ]) {
        expect(count(retired), 0, reason: '$retired must not run on Home');
      }
    });

    testWidgets('/feed/home/ has no scope; /feed/ is include=all, scope=main',
        (tester) async {
      final api = _Api(_everything);
      ApiClient.instance.dio.httpClientAdapter = api;

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final home = api.requests.firstWhere((r) => r.path == '/api/v1/feed/home/');
      expect(home.queryParameters.containsKey('scope'), isFalse);
      expect(home.queryParameters['mode'], 'normal');
      expect(home.queryParameters['limit'], '10');

      final latest = api.requests.firstWhere((r) => r.path == '/api/v1/feed/');
      expect(latest.queryParameters['include'], 'all');
      expect(latest.queryParameters['scope'], 'main');
      expect(latest.queryParameters['page_size'], 20);
    });
  });

  testWidgets('pull-to-refresh reloads both feeds and keeps content up',
      (tester) async {
    final api = _Api(_everything);
    ApiClient.instance.dio.httpClientAdapter = api;

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    int count(String p) => api.paths.where((x) => x == p).length;
    expect(count('/api/v1/feed/home/'), 1);

    // The spinner starts below the floating header, not behind it.
    final indicator = tester
        .widget<RefreshIndicator>(find.byKey(const Key('home_refresh')));
    expect(indicator.edgeOffset, greaterThanOrEqualTo(68));

    await tester.fling(
        find.byType(CustomScrollView).first, const Offset(0, 500), 1500);
    await tester.pump();
    // Old content stays visible while the refresh runs.
    expect(find.text('T l1'), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(count('/api/v1/feed/home/'), 2, reason: 'forced, not the cache');
    expect(count('/api/v1/feed/'), 2, reason: 'cursor reset, first page');
    expect(count('/api/v1/ads/'), 2, reason: 'still one per load');
    expect(find.text('T l1'), findsWidgets);
  });

  testWidgets('story pictures: media_items count, and no grey placeholders',
      (tester) async {
    final api = _Api((o) {
      if (o.path == '/api/v1/feed/home/') {
        return (200, {
          'data': {
            'sections': [
              {
                'key': 'personalized',
                'items': [
                  {
                    'id': 'b1',
                    'type': 'article',
                    'title': 'Breaking with photo',
                    'metadata': {'slug': 's-b1', 'is_breaking': true},
                    // The picture is only here, not in image_url.
                    'media_items': [
                      {
                        'media_type': 'image',
                        'url': 'https://cdn.test/b1.jpg',
                        'thumbnail_url': 'https://cdn.test/b1-thumb.jpg',
                      },
                    ],
                  },
                  _item('p2'),
                ],
              },
              {'key': 'local', 'items': []},
            ],
          },
        });
      }
      return _everything(o);
    });
    ApiClient.instance.dio.httpClientAdapter = api;

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // The hero shows b1's photo from media_items, not a grey card.
    final heroImages = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.image?.image)
        .whereType<CachedNetworkImageProvider>()
        .map((p) => p.url);
    expect(heroImages, contains('https://cdn.test/b1-thumb.jpg'));

    // p2 has no picture: the branded tile, not a grey box.
    expect(find.byKey(const Key('no_image_tile')), findsWidgets);
  });

  group('/feed/ — the Latest list', () {
    test('keeps article, ugc and live; drops anything else', () {
      final page = LatestPage.parse({
        'data': [
          _item('a1'),
          _item('u1', type: 'ugc'),
          _item('v1', type: 'live'),
          _item('x1', type: 'ad'),
        ],
        'meta': {'next': null},
      });
      expect(page.items.map((a) => '${a.contentKind}:${a.id}'),
          ['article:a1', 'ugc:u1', 'live:v1']);
      expect(page.next, isNull);
    });

    test('the next page is meta.next exactly — never a built page=2', () async {
      const next =
          'https://api.vaaradhinews.com/api/v1/feed/?cursor=abc&include=all&scope=main';
      final api = _Api((o) => (200, {
            'data': [_item('a2')],
            'meta': {'next': null},
          }));
      final repo = HomeFeedRepository.forTesting(_dio(api));
      final first = LatestPage.parse({
        'data': [_item('a1')],
        'meta': {'next': next},
      });
      expect(first.next, next);

      await repo.fetchLatest(
          next: first.next,
          state: 'Telangana',
          district: '',
          subdistrict: '',
          village: '');
      expect(api.requests.single.uri.toString(), next);
      expect(api.requests.single.uri.queryParameters.containsKey('page'),
          isFalse);
    });
  });

  group('Home cache', () {
    test('one account never sees another\'s personalized Home', () async {
      final api = _Api((o) => (200, _home(['mine'], const [])));
      final repo = HomeFeedRepository.forTesting(_dio(api));
      await repo.fetch(
          viewer: 'user:1',
          lang: 'te',
          state: 'Telangana',
          district: 'Suryapet',
          subdistrict: '',
          village: '');

      final other = await repo.cached(
          viewer: 'user:2',
          lang: 'te',
          state: 'Telangana',
          district: 'Suryapet',
          subdistrict: '',
          village: '');
      expect(other, isNull);
      final guest = await repo.cached(
          viewer: 'guest',
          lang: 'te',
          state: 'Telangana',
          district: 'Suryapet',
          subdistrict: '',
          village: '');
      expect(guest, isNull);
      final same = await repo.cached(
          viewer: 'user:1',
          lang: 'te',
          state: 'Telangana',
          district: 'Suryapet',
          subdistrict: '',
          village: '');
      expect(same!.personalized.single.id, 'mine');
    });

    test('a failed refresh keeps the cached copy and reports the status',
        () async {
      final ok = HomeFeedRepository.forTesting(
          _dio(_Api((o) => (200, _home(['saved'], const [])))));
      await ok.fetch(
          viewer: 'guest', state: 'T', district: '', subdistrict: '', village: '');

      final throttled = HomeFeedRepository.forTesting(
          _dio(_Api((o) => (429, {'detail': 'Throttled.'}))));
      expect(
          await throttled.fetch(
              viewer: 'guest',
              state: 'T',
              district: '',
              subdistrict: '',
              village: '',
              forceRefresh: true),
          isNull);
      expect(throttled.lastFailureStatus, 429);
      final kept = await throttled.cached(
          viewer: 'guest', state: 'T', district: '', subdistrict: '', village: '');
      expect(kept!.personalized.single.id, 'saved');
    });
  });

  testWidgets('a location change drops the old place\'s late answer',
      (tester) async {
    final app = AppState.instance;
    final oldDistrict = app.district;
    // Each answer is for the place its own request asked about.
    final api = _Api((o) {
      if (o.path == '/api/v1/feed/home/') {
        final place =
            o.queryParameters['district'] == 'NewDistrict' ? 'new' : 'old';
        return (200, _home(['$place-story'], const []));
      }
      return _everything(o);
    });
    // Hold the first /feed/home/ answer until after the location changes.
    api.gates['/api/v1/feed/home/'] = Completer<void>();
    ApiClient.instance.dio.httpClientAdapter = api;

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    // Location changes while the old request is still in flight.
    final held = api.gates.remove('/api/v1/feed/home/')!;
    app.district = 'NewDistrict';
    app.notifyListeners();
    await tester.pump();
    // Only now does the old place's answer arrive — late.
    held.complete();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('T new-story'), findsWidgets);
    expect(find.text('T old-story'), findsNothing);

    app.district = oldDistrict;
    app.notifyListeners();
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
