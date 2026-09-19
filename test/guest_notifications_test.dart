import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/navigation/notification_deep_link_resolver.dart';
import 'package:way2news_clone/models/notification_target.dart';

void main() {
  group('a tap resolves from the payload, not to Home', () {
    // Regression: the resolver read only `content_type`. A payload keyed
    // `type` or `entity_type` resolved to unknown, the gate dropped it, and
    // the reader was left on Home.
    for (final key in ['content_type', 'type', 'entity_type',
        'notification_type']) {
      test('an article keyed by "$key" resolves to the article', () {
        final t = NotificationDeepLinkResolver.resolveFromPayload({
          key: 'article',
          'content_id': '42',
        });
        expect(t.type, NotificationTargetType.article);
        expect(t.identifier, '42');
      });
    }

    test('a video payload opens the story that carries it', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload(
          {'type': 'video', 'content_id': '7'});
      expect(t.type, NotificationTargetType.article);
    });

    test('ugc keeps its own destination rather than becoming an article', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload(
          {'type': 'ugc', 'content_id': '7'});
      expect(t.type, NotificationTargetType.ugc);
      expect(t.requiresAuth, isFalse);
    });

    test('content_id, article_id and slug are all accepted', () {
      expect(
        NotificationDeepLinkResolver.resolveFromPayload(
            {'type': 'news', 'article_id': '9'}).identifier,
        '9',
      );
      expect(
        NotificationDeepLinkResolver.resolveFromPayload(
            {'type': 'news', 'content_slug': 'a-slug'}).identifier,
        'a-slug',
      );
    });

    test('a payload with no destination falls back safely', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload(
          {'title': 'hello', 'body': 'world'});
      expect(t.type, NotificationTargetType.unknown,
          reason: 'Home is correct only when nothing is addressable');
    });

    test('an empty payload does not throw', () {
      expect(
        () => NotificationDeepLinkResolver.resolveFromPayload({}),
        returnsNormally,
      );
    });

    test('a nested data payload is unwrapped', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload({
        'data': {'type': 'article', 'content_id': '11'},
      });
      expect(t.type, NotificationTargetType.article);
      expect(t.identifier, '11');
    });
  });

  group('guest article destinations do not demand login', () {
    test('an article target is publicly reachable', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload(
          {'type': 'article', 'content_id': '42'});
      expect(t.requiresAuth, isFalse,
          reason: 'a guest tapping a news notification must reach the story');
    });
  });

  group('the token is registered when it is acquired', () {
    final src =
        File('lib/services/notification_service.dart').readAsStringSync();

    test('initEarly registers the token, not just stores it', () {
      final block = src.substring(src.indexOf('token acquired'));
      final head = block.substring(0, 1200);
      expect(head, contains('updateFcmToken'),
          reason: 'storing it locally left the backend with no device record');
    });

    test('registration is not gated on being signed in', () {
      final block = src.substring(src.indexOf('token acquired'));
      final head = block.substring(0, 1200);
      expect(head, isNot(contains('if (AppState.instance.isLoggedIn)')),
          reason: 'guests must register too');
    });

    test('logout never deletes the FCM token', () {
      final all = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(all, isNot(contains('deleteToken(')),
          reason: 'a logged-out device must stay notification-capable');
    });
  });
}
