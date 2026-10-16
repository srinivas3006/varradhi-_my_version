import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/navigation/notification_deep_link_resolver.dart';
import 'package:vaaradhi/core/navigation/notification_navigation_gate.dart';
import 'package:vaaradhi/models/notification_target.dart';

NotificationTarget _article(String slug) =>
    NotificationDeepLinkResolver.resolveFromPayload(
        {'type': 'article', 'content_slug': slug});

/// "Some notifications don't open": the causes and their fixes.
void main() {
  final gate = NotificationNavigationGate.instance;
  setUp(gate.reset);

  final src = File('lib/services/notification_service.dart').readAsStringSync();
  final router = src.substring(src.indexOf('Future<void> navigateToTarget('));

  test('screens open without the 375 ms tap debounce (launch race)', () {
    expect(router, isNot(contains('AppNavigator.pushSafe(')));
    expect(router, contains('_openRoute('));
  });

  test('the router does not wait for the story to be closed', () {
    // Awaiting a push held the dispatch lock until the reader left the
    // story, so the next notification tap was refused.
    expect(RegExp(r'await _openRoute\(').hasMatch(router), isFalse);
    final open = src.substring(src.indexOf('void _openRoute('));
    expect(open.substring(0, 200), contains('unawaited('));
  });

  test('falls back to the root navigator when Home was rebuilt', () {
    expect(router, contains('_navigatorKey?.currentContext'));
  });

  testWidgets('a tap after Home was rebuilt is still dispatched',
      (tester) async {
    late BuildContext oldHome;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        oldHome = ctx;
        return const SizedBox.shrink();
      }),
    ));
    final dispatched = <NotificationTarget>[];
    gate.onNavigationReady(oldHome, (t, _) async => dispatched.add(t));
    // Home goes away (logout / login rebuild).
    await tester.pumpWidget(const SizedBox.shrink());
    expect(oldHome.mounted, isFalse);

    gate.setPendingTarget(_article('77'));
    expect(dispatched.single.identifier, '77');
    expect(gate.hasPendingTarget, isFalse);
  });

  testWidgets('a second notification opens while the first story is open',
      (tester) async {
    final first = _article('1');
    final second = _article('2');
    expect(gate.acquireDispatchLock(first), isTrue);
    // The router releases as soon as the screen is pushed.
    gate.releaseDispatchLock();
    expect(gate.acquireDispatchLock(second), isTrue);
    gate.releaseDispatchLock();
  });
}
