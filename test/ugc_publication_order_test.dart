import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/feed/ugc_feed_freshness.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/unified_feed_item.dart';
import 'package:vaaradhi/repositories/ugc_repository.dart';
import 'package:vaaradhi/screens/ugc_feed_screen.dart';
import 'package:vaaradhi/services/api_service.dart';

const nextUrl =
    'https://api.vaaradhinews.com/api/v1/ugc/feed/?cursor=abc&scope=main';

Map<String, dynamic> post(String id, {String? published, String? created}) => {
      'id': id,
      'type': 'ugc',
      'title': 'Post $id',
      'description': 'Text',
      'language': 'te',
      if (published != null) 'published_at': published,
      'created_at': created ?? '2026-11-02T18:20:10+05:30',
      'district': 'Vikarabad',
      'state': 'Telangana',
    };

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final pages = <Map<String, dynamic>>[];
  bool fail = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    requests.add(options);
    if (fail) {
      return ResponseBody.fromString(
          jsonEncode({'data': null, 'errors': 'down'}), 500,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
    }
    return ResponseBody.fromString(jsonEncode(pages.removeAt(0)), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> page(List<Map<String, dynamic>> data, {String? next}) => {
      'data': data,
      'meta': {'next': next, 'previous': null},
      'errors': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Adapter adapter;
  late HttpClientAdapter previous;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = ApiClient.instance.dio.httpClientAdapter;
    adapter = _Adapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
  });
  tearDown(() => ApiClient.instance.dio.httpClientAdapter = previous);

  group('the time shown', () {
    test('published_at beats created_at in the feed', () async {
      adapter.pages.add(page([
        post('a', published: '2026-11-03T11:45:20+05:30'),
      ]));
      final res = await UgcRepository.instance.getUgcFeed(scope: 'main');
      expect(res.data!.single.publishedAt,
          DateTime.parse('2026-11-03T11:45:20+05:30'));
    });

    test('created_at is only the fallback', () async {
      adapter.pages.add(page([post('old')]));
      final res = await UgcRepository.instance.getUgcFeed(scope: 'main');
      expect(res.data!.single.publishedAt,
          DateTime.parse('2026-11-02T18:20:10+05:30'));
    });

    test('search results and Home items read it the same way', () {
      final item = UnifiedFeedItem.fromJson({
        'id': 'x',
        'type': 'ugc',
        'published_at': '2026-11-03T11:45:20+05:30',
        'created_at': '2026-11-02T18:20:10+05:30',
      });
      expect(item.toArticle().publishedAt,
          DateTime.parse('2026-11-03T11:45:20+05:30'));
    });
  });

  group('pagination', () {
    test('meta.next is requested exactly, never nested in cursor=', () async {
      adapter.pages
        ..add(page([post('a')], next: nextUrl))
        ..add(page([post('b')]));
      final first = await ApiService.instance.getUgcFeed(scope: 'main');
      expect(first.nextCursor, nextUrl);

      final second = await ApiService.instance
          .getUgcFeed(scope: 'main', cursor: first.nextCursor);
      final request = adapter.requests.last;
      expect(request.uri.toString(), nextUrl);
      expect(request.uri.queryParameters['cursor'], 'abc');
      expect(second.nextCursor, isNull, reason: 'stop at a null meta.next');
    });
  });

  test('a feed is stale after 45 seconds', () {
    final t = DateTime(2026, 11, 3, 12);
    expect(UgcFeedFreshness.isStale(null), isTrue);
    expect(UgcFeedFreshness.isStale(t, now: t.add(const Duration(seconds: 44))),
        isFalse);
    expect(UgcFeedFreshness.isStale(t, now: t.add(const Duration(seconds: 45))),
        isTrue);
  });

  group('the Citizen News list', () {
    // The request goes through both the widget test clock (interceptors) and
    // real time (Dio's response stream), so turn each in several rounds.
    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 20));
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await t.pump();
    }

    List<String> titles(WidgetTester t) => t
        .widgetList<Text>(find.textContaining('Post '))
        .map((w) => w.data!)
        .toList();

    testWidgets('keeps the backend order and asks for scope=main', (t) async {
      adapter.pages.add(page([
        // Deliberately not date-sorted: only the backend decides the order.
        post('b', published: '2026-11-01T10:00:00+05:30'),
        post('a', published: '2026-11-03T10:00:00+05:30'),
      ]));
      await t.pumpWidget(const MaterialApp(home: UgcFeedScreen()));
      await settle(t);
      expect(titles(t), ['Post b', 'Post a']);
      expect(adapter.requests.first.queryParameters['scope'], 'main');
    });

    testWidgets('a refresh replaces page one, without the cursor', (t) async {
      adapter.pages
        ..add(page([post('a')], next: nextUrl))
        ..add(page([post('new'), post('a'), post('new')]));
      await t.pumpWidget(const MaterialApp(home: UgcFeedScreen()));
      await settle(t);

      UgcFeedFreshness.notifyPublished();
      await settle(t);

      expect(titles(t), ['Post new', 'Post a'], reason: 'replaced and deduped');
      final request = adapter.requests.last;
      expect(request.path, '/api/v1/ugc/feed/');
      expect(request.queryParameters.containsKey('cursor'), isFalse);
    });

    testWidgets('a failed refresh leaves the list as it is', (t) async {
      adapter.pages.add(page([post('a')]));
      await t.pumpWidget(const MaterialApp(home: UgcFeedScreen()));
      await settle(t);

      adapter.fail = true;
      UgcFeedFreshness.notifyPublished();
      await settle(t);

      expect(titles(t), ['Post a']);
    });
  });

  test('Spotlight: page one replaces citizen posts only when it loaded', () {
    final src = File('lib/spotlight/spotlight_controller.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(
        src,
        contains('if (!ugc.hasErrors) {\n'
            '        // A refreshed page one replaces the list; '
            'a failed one leaves it.\n'
            '        if (refresh) _ugcItems.clear();'));
  });

  test('Spotlight refreshes on its own only on the first card', () {
    final src = File('lib/spotlight/spotlight_screen.dart').readAsStringSync();
    expect(src, contains('if (_currentPage.value != 0) return;'));
    expect(src, contains('UgcFeedFreshness.published.addListener'));
  });

  test('a citizen-news notification asks open lists to refresh', () {
    final src =
        File('lib/services/notification_service.dart').readAsStringSync();
    expect('UgcFeedFreshness.notifyPublished()'.allMatches(src).length, 2);
  });
}
