import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/app_notification.dart';
import 'package:vaaradhi/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.notifications = [];
    AppState.instance.isLoggedIn = false;
  });

  group('the inbox needs no login', () {
    test('the screen has no login gate', () {
      final src =
          File('lib/screens/notifications_screen.dart').readAsStringSync();
      expect(src, isNot(contains('_buildLoginRequired')));
      expect(src, isNot(contains('AccountLoginScreen')));
      expect(src, isNot(contains('if (!AppState.instance.isLoggedIn) return;')));
    });

    test('a guest keeps pushes they receive', () async {
      await AppState.instance.recordPushNotification(
        data: {'notification_id': 'n-1', 'content_type': 'article'},
        title: 'Breaking',
        body: 'Something happened',
        messageId: 'm-1',
      );
      final inbox = AppState.instance.notifications;
      expect(inbox, hasLength(1));
      expect(inbox.first.title, 'Breaking');
      expect(inbox.first.isRead, isFalse);
      expect(AppState.instance.unreadNotificationsCount, 1);
    });

    test('the same push is not recorded twice', () async {
      for (var i = 0; i < 2; i++) {
        await AppState.instance.recordPushNotification(
          data: {'notification_id': 'n-1'},
          title: 'Breaking',
          body: 'x',
        );
      }
      expect(AppState.instance.notifications, hasLength(1));
    });

    test('empty pushes are ignored', () async {
      await AppState.instance
          .recordPushNotification(data: {}, title: '', body: '');
      expect(AppState.instance.notifications, isEmpty);
    });

    test('pushes survive a restart', () async {
      await AppState.instance.recordPushNotification(
        data: {'notification_id': 'n-9'},
        title: 'Kept',
        body: 'on device',
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_notification_inbox_v1');
      expect(raw, isNotNull);
      expect(raw, contains('Kept'));
    });

    test('read state is kept locally for device-only pushes', () async {
      await AppState.instance.recordPushNotification(
        data: {},
        title: 'Local',
        body: 'only',
        messageId: 'abc',
      );
      final id = AppState.instance.notifications.first.id;
      expect(id, 'push_abc');
      AppState.instance.markNotificationRead(id);
      expect(AppState.instance.notifications.first.isRead, isTrue);
    });
  });

  test('toJson round-trips through fromJson', () {
    final n = AppNotification(
      id: '1',
      notificationId: 'n1',
      title: 'T',
      message: 'M',
      timestamp: DateTime.utc(2026, 9, 25, 10),
      type: NotificationType.announcement,
      contentType: 'article',
      contentSlug: 'slug',
      isRead: true,
    );
    final back = AppNotification.fromJson(n.toJson());
    expect(back.id, '1');
    expect(back.notificationId, 'n1');
    expect(back.title, 'T');
    expect(back.message, 'M');
    expect(back.contentSlug, 'slug');
    expect(back.isRead, isTrue);
    expect(back.timestamp, n.timestamp);
  });
}
