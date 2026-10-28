import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/navigation/notification_deep_link_resolver.dart';
import 'package:vaaradhi/models/notification_target.dart';

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
          'content_slug': 'story-42',
        });
        expect(t.type, NotificationTargetType.article);
        expect(t.identifier, 'story-42');
      });
    }

    test('a video payload opens the Reels viewer', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload(
          {'type': 'video', 'content_id': '7'});
      expect(t.type, NotificationTargetType.video);
      expect(t.identifier, '7');
    });

    test('ugc keeps its own destination rather than becoming an article', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload(
          {'type': 'ugc', 'content_id': '7'});
      expect(t.type, NotificationTargetType.ugc);
      expect(t.requiresAuth, isFalse);
    });

    test('articles open by slug; an id alone is not a detail address', () {
      // GET /api/v1/articles/{id}/ is a 404 — detail takes the slug only.
      for (final key in ['content_id', 'article_id']) {
        expect(
          NotificationDeepLinkResolver.resolveFromPayload(
              {'type': 'news', key: '9'}).type,
          isNot(NotificationTargetType.article),
          reason: '$key must not be used as a slug',
        );
      }
      expect(
        NotificationDeepLinkResolver.resolveFromPayload({
          'content_type': 'article',
          'content_id': 'uuid-9',
          'deep_link': '/article/from-link',
        }).identifier,
        'from-link',
        reason: 'no content_slug: the deep_link slug is used, not the id',
      );
      expect(
        NotificationDeepLinkResolver.resolveFromPayload(
            {'type': 'news', 'slug': 's-9'}).identifier,
        's-9',
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
        'data': {'type': 'article', 'content_slug': 'story-11'},
      });
      expect(t.type, NotificationTargetType.article);
      expect(t.identifier, 'story-11');
    });
  });

  group('guest article destinations do not demand login', () {
    test('an article target is publicly reachable', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload(
          {'type': 'article', 'content_slug': 'a-42'});
      expect(t.type, NotificationTargetType.article);
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
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      for (final f in files) {
        final src = f.readAsStringSync().replaceAll('\r\n', '\n');
        // No logout path deletes the token.
        for (final m
            in RegExp(r'Future<void> \w*[lL]ogout\w*\(').allMatches(src)) {
          final rest = src.substring(m.start);
          final end = rest.indexOf('\n  }\n');
          expect(rest.substring(0, end < 0 ? rest.length : end),
              isNot(contains('deleteToken(')),
              reason: 'a logged-out device must stay notification-capable '
                  '(${f.path})');
        }
      }
      // The one deleteToken in the app (recovering a lost installation
      // credential at login) fetches a new token straight away, so the
      // device never ends up without one.
      final api = File('lib/services/api_service.dart').readAsStringSync();
      final at = api.indexOf('deleteToken(');
      expect(at, isNot(-1));
      expect(api.substring(at, at + 400), contains('getToken('));
      final others = files
          .where((f) => !f.path.endsWith('api_service.dart'))
          .where((f) => f.readAsStringSync().contains('deleteToken('));
      expect(others, isEmpty);
    });
  });
}
