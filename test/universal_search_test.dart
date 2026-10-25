import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/screens/search_screen.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/search/universal_search_view.dart';

Map<String, dynamic> _article(String id, String title) => {
      'id': id,
      'slug': 'article-$id',
      'title': title,
      'summary': 's',
      'thumbnail_url': '',
      'media_items': [],
      'published_at': '2026-10-24T10:00:00+05:30',
    };

/// The shape `GET /api/v1/search/` returned in production (Oct 2026).
Map<String, dynamic> _universal({
  List<Map<String, dynamic>> articles = const [],
  List<Map<String, dynamic>> polls = const [],
  List<Map<String, dynamic>> recommendations = const [],
  List<String> suggestions = const [],
}) =>
    {
      'data': {
        'keyword': 'తెలంగాణ',
        'result_count': articles.length,
        'universal_result_count': articles.length + polls.length,
        'results': articles,
        'suggestions': suggestions,
        'counts': {
          'articles': articles.length,
          'polls': polls.length,
          'recommendations': recommendations.length,
        },
        'sections': {
          'articles': articles,
          'ugc': [],
          'posters': [],
          'polls': polls,
          'quotes': [],
          'categories': [],
          'blogs': [],
          'epapers': [],
          'live_news': [],
          'videos': [],
          'trends': [],
          'recommendations': recommendations,
        },
      },
      'meta': {},
      'errors': null,
    };

class _Api implements HttpClientAdapter {
  _Api(this.reply);

  /// (status, body) for each search request, in order; the last repeats.
  final List<(int, Object)> reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    if (o.path != '/api/v1/search/') {
      return ResponseBody.fromString(jsonEncode({'data': []}), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    requests.add(o);
    final r = reply.length > 1 ? reply.removeAt(0) : reply.first;
    return ResponseBody.fromString(jsonEncode(r.$2), r.$1, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = 'English';
  });

  group('response', () {
    test('sections are read in the recommended order, empty ones dropped', () {
      final r = SearchResult.parse(_universal(
        articles: [_article('a1', 'Telangana news')],
        polls: [
          {'id': 'p1', 'question': 'Who will win?'}
        ],
        recommendations: [_article('r1', 'Popular')],
      ));
      expect(r.hasSections, isTrue);
      expect(r.orderedSections, ['articles', 'polls', 'recommendations']);
      expect(r.universalResultCount, 2, reason: 'recommendations not counted');
      expect(r.noDirectResults, isFalse);
    });

    test('only recommendations: no direct results, but not empty', () {
      final r = SearchResult.parse(
          _universal(recommendations: [_article('r1', 'Popular')]));
      expect(r.noDirectResults, isTrue);
      expect(r.isEmpty, isFalse);
    });

    test('older backend without sections: results as articles', () {
      final r = SearchResult.parse({
        'data': {
          'results': [_article('a1', 'Old')],
          'suggestions': [],
        }
      });
      expect(r.hasSections, isFalse);
      expect(r.results.single.title, 'Old');
      expect(r.noDirectResults, isFalse);
    });

    test('a missing articles key falls back to results; others to empty',
        () {
      final r = SearchResult.parse({
        'data': {
          'results': [_article('a1', 'From results')],
          'universal_result_count': 1,
          'sections': {'polls': []},
        }
      });
      expect(r.hasSections, isTrue);
      expect(r.articles.single.title, 'From results');
      expect(r.section('videos'), isEmpty);
    });

    test('status codes map to the handover messages', () {
      expect(SearchResult.errorKindFor(400), SearchErrorKind.invalidQuery);
      expect(SearchResult.errorKindFor(403), SearchErrorKind.forbidden);
      expect(SearchResult.errorKindFor(429), SearchErrorKind.rateLimited);
      expect(SearchResult.errorKindFor(503), SearchErrorKind.unavailable);
      expect(SearchResult.errorKindFor(null), SearchErrorKind.unavailable);
    });

    test('item titles and pictures come from each section\'s own fields', () {
      expect(searchItemTitle({'question': 'Q?'}), 'Q?');
      expect(searchItemTitle({'term': 'IPL'}), 'IPL');
      expect(
          searchItemImage({
            'media_items': [
              {'media_type': 'video', 'url': 'https://x/v.mp4'},
              {'media_type': 'image', 'url': 'https://x/p.jpg'},
            ]
          }),
          'https://x/p.jpg');
    });
  });

  group('request', () {
    test('Telugu goes as typed, with lang (no language / paging)', () async {
      final api = _Api([(200, _universal())]);
      ApiClient.instance.dio.httpClientAdapter = api;
      await ApiService.instance.search('తెలంగాణ', lang: 'te');
      final q = api.requests.single.queryParameters;
      expect(q['q'], 'తెలంగాణ');
      expect(q['lang'], 'te');
      expect(q.containsKey('language'), isFalse);
      expect(q.containsKey('page'), isFalse);
      expect(q.containsKey('page_size'), isFalse);
      expect(api.requests.single.uri.toString(),
          contains(Uri.encodeQueryComponent('తెలంగాణ')));
    });

    test('empty query: no request', () async {
      final api = _Api([(200, _universal())]);
      ApiClient.instance.dio.httpClientAdapter = api;
      final r = await ApiService.instance.search('   ');
      expect(api.requests, isEmpty);
      expect(r.isEmpty, isTrue);
    });

    test('401 is retried once (as a guest), then succeeds', () async {
      final api = _Api([
        (401, {'errors': {'detail': 'expired'}}),
        (200, _universal(articles: [_article('a1', 'x')])),
      ]);
      ApiClient.instance.dio.httpClientAdapter = api;
      final r = await ApiService.instance.search('x');
      expect(api.requests, hasLength(2));
      expect(r.errorKind, isNull);
    });

    test('429 is reported, not retried', () async {
      final api = _Api([(429, {'errors': {'detail': 'slow down'}})]);
      ApiClient.instance.dio.httpClientAdapter = api;
      final r = await ApiService.instance.search('x');
      expect(api.requests, hasLength(1));
      expect(r.errorKind, SearchErrorKind.rateLimited);
    });
  });

  group('screen', () {
    Future<void> type(WidgetTester t, String text) async {
      await t.enterText(find.byType(TextField), text);
      await t.pump(const Duration(milliseconds: 500)); // debounce
      await t.pump();
      await t.pump();
    }

    testWidgets('grouped sections, with the counts', (t) async {
      ApiClient.instance.dio.httpClientAdapter = _Api([
        (
          200,
          _universal(
            articles: [_article('a1', 'Telangana news')],
            polls: [
              {'id': 'p1', 'question': 'Who will win?'}
            ],
            recommendations: [_article('r1', 'Popular story')],
          )
        )
      ]);
      await t.pumpWidget(const MaterialApp(home: SearchScreen()));
      await type(t, 'తెలంగాణ');
      expect(find.byKey(const ValueKey('universal_search_results')),
          findsOneWidget);
      expect(find.text('Articles (1)'), findsOneWidget);
      expect(find.text('Polls (1)'), findsOneWidget);
      expect(find.text('Recommended for you'), findsOneWidget,
          reason: 'no count on recommendations');
      expect(find.text('Who will win?'), findsOneWidget);
    });

    testWidgets('typing waits for the pause; nothing for an empty box',
        (t) async {
      final api = _Api([(200, _universal())]);
      ApiClient.instance.dio.httpClientAdapter = api;
      await t.pumpWidget(const MaterialApp(home: SearchScreen()));
      await t.enterText(find.byType(TextField), 'te');
      await t.pump(const Duration(milliseconds: 200));
      expect(api.requests, isEmpty, reason: 'still typing');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      expect(api.requests, hasLength(1));
      await t.enterText(find.byType(TextField), '');
      await t.pump(const Duration(seconds: 1));
      expect(api.requests, hasLength(1));
    });

    testWidgets('server trouble: message and Retry, the text kept',
        (t) async {
      final api = _Api([
        (503, {'errors': {'detail': 'down'}}),
        (200, _universal(articles: [_article('a1', 'Back')])),
      ]);
      ApiClient.instance.dio.httpClientAdapter = api;
      await t.pumpWidget(const MaterialApp(home: SearchScreen()));
      await type(t, 'news');
      expect(find.text('Search is temporarily unavailable. Please try again.'),
          findsOneWidget);
      expect(find.text('news'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('search_retry')));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(api.requests, hasLength(2));
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('429: the wait message, no Retry button', (t) async {
      ApiClient.instance.dio.httpClientAdapter =
          _Api([(429, {'errors': {'detail': 'slow'}})]);
      await t.pumpWidget(const MaterialApp(home: SearchScreen()));
      await type(t, 'news');
      expect(find.text('Too many searches. Please wait and try again.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('search_retry')), findsNothing);
    });

    testWidgets('nothing anywhere: No results found', (t) async {
      ApiClient.instance.dio.httpClientAdapter = _Api([(200, _universal())]);
      await t.pumpWidget(const MaterialApp(home: SearchScreen()));
      await type(t, 'zzzz');
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.byKey(const ValueKey('universal_search_results')),
          findsNothing);
    });
  });
}
