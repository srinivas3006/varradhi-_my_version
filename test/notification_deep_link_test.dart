import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/navigation/notification_deep_link_resolver.dart';
import 'package:vaaradhi/core/navigation/notification_navigation_gate.dart';
import 'package:vaaradhi/models/app_notification.dart';
import 'package:vaaradhi/models/notification_target.dart';
import 'package:vaaradhi/services/deep_link_service.dart';
import 'package:vaaradhi/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationDeepLinkResolver URI Parsing Tests', () {
    test('varadhi://category/education resolves to category target', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'varadhi://category/education',
        notificationId: 'notif-1',
      );

      expect(target.type, equals(NotificationTargetType.category));
      expect(target.identifier, equals('education'));
      expect(target.notificationId, equals('notif-1'));
    });

    test(
        'varadhi://category/education?utm_source=fcm handles query params cleanly',
        () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'varadhi://category/education?utm_source=fcm&campaign=breaking',
      );

      expect(target.type, equals(NotificationTargetType.category));
      expect(target.identifier, equals('education'));
    });

    test('varadhi:///category/sports with triple slash resolves correctly', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'varadhi:///category/sports',
      );

      expect(target.type, equals(NotificationTargetType.category));
      expect(target.identifier, equals('sports'));
    });

    test('article://breaking-news resolves to article target', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'article://breaking-news',
      );

      expect(target.type, equals(NotificationTargetType.article));
      expect(target.identifier, equals('breaking-news'));
    });

    test('Relative /article/breaking-news resolves to article target', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        '/article/breaking-news',
      );

      expect(target.type, equals(NotificationTargetType.article));
      expect(target.identifier, equals('breaking-news'));
    });

    test('varadhi://poster/poster-888 resolves to poster target', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'varadhi://poster/poster-888',
      );

      expect(target.type, equals(NotificationTargetType.poster));
      expect(target.identifier, equals('poster-888'));
    });

    test(
        'varadhi://ugc/reporter/dashboard resolves to UGC dashboard target with auth',
        () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'varadhi://ugc/reporter/dashboard',
      );

      expect(target.type, equals(NotificationTargetType.ugc));
      expect(target.screenName, equals('dashboard'));
      expect(target.requiresAuth, isTrue);
    });

    test('varadhi://ugc/submit resolves to UGC submit target with auth', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'varadhi://ugc/submit',
      );

      expect(target.type, equals(NotificationTargetType.ugc));
      expect(target.screenName, equals('submit'));
      expect(target.requiresAuth, isTrue);
    });

    test('public UGC report link does not require reporter login', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'varadhi://ugc/report-123',
      );

      expect(target.type, equals(NotificationTargetType.ugc));
      expect(target.identifier, equals('report-123'));
      expect(target.requiresAuth, isFalse);
    });

    test('screen://bookmarks resolves to screen target and requires auth', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'screen://bookmarks',
      );

      expect(target.type, equals(NotificationTargetType.screen));
      expect(target.screenName, equals('bookmarks'));
      expect(target.requiresAuth, isTrue);
    });

    test('screen://notifications resolves to screen target', () {
      final target = NotificationDeepLinkResolver.resolveFromUri(
        'screen://notifications',
      );

      expect(target.type, equals(NotificationTargetType.screen));
      expect(target.screenName, equals('notifications'));
      expect(target.requiresAuth, isFalse);
    });

    test('Malformed, empty, or unknown URIs degrade gracefully to unknown', () {
      expect(
        NotificationDeepLinkResolver.resolveFromUri(null).type,
        equals(NotificationTargetType.unknown),
      );
      expect(
        NotificationDeepLinkResolver.resolveFromUri('').type,
        equals(NotificationTargetType.unknown),
      );
      expect(
        NotificationDeepLinkResolver.resolveFromUri('   ').type,
        equals(NotificationTargetType.unknown),
      );
      expect(
        NotificationDeepLinkResolver.resolveFromUri('varadhi://category/').type,
        equals(NotificationTargetType.unknown),
      );
      expect(
        NotificationDeepLinkResolver.resolveFromUri('random_scheme://test')
            .type,
        equals(NotificationTargetType.unknown),
      );
    });
  });

  group('NotificationDeepLinkResolver FCM Payload Tests', () {
    test('FCM payload with deep_link prioritizes deep link', () {
      final payload = {
        'notification_id': 'uuid-123',
        'deep_link': 'varadhi://category/politics',
        'content_type': 'article',
      };

      final target = NotificationDeepLinkResolver.resolveFromPayload(payload);
      expect(target.type, equals(NotificationTargetType.category));
      expect(target.identifier, equals('politics'));
      expect(target.notificationId, equals('uuid-123'));
    });

    test('FCM payload without deep_link resolves via content_type and slug',
        () {
      final payload = {
        'notification_id': 'uuid-456',
        'content_type': 'article',
        'content_slug': 'telangana-budget-2026',
      };

      final target = NotificationDeepLinkResolver.resolveFromPayload(payload);
      expect(target.type, equals(NotificationTargetType.article));
      expect(target.identifier, equals('telangana-budget-2026'));
      expect(target.notificationId, equals('uuid-456'));
    });

    test('FCM payload with poster content resolves cleanly', () {
      final payload = {
        'content_type': 'poster',
        'content_id': 'p-99',
        'notification_id': 'notif-99',
      };

      final target = NotificationDeepLinkResolver.resolveFromPayload(payload);
      expect(target.type, equals(NotificationTargetType.poster));
      expect(target.identifier, equals('p-99'));
      expect(target.notificationId, equals('notif-99'));
    });

    test('FCM payload for a public UGC report does not require auth', () {
      final target = NotificationDeepLinkResolver.resolveFromPayload({
        'content_type': 'ugc',
        'content_id': 'ugc-55',
        'title': 'Citizen report',
      });

      expect(target.type, equals(NotificationTargetType.ugc));
      expect(target.identifier, equals('ugc-55'));
      expect(target.requiresAuth, isFalse);
    });

    test('AppNotification domain model resolves correctly', () {
      final notif = AppNotification(
        id: 'inbox-1',
        title: 'New Poster',
        message: 'View poster update',
        timestamp: DateTime.now(),
        type: NotificationType.announcement,
        contentType: 'poster',
        contentId: 'poster-55',
        deepLink: 'varadhi://poster/poster-55',
      );

      final target =
          NotificationDeepLinkResolver.resolveFromAppNotification(notif);
      expect(target.type, equals(NotificationTargetType.poster));
      expect(target.identifier, equals('poster-55'));
    });
  });

  group('NotificationNavigationGate Tests', () {
    setUp(() {
      NotificationNavigationGate.instance.reset();
    });

    test('Pending target is stored and consumed exactly once', () {
      final gate = NotificationNavigationGate.instance;
      expect(gate.hasPendingTarget, isFalse);

      final target = NotificationTarget.category(categorySlug: 'education');
      gate.setPendingTarget(target);

      expect(gate.hasPendingTarget, isTrue);
      expect(gate.pendingTarget, equals(target));

      final consumed = gate.consumePendingTarget();
      expect(consumed, equals(target));
      expect(gate.hasPendingTarget, isFalse);
    });

    test('cold-start Android URI is queued until Home is ready', () async {
      await DeepLinkService.instance.handleUri(
        'varadhi://article/telangana-budget-2026',
      );

      final target = NotificationNavigationGate.instance.pendingTarget;
      expect(target?.type, NotificationTargetType.article);
      expect(target?.identifier, 'telangana-budget-2026');
    });

    testWidgets('onNavigationReady dispatches pending target on next frame',
        (tester) async {
      final gate = NotificationNavigationGate.instance;
      final target = NotificationTarget.article(slugOrId: 'news-slug');
      gate.setPendingTarget(target);

      NotificationTarget? dispatchedTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              gate.onNavigationReady(context, (t, _) async {
                dispatchedTarget = t;
              });
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(dispatchedTarget, isNotNull);
      expect(dispatchedTarget?.identifier, equals('news-slug'));
      expect(gate.hasPendingTarget, isFalse);
    });

    test('acquireDispatchLock rejects concurrent in-flight dispatch', () {
      final gate = NotificationNavigationGate.instance;
      final target1 = NotificationTarget.article(slugOrId: 'article-1');
      final target2 = NotificationTarget.article(slugOrId: 'article-2');

      expect(gate.acquireDispatchLock(target1), isTrue);
      expect(gate.isDispatching, isTrue);

      // Second target while target1 is in-flight must be rejected
      expect(gate.acquireDispatchLock(target2), isFalse);

      gate.releaseDispatchLock();
      expect(gate.isDispatching, isFalse);

      // Now target2 can be dispatched
      expect(gate.acquireDispatchLock(target2), isTrue);
      gate.releaseDispatchLock();
    });

    test('acquireDispatchLock deduplicates rapid taps on identical target', () {
      final gate = NotificationNavigationGate.instance;
      final target = NotificationTarget.article(slugOrId: 'same-article');

      expect(gate.acquireDispatchLock(target), isTrue);
      gate.releaseDispatchLock();

      // Immediate subsequent tap on exact same target within dedup window is suppressed
      expect(gate.acquireDispatchLock(target), isFalse);
    });

    test('schema v2: content_type + content_slug beat deep_link', () {
      final target = NotificationDeepLinkResolver.resolveFromPayload({
        'notification_id': 'n-1',
        'deep_link': '/article/stale-slug',
        'content_type': 'article',
        'content_id': 'a-uuid',
        'content_slug': 'fresh-slug',
        'notification_type': 'breaking',
        'schema_version': '2',
      });
      expect(target.type, NotificationTargetType.article);
      expect(target.identifier, 'fresh-slug');
      expect(target.notificationId, 'n-1');
    });

    test('schema v2: deep_link is used when content fields do not resolve', () {
      final target = NotificationDeepLinkResolver.resolveFromPayload({
        'deep_link': '/poster/p-7',
        'notification_type': 'breaking',
      });
      expect(target.type, NotificationTargetType.poster);
      expect(target.identifier, 'p-7');
    });

    test('a poster payload with a category field stays a poster', () {
      final target = NotificationDeepLinkResolver.resolveFromPayload({
        'content_type': 'poster',
        'content_id': 'p-1',
        'category': 'sports',
      });
      expect(target.type, NotificationTargetType.poster);
    });

    test('a quote notification opens the Home feed', () {
      final target = NotificationDeepLinkResolver.resolveFromPayload({
        'content_type': 'quote',
        'content_id': 'q-1',
        'deep_link': '/quote/q-1',
      });
      expect(target.type, NotificationTargetType.screen);
      expect(target.screenName, 'home');
    });

    test('an unroutable tap opens the notification inbox', () {
      final target = NotificationService.targetForTap({
        'notification_id': 'n-9',
        'title': 'Hello',
      });
      expect(target.type, NotificationTargetType.screen);
      expect(target.screenName, 'notifications');
    });

    test('Nested JSON string payload is safely unwrapped', () {
      final payload = {
        'data': '{"content_type":"article","slug":"nested-article-slug","notification_id":"notif-nested"}',
      };

      final target = NotificationDeepLinkResolver.resolveFromPayload(payload);
      expect(target.type, equals(NotificationTargetType.article));
      expect(target.identifier, equals('nested-article-slug'));
      expect(target.notificationId, equals('notif-nested'));
    });
  });
}
