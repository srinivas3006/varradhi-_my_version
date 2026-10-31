import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/app_notification.dart';
import 'package:vaaradhi/services/notification_service.dart';
import 'package:vaaradhi/state/app_state.dart';

/// The backend's notification handling contract (schema_version 2): title
/// and body in message.notification, routing and identity in data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.notifications = [];
    AppState.instance.isLoggedIn = false;
  });

  const v2Data = {
    'notification_id': 'n-uuid',
    'deep_link': 'varadhi://article/c-uuid',
    'type': 'all',
    'notification_type': 'article',
    'delivery_category': 'breaking',
    'content_type': 'article',
    'content_id': 'c-uuid',
    'content_slug': 'slug',
    'schema_version': '2',
  };

  group('empty pushes never become "New Notification"', () {
    test('no real title or body: not saved', () async {
      final saved = await AppState.instance.recordPushNotification(
          data: {'notification_id': 'x'}, title: '  ', body: '');
      expect(saved, isFalse);
      expect(AppState.instance.notifications, isEmpty);
    });

    test('foreground handler validates before tray, pill and inbox', () {
      final src =
          File('lib/services/notification_service.dart').readAsStringSync();
      expect(src, isNot(contains("'New Notification'")));
      final onMessage = src.substring(
          src.indexOf('FirebaseMessaging.onMessage.listen'),
          src.indexOf('Future<void> requestPermissionAfterArticlesLoaded'));
      final guard = onMessage.indexOf('if (title.isEmpty && body.isEmpty)');
      expect(guard, greaterThan(0));
      expect(guard, lessThan(onMessage.indexOf('_showLocalNotification(')));
      expect(guard, lessThan(onMessage.indexOf('recordPushNotification(')));
      expect(guard, lessThan(onMessage.indexOf('InAppNewsPill.show(')));
    });

    test('title and body come from message.notification', () {
      const m = RemoteMessage(
        messageId: 'm1',
        notification: RemoteNotification(title: ' Real ', body: 'Body'),
        data: v2Data,
      );
      expect(NotificationService.realTitle(m), 'Real');
      expect(NotificationService.realBody(m), 'Body');
      expect(NotificationService.dedupeKey(m), 'n-uuid');
      const empty = RemoteMessage(messageId: 'm2', data: {});
      expect(NotificationService.realTitle(empty), '');
      expect(NotificationService.dedupeKey(empty), 'm2');
    });
  });

  group('local inbox', () {
    test('a valid push keeps the contract fields, once', () async {
      for (var i = 0; i < 2; i++) {
        await AppState.instance.recordPushNotification(
          data: Map<String, dynamic>.from(v2Data),
          title: 'Real',
          body: 'Body',
          messageId: 'm$i',
        );
      }
      final inbox = AppState.instance.notifications;
      expect(inbox, hasLength(1));
      final n = inbox.single;
      expect(n.id, 'push_n-uuid', reason: 'never a server row id');
      expect(n.isLocal, isTrue);
      expect(n.notificationId, 'n-uuid');
      expect(n.deliveryCategory, 'breaking');
      expect(n.notificationType, 'article');
      expect(n.schemaVersion, '2');
      expect(n.deepLink, 'varadhi://article/c-uuid');
    });

    test('read by notification_id finds the entry', () async {
      await AppState.instance.recordPushNotification(
          data: Map<String, dynamic>.from(v2Data), title: 'Real');
      AppState.instance.markNotificationReadByNotificationId('n-uuid');
      expect(AppState.instance.notifications.single.isRead, isTrue);
    });

    test('migration drops only the fake cards and dedupes', () {
      AppNotification n(Map<String, dynamic> j) => AppNotification.fromJson(j);
      final cleaned = AppState.cleanLocalInbox([
        n({'id': 'push_m1', 'title': 'New Notification', 'body': ''}),
        n({'id': 'push_m2', 'title': 'New Notification', 'body': ''}),
        // Valid without image or known type: kept.
        n({'id': 'push_m3', 'title': 'Plain', 'body': ''}),
        // Older build: device copy keyed by notification_id, read.
        n({'id': 'a', 'notification_id': 'a', 'title': 'T', 'is_read': true}),
        // Server copy of the same notification.
        n({'id': 'row-1', 'notification_id': 'a', 'title': 'T'}),
        n({'id': 'b', 'notification_id': 'b', 'title': 'Only local'}),
      ]);
      expect(cleaned.map((e) => e.id), ['push_m3', 'row-1', 'push_b']);
      expect(cleaned[1].isRead, isTrue, reason: 'read state kept');
    });
  });

  group('server inbox rows', () {
    test('flat fields; id is the row, notification_id the common id', () {
      final n = AppNotification.fromJson({
        'id': 'row-uuid',
        'notification_id': 'n-uuid',
        'title': 'T',
        'body': 'B',
        'notification_type': 'article',
        'event_type': 'article',
        'delivery_category': 'alert',
        'image_url': 'https://cdn.example.com/i.jpg',
        'is_read': false,
        'notification_created_at': '2026-10-31T11:55:00+05:30',
      });
      expect(n.id, 'row-uuid');
      expect(n.notificationId, 'n-uuid');
      expect(n.isLocal, isFalse);
      expect(n.deliveryCategory, 'alert');
      expect(n.imageUrl, 'https://cdn.example.com/i.jpg');
    });

    test('targeting `type` is not the kind of notification', () {
      final n =
          AppNotification.fromJson({'id': '1', 'title': 'T', 'type': 'single'});
      expect(n.notificationType, isNull);
      expect(n.type, NotificationType.announcement);
      final ugc = AppNotification.fromJson({
        'id': '2',
        'title': 'T',
        'type': 'single',
        'notification_type': 'ugc_approved',
      });
      expect(ugc.type, NotificationType.approved);
    });

    test('mark read sends the row id only', () {
      final screen =
          File('lib/screens/notifications_screen.dart').readAsStringSync();
      expect(
          screen, isNot(contains('ApiService.instance.markNotificationRead')));
      expect(screen, contains('Icons.notifications_none_rounded'));
      final svc =
          File('lib/services/notification_service.dart').readAsStringSync();
      expect(
          svc, isNot(contains('markNotificationRead(target.notificationId')));
    });
  });
}
