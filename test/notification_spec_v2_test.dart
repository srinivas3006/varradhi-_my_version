import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/navigation/notification_deep_link_resolver.dart';
import 'package:vaaradhi/models/notification_target.dart';
import 'package:vaaradhi/services/analytics_queue.dart';
import 'package:vaaradhi/services/notification_service.dart';

/// Push notification tap handover (schema_version 2): structured fields
/// first, deep_link as the fallback, every link format the backend sends.
void main() {
  NotificationTarget payload(Map<String, dynamic> d) =>
      NotificationDeepLinkResolver.resolveFromPayload(d);
  NotificationTarget link(String l) => payload({'deep_link': l});

  test('the tested production payload opens the article by slug', () {
    final t = payload({
      'notification_id': '77accce8-aec3-4338-9391-15b4c55b629a',
      'deep_link': '/article/article-f187341121af',
      'type': 'all',
      'notification_type': 'alert',
      'content_type': 'article',
      'content_id': 'd837b876-0d8c-4064-a190-fc26cdb2c7a1',
      'content_slug': 'article-f187341121af',
      'schema_version': '2',
    });
    expect(t.type, NotificationTargetType.article);
    expect(t.identifier, 'article-f187341121af');
    expect(t.notificationId, '77accce8-aec3-4338-9391-15b4c55b629a');
  });

  test('article without a slug opens through deep_link', () {
    // The article detail API takes the slug only (/articles/<uuid>/ is 404,
    // checked live), so content_id alone cannot open it; deep_link can.
    final t = payload({
      'content_type': 'article',
      'content_id': 'd837b876-0d8c-4064-a190-fc26cdb2c7a1',
      'deep_link': '/article/article-f187341121af',
    });
    expect(t.type, NotificationTargetType.article);
    expect(t.identifier, 'article-f187341121af');
  });

  test('structured UGC / poster / poll / video', () {
    for (final (type, expected) in [
      ('ugc', NotificationTargetType.ugc),
      ('poster', NotificationTargetType.poster),
      ('poll', NotificationTargetType.poll),
      ('video', NotificationTargetType.video),
    ]) {
      final t = payload({'content_type': type, 'content_id': 'id-9'});
      expect(t.type, expected, reason: type);
      expect(t.identifier, 'id-9', reason: type);
    }
  });

  group('deep_link formats', () {
    test('relative /article/<slug>', () {
      final t = link('/article/my-slug');
      expect(t.type, NotificationTargetType.article);
      expect(t.identifier, 'my-slug');
    });

    test('relative /ugc /poster /poll /video', () {
      expect(link('/ugc/u1').type, NotificationTargetType.ugc);
      expect(link('/poster/p1').type, NotificationTargetType.poster);
      expect(link('/poll/q1').type, NotificationTargetType.poll);
      expect(link('/video/v1').type, NotificationTargetType.video);
    });

    test('https on both public hosts', () {
      for (final host in ['vaaradhinews.com', 'www.vaaradhinews.com']) {
        final t = link('https://$host/article/my-slug/');
        expect(t.type, NotificationTargetType.article, reason: host);
        expect(t.identifier, 'my-slug', reason: host);
      }
    });

    test('legacy custom schemes', () {
      final a = link('article://my-slug');
      expect(a.type, NotificationTargetType.article);
      expect(a.identifier, 'my-slug');
      expect(link('ugc://u1').identifier, 'u1');
      expect(link('ugc://u1').type, NotificationTargetType.ugc);
      expect(link('poster://p1').type, NotificationTargetType.poster);
      expect(link('poll://q1').type, NotificationTargetType.poll);
      expect(link('video://v1').type, NotificationTargetType.video);
    });

    test('varadhi://category/<slug>', () {
      final t = link('varadhi://category/politics');
      expect(t.type, NotificationTargetType.category);
      expect(t.identifier, 'politics');
    });

    test('screen://notifications', () {
      final t = link('screen://notifications');
      expect(t.type, NotificationTargetType.screen);
      expect(t.screenName, 'notifications');
    });
  });

  group('tap handling', () {
    test('the same notification within 10 s is handled once', () {
      final s = NotificationService.instance;
      final t0 = DateTime(2026, 10, 16, 12);
      final data = {'notification_id': 'n-dup-1'};
      expect(s.shouldHandle(data, now: t0), isTrue);
      expect(s.shouldHandle(data, now: t0.add(const Duration(seconds: 3))),
          isFalse);
      expect(s.shouldHandle(data, now: t0.add(const Duration(seconds: 11))),
          isTrue);
      expect(s.shouldHandle({'notification_id': 'n-other'}, now: t0), isTrue);
    });

    test('an unroutable payload opens Home', () {
      final t = NotificationService.targetForTap({'title': 'x'});
      expect(t.type, NotificationTargetType.screen);
      expect(t.screenName, 'home');
    });

    test('notification_opened goes out after the screen opens, by its id',
        () async {
      final sent = <RequestOptions>[];
      final q = AnalyticsQueue.forTesting(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = _Capture(sent));
      await q.notificationOpened('push_123'); // device-only id: not sent
      await q.notificationOpened('77accce8-aec3-4338-9391-15b4c55b629a');
      expect(sent.single.path, '/api/v1/analytics/events/');
      final body = sent.single.data as Map;
      expect(body['event_type'], 'notification_opened');
      expect(body['notification_id'], '77accce8-aec3-4338-9391-15b4c55b629a');
      expect(body['session_id'], isNotNull);

      final src =
          File('lib/services/notification_service.dart').readAsStringSync();
      final router =
          src.substring(src.indexOf('Future<void> navigateToTarget('));
      expect(router.indexOf('if (_routeOpened)'),
          greaterThan(router.indexOf('switch (target.type)')),
          reason: 'sent only after navigation, not on receipt');
    });
  });
}

class _Capture implements HttpClientAdapter {
  _Capture(this.sent);
  final List<RequestOptions> sent;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    sent.add(o);
    return ResponseBody.fromString('{"data":{"status":"accepted"}}', 202,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}
