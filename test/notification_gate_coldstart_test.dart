import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/navigation/notification_deep_link_resolver.dart';
import 'package:way2news_clone/core/navigation/notification_navigation_gate.dart';
import 'package:way2news_clone/models/notification_target.dart';

NotificationTarget _article(String id) =>
    NotificationDeepLinkResolver.resolveFromPayload(
        {'type': 'article', 'content_id': id});

void main() {
  final gate = NotificationNavigationGate.instance;

  setUp(gate.reset);

  Future<BuildContext> mountContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        captured = ctx;
        return const SizedBox.shrink();
      }),
    ));
    return captured;
  }

  group('a target arriving before the tree is ready is held', () {
    testWidgets('and dispatched once navigation reports ready',
        (tester) async {
      final dispatched = <NotificationTarget>[];
      gate.setPendingTarget(_article('42'));
      expect(gate.hasPendingTarget, isTrue);

      final ctx = await mountContext(tester);
      gate.onNavigationReady(ctx, (t, _) async => dispatched.add(t));
      await tester.pumpAndSettle();

      expect(dispatched.single.identifier, '42');
      expect(gate.hasPendingTarget, isFalse);
    });
  });

  group('a target arriving AFTER the tree is ready still navigates', () {
    // The cold-start bug: getInitialMessage() resolves inside the background
    // init that runs after runApp, so the target routinely lands after
    // HomeScreen has already called onNavigationReady and found nothing.
    testWidgets('it dispatches immediately instead of waiting forever',
        (tester) async {
      final dispatched = <NotificationTarget>[];
      final ctx = await mountContext(tester);

      gate.onNavigationReady(ctx, (t, _) async => dispatched.add(t));
      await tester.pumpAndSettle();
      expect(dispatched, isEmpty);

      // getInitialMessage() finally resolves.
      gate.setPendingTarget(_article('99'));
      // The dispatch runs in a post-frame callback; a real app is producing
      // frames continuously, a test has to ask for one.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(dispatched.single.identifier, '99',
          reason: 'the reader tapped a notification and must not sit on Home');
      expect(gate.hasPendingTarget, isFalse);
    });
  });

  group('one tap never navigates twice', () {
    testWidgets('a repeated identical target is suppressed', (tester) async {
      final ctx = await mountContext(tester);
      gate.onNavigationReady(ctx, (t, _) async {});
      await tester.pumpAndSettle();

      final target = _article('7');
      expect(gate.acquireDispatchLock(target), isTrue);
      gate.releaseDispatchLock();
      expect(gate.acquireDispatchLock(target), isFalse,
          reason: 'getInitialMessage and onMessageOpenedApp can both fire');
    });
  });

  group('unknown targets are not held', () {
    test('an unaddressable payload leaves nothing pending', () {
      gate.setPendingTarget(
          NotificationDeepLinkResolver.resolveFromPayload({'title': 'hi'}));
      expect(gate.hasPendingTarget, isFalse,
          reason: 'Home is the right destination only when nothing is addressable');
    });
  });

  group('public destinations do not demand login', () {
    test('article, video and category targets are guest-reachable', () {
      for (final payload in [
        {'type': 'article', 'content_id': '1'},
        {'type': 'video', 'content_id': '2'},
        {'type': 'category', 'category_slug': 'sports'},
      ]) {
        final t = NotificationDeepLinkResolver.resolveFromPayload(payload);
        expect(t.requiresAuth, isFalse, reason: 'payload $payload');
        expect(t.type, isNot(NotificationTargetType.unknown));
      }
    });

    test('profile and bookmarks still require auth', () {
      for (final screen in ['profile', 'bookmarks']) {
        final t = NotificationDeepLinkResolver.resolveFromUri('screen://$screen');
        expect(t.requiresAuth, isTrue, reason: screen);
      }
    });
  });

  group('App Links from the public site route to content, not Home', () {
    // The resolver only knew varadhi:// — a tapped https share link resolved
    // to unknown and the reader landed on Home.
    NotificationTarget resolve(String url) =>
        NotificationDeepLinkResolver.resolveFromUri(url);

    test('an article link resolves by slug', () {
      final t = resolve('https://vaaradhinews.com/article/telangana-story/');
      expect(t.type, NotificationTargetType.article);
      expect(t.identifier, 'telangana-story');
      expect(t.requiresAuth, isFalse, reason: 'guests must reach it');
    });

    test('the trailing slash does not swallow the identifier', () {
      expect(resolve('https://vaaradhinews.com/poster/abc-123/').identifier,
          'abc-123');
    });

    test('www is accepted too', () {
      expect(resolve('https://www.vaaradhinews.com/article/s/').type,
          NotificationTargetType.article);
    });

    test('ugc resolves to its own destination', () {
      final t = resolve('https://vaaradhinews.com/ugc/sub-1/');
      expect(t.type, NotificationTargetType.ugc);
      expect(t.identifier, 'sub-1');
    });

    test('a video link opens the story carrying it', () {
      expect(resolve('https://vaaradhinews.com/video/v1/').type,
          NotificationTargetType.article);
    });

    test('an unrelated host is not hijacked', () {
      expect(resolve('https://example.com/article/x/').type,
          NotificationTargetType.unknown);
    });

    test('the bare site root has nothing to route to', () {
      expect(resolve('https://vaaradhinews.com/').type,
          NotificationTargetType.unknown);
    });
  });
}
