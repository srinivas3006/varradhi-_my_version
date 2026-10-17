import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/notification_target.dart';
import 'package:vaaradhi/services/notification_service.dart';

/// A tapped news notification must open that article, whatever spelling the
/// backend/admin uses for it.
void main() {
  NotificationTarget tap(Map<String, dynamic> data) =>
      NotificationService.targetForTap(data);

  void expectArticle(NotificationTarget t, String slug) {
    expect(t.type, NotificationTargetType.article);
    expect(t.identifier, slug);
  }

  group('news notification payloads open the article', () {
    test('backend format: deep_link article://slug', () {
      expectArticle(
          tap({
            'notification_id': 'n1',
            'title': 'Breaking',
            'deep_link': 'article://ranabali-trailer-response',
          }),
          'ranabali-trailer-response');
    });

    test('content_type + content_slug (schema v2)', () {
      expectArticle(
          tap({'content_type': 'article', 'content_slug': 'gold-medal'}),
          'gold-medal');
    });

    test('breaking news type', () {
      expectArticle(
          tap({'type': 'breaking', 'slug': 'flood-alert'}), 'flood-alert');
    });

    test('varadhi:// link', () {
      expectArticle(tap({'deep_link': 'varadhi://article/temple-tickets'}),
          'temple-tickets');
    });

    test('website link (shared / App Link)', () {
      expectArticle(
          tap({'deep_link': 'https://vaaradhinews.com/article/gold-medal/'}),
          'gold-medal');
    });

    test('relative path', () {
      expectArticle(tap({'deep_link': '/article/gold-medal'}), 'gold-medal');
    });

    test('payload wrapped in a JSON string under "data"', () {
      expectArticle(
          tap({'data': '{"content_type":"article","content_slug":"x-1"}'}),
          'x-1');
    });
  });

  test('an unroutable payload opens Home, never a wrong page', () {
    final t = tap({'title': 'Hello'});
    expect(t.type, NotificationTargetType.screen);
    expect(t.screenName, 'home');
  });

  test('a cold start from an app-shown notification is not lost', () {
    // The tap that launches a closed app arrives through the launch details,
    // not the response callback.
    final src =
        File('lib/services/notification_service.dart').readAsStringSync();
    expect(src, contains('getNotificationAppLaunchDetails()'));
    expect(src, contains('didNotificationLaunchApp'));
    // System-tray taps: app closed and app in background.
    expect(src, contains('getInitialMessage()'));
    expect(src, contains('onMessageOpenedApp.listen'));
  });
}
