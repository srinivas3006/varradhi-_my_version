import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/navigation/app_navigator.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/features/reels/reel_item.dart';
import 'package:vaaradhi/features/reels/reel_model.dart';
import 'package:vaaradhi/features/reels/reels_api.dart';
import 'package:vaaradhi/features/reels/reels_controller.dart';
import 'package:vaaradhi/features/reels/reels_screen.dart';
import 'package:vaaradhi/screens/home_screen.dart';
import 'package:vaaradhi/widgets/bottom_nav_bar.dart';

/// Answers in order from [responses] (status, body); records each request.
class _Api implements HttpClientAdapter {
  _Api(this.handler);
  final (int, Object) Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
      Future<void>? __) async {
    requests.add(o);
    final (status, body) = handler(o);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ReelsApi _reelsApi(_Api a, {String? token}) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.test',
    validateStatus: (_) => true,
  ))
    ..httpClientAdapter = a;
  return ReelsApi(dio: dio, authToken: token)..wait = (_) async {};
}

Map<String, dynamic> _reel(String id,
        {String yt = '', String video = '', String url = ''}) =>
    {
      'id': id,
      'title': 'Reel $id',
      'thumbnail_url': '',
      'youtube_video_id': yt,
      'youtube_url': url,
      'video_url': video,
      'share_url': 'https://vaaradhinews.com/video/$id/',
      'channel_name': 'Vaaradhi News',
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items, String? next) =>
    {'data': items, 'meta': {'next': next}, 'errors': null};

/// Waits until the controller has no page request in flight.
Future<void> _settle(ReelsController c) async {
  for (var i = 0; i < 50 && (c.isLoadingMore || c.isLoadingFirst); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('media selection', () {
    Reel r(Map<String, dynamic> j) => Reel.fromJson(j);

    test('video_url wins over YouTube', () {
      expect(r(_reel('a', yt: 'DFDuzTEaVOc', video: 'https://cdn/a.mp4'))
          .mediaType, ReelMediaType.native);
    });

    test('a valid YouTube id plays on YouTube', () {
      expect(r(_reel('a', yt: 'DFDuzTEaVOc')).mediaType,
          ReelMediaType.youtube);
    });

    test('an id is found in a YouTube URL too', () {
      final reel = r(_reel('a', url: 'https://youtube.com/shorts/DFDuzTEaVOc'));
      expect(reel.youtubeId, 'DFDuzTEaVOc');
    });

    test('local- ids are uploads, never YouTube', () {
      final reel = r(_reel('a', yt: 'local-12345'));
      expect(reel.youtubeId, isNull);
      expect(reel.mediaType, ReelMediaType.unavailable);
    });

    test('nothing playable is "unavailable"', () {
      expect(r(_reel('a')).mediaType, ReelMediaType.unavailable);
    });

    test('share uses share_url, else the public page', () {
      expect(r(_reel('a')).safeShareUrl, 'https://vaaradhinews.com/video/a/');
      final bare = r({'id': 'b'});
      expect(bare.safeShareUrl, 'https://vaaradhinews.com/video/b/');
    });
  });

  group('the shorts-feed API', () {
    test('main scope, page size and every location field sent', () async {
      final a = _Api((_) => (200, _page([_reel('1')], null)));
      await _reelsApi(a).fetch(location: {
        'state': 'Telangana',
        'district': 'Suryapet',
        'subdistrict': 'Jajireddygudem',
        'village': 'Kesaram',
        'city': '  ',
      });
      final q = a.requests.single.queryParameters;
      expect(a.requests.single.path, '/api/v1/articles/shorts-feed/');
      expect(q['scope'], 'main');
      expect(q['page_size'], 20);
      expect(q['state'], 'Telangana');
      expect(q['village'], 'Kesaram');
      expect(q.containsKey('city'), isFalse, reason: 'blank values left out');
    });

    test('page_size is kept within 1–50', () async {
      final a = _Api((_) => (200, _page([], null)));
      await _reelsApi(a).fetch(pageSize: 500);
      expect(a.requests.single.queryParameters['page_size'], 50);
    });

    test('the next page is meta.next exactly', () async {
      const next =
          'https://api.vaaradhinews.com/api/v1/articles/shorts-feed/?cursor=abc';
      final a = _Api((_) => (200, _page([], null)));
      await _reelsApi(a).fetch(nextUrl: next);
      expect(a.requests.single.uri.toString(), next);
    });

    test('a 401 drops the token and retries anonymously', () async {
      final a = _Api((o) => o.headers.containsKey('Authorization')
          ? (401, {'errors': {'message': 'Token expired'}})
          : (200, _page([_reel('1')], null)));
      final api = _reelsApi(a, token: 'old');
      final page = await api.fetch();
      expect(page.items.single.id, '1');
      expect(a.requests, hasLength(2));
      expect(a.requests.last.headers.containsKey('Authorization'), isFalse);
      expect(api.authToken, isNull);
    });

    test('a 429 backs off and retries', () async {
      var calls = 0;
      final a = _Api((_) =>
          ++calls < 3 ? (429, {'errors': {'message': 'Slow down'}}) : (200, _page([_reel('1')], null)));
      final waits = <Duration>[];
      final api = _reelsApi(a)..wait = (d) async => waits.add(d);
      final page = await api.fetch();
      expect(page.items, hasLength(1));
      expect(waits, [const Duration(seconds: 2), const Duration(seconds: 4)]);
    });

    test('400 is an invalid cursor', () async {
      final a = _Api((_) => (400, {'errors': {'message': 'Invalid cursor.'}}));
      expect(
        () => _reelsApi(a).fetch(nextUrl: 'https://api.test/x?cursor=bad'),
        throwsA(isA<ReelsApiException>()
            .having((e) => e.isInvalidCursor, 'isInvalidCursor', isTrue)
            .having((e) => e.message, 'message', 'Invalid cursor.')),
      );
    });
  });

  group('the Reels list', () {
    test('pages append, dedupe by id, and stop at meta.next == null',
        () async {
      final a = _Api((o) => o.uri.queryParameters['cursor'] == 'p2'
          ? (200, _page([_reel('2'), _reel('3')], null))
          : (200, _page([_reel('1'), _reel('2')], 'https://api.test/x?cursor=p2')));
      final c = ReelsController(api: _reelsApi(a));
      // A short first page (≤3) fetches the next one by itself.
      await c.loadFirstPage();
      await _settle(c);
      expect(c.reels.map((r) => r.id), ['1', '2', '3']);
      expect(c.hasMore, isFalse);
      final before = a.requests.length;
      await c.loadMore();
      expect(a.requests.length, before, reason: 'no request after the end');
    });

    test('only one load-more at a time', () async {
      final gate = Completer<void>();
      var calls = 0;
      final a = _Api((o) {
        calls++;
        return o.uri.queryParameters.containsKey('cursor')
            ? (200, _page([_reel('9')], null))
            : (200, _page(List.generate(10, (i) => _reel('r$i')), 'https://api.test/x?cursor=n'));
      });
      final c = ReelsController(api: _reelsApi(a));
      await c.loadFirstPage();
      final first = c.loadMore();
      final second = c.loadMore(); // ignored while the first runs
      await Future.wait([first, second]);
      expect(calls, 2);
      gate.complete();
    });

    test('an invalid cursor reloads from the first page', () async {
      var firstPages = 0;
      final a = _Api((o) {
        if (o.uri.queryParameters['cursor'] == 'stale') {
          return (400, {'errors': {'message': 'Invalid cursor.'}});
        }
        // The first page, fetched again after the cursor expired, now has
        // one more reel on it.
        return ++firstPages == 1
            ? (200, _page([_reel('1')], 'https://api.test/x?cursor=stale'))
            : (200, _page([_reel('1'), _reel('new')], null));
      });
      final c = ReelsController(api: _reelsApi(a));
      await c.loadFirstPage();
      await _settle(c);
      expect(c.loadMoreFailed, isFalse);
      expect(c.reels.map((r) => r.id), ['1', 'new'],
          reason: 'reloaded, with the duplicate dropped');
    });

    test('a failed load-more keeps the reels already shown', () async {
      final a = _Api((o) => o.uri.queryParameters.containsKey('cursor')
          ? (503, {'errors': {'message': 'Unavailable'}})
          : (200, _page(List.generate(5, (i) => _reel('r$i')), 'https://api.test/x?cursor=n')));
      final c = ReelsController(api: _reelsApi(a));
      await c.loadFirstPage();
      await c.loadMore();
      await _settle(c);
      expect(c.reels, hasLength(5));
      expect(c.loadMoreFailed, isTrue);
    });

    test('a notification\'s video plays first, and is not repeated',
        () async {
      final a = _Api((_) => (200, _page([_reel('1'), _reel('pin')], null)));
      final c = ReelsController(
          api: _reelsApi(a), pinned: Reel.fromJson(_reel('pin')));
      await c.loadFirstPage();
      await _settle(c);
      expect(c.reels.map((r) => r.id), ['pin', '1']);
    });

    test('the pointed-at video stays watchable if the feed fails', () async {
      final a = _Api((_) => (503, {'errors': {'message': 'Server busy'}}));
      final c = ReelsController(
          api: _reelsApi(a), pinned: Reel.fromJson(_reel('pin')));
      await c.loadFirstPage();
      expect(c.reels.single.id, 'pin');
    });

    test('notifications open the same full-screen Reels', () {
      final src = File('lib/services/notification_service.dart')
          .readAsStringSync();
      expect(src, contains('ReelsScreen.route('));
      expect(src, contains('Reel.fromVideo('));
      expect(src, isNot(contains('ShortsViewerScreen(')));
    });

    test('mute is kept across swipes', () {
      final c = ReelsController(api: _reelsApi(_Api((_) => (200, _page([], null)))));
      c.toggleMute();
      c.onPageChanged(1);
      c.onPageChanged(2);
      expect(c.isMuted, isTrue);
    });
  });

  group('the Reels screen', () {
    testWidgets('opens full-screen from Home — no bottom bar — and back returns',
        (tester) async {
      ApiClient.instance.dio.httpClientAdapter =
          _Api((_) => (200, {'data': [], 'meta': {}, 'errors': null}));
      AppNavigator.resetDebounce();
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.byKey(const Key('reels_back')), findsOneWidget);
      // The bottom bar is not on screen while Reels is open.
      expect(find.byType(BottomNavBar).hitTestable(), findsNothing);

      await tester.tap(find.byKey(const Key('reels_back')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(ReelsScreen), findsNothing);
      expect(find.byType(BottomNavBar).hitTestable(), findsOneWidget);
    });

    testWidgets('a reel with nothing playable says so, swipe still works',
        (tester) async {
      final a = _Api((_) => (200, _page([_reel('x'), _reel('y')], null)));
      await tester.pumpWidget(MaterialApp(
          home: ReelsScreen(api: _reelsApi(a), location: const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ReelUnavailable), findsWidgets);
      expect(find.text('Reel x'), findsOneWidget);
      await tester.fling(
          find.byKey(const Key('reels_pager')), const Offset(0, -400), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Reel y'), findsOneWidget);
    });

    testWidgets('a failed first page shows a full-screen retry',
        (tester) async {
      final a = _Api((_) => (503, {'errors': {'message': 'Server busy'}}));
      await tester.pumpWidget(MaterialApp(
          home: ReelsScreen(api: _reelsApi(a), location: const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Server busy'), findsOneWidget);
      expect(find.byKey(const Key('reels_retry')), findsOneWidget);
    });

    testWidgets('an empty feed is not an error', (tester) async {
      final a = _Api((_) => (200, _page([], null)));
      await tester.pumpWidget(MaterialApp(
          home: ReelsScreen(api: _reelsApi(a), location: const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ప్రస్తుతం రీల్స్ లేవు'), findsOneWidget);
    });
  });
}
