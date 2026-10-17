import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/media/media_source.dart';
import 'package:vaaradhi/core/media/video_playback_controller.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/services/analytics_queue.dart';
import 'package:vaaradhi/services/content_analytics.dart';
import 'package:vaaradhi/utils/share_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Vaaradhi APK analytics handover (articles and UGC).

const _articleId = '11111111-2222-3333-4444-555555555555';
const _ugcId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

NewsArticle _story({String id = _articleId, String kind = 'article'}) =>
    NewsArticle.fromJson({
      'id': id,
      'slug': 'some-slug',
      'title': 't',
      'feed_item_type': kind,
      'published_at': DateTime(2026, 10, 1).toIso8601String(),
    });

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  final List<int> status;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    requests.add(o);
    final s = status.length > 1 ? status.removeAt(0) : status.first;
    return ResponseBody.fromString(jsonEncode({'data': {}}), s, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

AnalyticsQueue _queue(_Adapter a) => AnalyticsQueue.forTesting(
    Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = a)
  ..resetForTest();

class _FakeVideo extends VideoPlaybackController {
  _FakeVideo()
      : super(const MediaSource(
            type: MediaSourceType.networkVideo, thumbnailUrl: ''));

  void set(PlaybackStatus s, {int pos = 0, int dur = 100}) =>
      value = value.copyWith(
          status: s,
          position: Duration(seconds: pos),
          duration: Duration(seconds: dur));

  @override
  Future<void> initialize() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> setLooping(bool looping) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AnalyticsQueue.instance.resetForTest();
  });

  List<Map<String, dynamic>> events() => AnalyticsQueue.instance.pending;

  group('content id', () {
    test('article -> article_id, UGC -> submission_id, never both', () async {
      final q = AnalyticsQueue.instance;
      await q.trackContent('article_open', _story());
      await q.trackContent('article_open', _story(id: _ugcId, kind: 'ugc'));
      expect(events()[0]['article_id'], _articleId);
      expect(events()[0].containsKey('submission_id'), isFalse);
      expect(events()[1]['submission_id'], _ugcId);
      expect(events()[1].containsKey('article_id'), isFalse);
      for (final e in events()) {
        // guest_id is the installation id (empty in tests); session_id
        // alone also satisfies the backend.
        expect(e['session_id'], isNotNull);
        expect(e['device_type'], isNotNull);
        expect(e['language'], isNotNull);
      }
    });

    test('no UUID (slug only): nothing sent', () async {
      await AnalyticsQueue.instance
          .trackContent('article_open', _story(id: 'some-slug'));
      expect(events(), isEmpty);
    });

    test('only the event types the backend supports are queued', () async {
      await AnalyticsQueue.instance.trackContent('feed_refresh', _story());
      await AnalyticsQueue.instance.track('category_select');
      expect(events(), isEmpty);
    });

    test('dwell is capped at 86400 and depth at 100', () async {
      await AnalyticsQueue.instance.trackContent('scroll_depth', _story(),
          dwellSeconds: 999999, scrollDepth: 150);
      expect(events().single['dwell_seconds'], 86400);
      expect(events().single['scroll_depth'], 100);
    });
  });

  group('queue delivery', () {
    test('202: sent once and removed; batches of at most 100', () async {
      final a = _Adapter([202]);
      final q = _queue(a);
      for (var i = 0; i < 130; i++) {
        await q.trackContent('article_impression', _story());
      }
      await q.flush();
      expect(q.pending, isEmpty);
      final sizes =
          a.requests.map((r) => (r.data['events'] as List).length).toList();
      expect(sizes.every((n) => n <= 100), isTrue);
      expect(sizes.fold<int>(0, (s, n) => s + n), 130,
          reason: 'each event sent exactly once');
      expect(a.requests.first.path, '/api/v1/analytics/events/bulk/');
    });

    test('400: the bad batch is dropped so later events still go', () async {
      final q = _queue(_Adapter([400, 202]));
      await q.trackContent('article_open', _story());
      await q.flush();
      expect(q.pending, isEmpty);
    });

    test('5xx, 429 and 401: events kept for a retry', () async {
      for (final s in [503, 429, 401]) {
        final q = _queue(_Adapter([s]));
        await q.trackContent('article_open', _story());
        await q.flush();
        expect(q.pending, hasLength(1), reason: 'status $s');
      }
    });
  });

  group('reading', () {
    test(
        'open, milestones once, completion at 90 % after a moment, '
        'reading time on close', () {
      final r = ReadingTracker(_story());
      r.opened();
      r.scrolledTo(30);
      r.scrolledTo(30);
      r.scrolledTo(80);
      final now = DateTime.now();
      r.tick(now: now);
      r.tick(now: now);
      r.scrolledTo(95);
      expect(
          events().where((e) => e['event_type'] == 'read_completion'), isEmpty,
          reason: 'less than 3 s of reading');
      r.tick(now: now);
      r.closed();

      final types = events().map((e) => e['event_type']).toList();
      expect(types.first, 'article_open');
      final depths = events()
          .where((e) =>
              e['event_type'] == 'scroll_depth' && e['dwell_seconds'] == null)
          .map((e) => e['scroll_depth']);
      expect(depths, [25, 50, 75]);
      expect(types.where((t) => t == 'read_completion'), hasLength(1));
      final last = events().last;
      expect(last['event_type'], 'scroll_depth');
      expect(last['dwell_seconds'], 3);
      expect(last['scroll_depth'], 95);
    });

    test('time does not count while covered or idle', () {
      var onTop = false;
      final r = ReadingTracker(_story(), isOnTop: () => onTop);
      r.opened();
      r.tick();
      expect(r.activeSeconds, 0);
      onTop = true;
      r.tick(now: DateTime.now().add(const Duration(minutes: 5)));
      expect(r.activeSeconds, 0, reason: 'idle for 5 minutes');
      r.tick();
      expect(r.activeSeconds, 1);
      r.closed();
    });

    test('a story opened by slug sends open once its UUID arrives', () {
      final r = ReadingTracker(_story(id: 'just-a-slug'));
      r.opened();
      expect(events(), isEmpty);
      r.updateStory(_story());
      expect(events().single['event_type'], 'article_open');
      r.closed();
    });
  });

  group('video', () {
    test(
        'start once, progress every 15 s with interval dwell, complete at '
        '90 %', () {
      final c = _FakeVideo();
      final w =
          VideoWatchTracker(_story(id: _ugcId, kind: 'ugc'), c, source: 's3');
      expect(events(), isEmpty, reason: 'shown, not playing');

      c.set(PlaybackStatus.playing, pos: 0);
      var t = DateTime.now();
      for (var i = 1; i <= 16; i++) {
        t = t.add(const Duration(seconds: 1));
        c.set(PlaybackStatus.playing, pos: i);
        w.advance(now: t);
      }
      // Paused: no time counts.
      c.set(PlaybackStatus.paused, pos: 16);
      // Resumed near the end.
      c.set(PlaybackStatus.playing, pos: 90);
      t = DateTime.now().add(const Duration(seconds: 1));
      w.advance(now: t);
      w.dispose();

      final types = events().map((e) => e['event_type']).toList();
      expect(types.where((x) => x == 'video_start'), hasLength(1));
      final progress =
          events().firstWhere((e) => e['event_type'] == 'video_progress');
      expect(progress['dwell_seconds'], 15);
      expect(progress['submission_id'], _ugcId);
      expect(types.where((x) => x == 'video_complete'), hasLength(1));
      final complete =
          events().firstWhere((e) => e['event_type'] == 'video_complete');
      expect(
          complete['metadata']['progress_percent'], greaterThanOrEqualTo(90));
      expect(complete['dwell_seconds'], lessThan(15));
    });
  });

  group('share', () {
    test('counted when shared, not when the sheet is dismissed', () {
      ShareService.trackShare(
          _story(), const ShareResult('', ShareResultStatus.dismissed));
      expect(events(), isEmpty);
      ShareService.trackShare(_story(),
          const ShareResult('com.whatsapp', ShareResultStatus.success));
      expect(events().single['event_type'], 'share');
      expect(events().single['metadata'], {'channel': 'whatsapp'});
    });
  });

  testWidgets('impression: half visible for a second, once per screen',
      (tester) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final log = ImpressionLog();
    Widget card() => MaterialApp(
          home: ImpressionScope(
            log: log,
            child: ImpressionTracker(
              story: _story(),
              child: const SizedBox(width: 200, height: 100),
            ),
          ),
        );
    await tester.pumpWidget(card());
    await tester.pump(const Duration(milliseconds: 500));
    expect(events(), isEmpty, reason: 'not yet a second');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(events().single['event_type'], 'article_impression');

    // Rebuilt in the same screen session: not counted again.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(card());
    await tester.pump(const Duration(seconds: 2));
    expect(events(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}
