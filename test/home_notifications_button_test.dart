import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:way2news_clone/models/app_notification.dart';
import 'package:way2news_clone/state/app_state.dart';

void main() {
  final bar = File('lib/screens/news_feed_tab.dart').readAsStringSync();

  group('the notifications button sits after search', () {
    test('both buttons exist in the top bar', () {
      expect(bar, contains('Icons.search_rounded'));
      expect(bar, contains('Icons.notifications_none_rounded'));
    });

    test('notifications comes after search, not before', () {
      expect(bar.indexOf('Icons.notifications_none_rounded'),
          greaterThan(bar.indexOf('Icons.search_rounded')));
    });

    test('it opens the existing notifications screen', () {
      expect(bar, contains('NotificationsScreen()'));
    });

    test('it is labelled in both languages', () {
      expect(bar, contains('నోటిఫికేషన్లు'));
      expect(bar, contains("'Notifications'"));
    });
  });

  group('the badge reflects unread state', () {
    setUp(() => AppState.instance.notifications = []);

    AppNotification make(String id, {required bool isRead}) => AppNotification(
          id: id,
          title: 't',
          message: 'm',
          timestamp: DateTime(2026),
          type: NotificationType.announcement,
          isRead: isRead,
        );
    AppNotification unread(String id) => make(id, isRead: false);

    test('no unread means no count', () {
      expect(AppState.instance.unreadNotificationsCount, 0);
    });

    test('unread items are counted', () {
      AppState.instance.notifications = [unread('1'), unread('2')];
      expect(AppState.instance.unreadNotificationsCount, 2);
    });

    test('read items are not counted', () {
      AppState.instance.notifications = [
        unread('1'),
        make('2', isRead: true),
      ];
      expect(AppState.instance.unreadNotificationsCount, 1);
    });

    test('the badge is hidden at zero', () {
      expect(bar, contains('if (unread > 0)'));
    });

    test('a large count is capped so the bar does not shift', () {
      expect(bar, contains("unread > 99 ? '99+'"));
    });

    test('it rebuilds from AppState rather than polling', () {
      expect(bar, contains('animation: AppState.instance'));
      expect(bar, contains('AppState.instance.unreadNotificationsCount'));
    });
  });
}
