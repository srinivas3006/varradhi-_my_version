import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/app_notification.dart';

void main() {
  test('image is read from any key the inbox / push uses', () {
    for (final k in [
      'image_url',
      'image',
      'thumbnail_url',
      'cover_image_url'
    ]) {
      final n = AppNotification.fromJson(
          {'id': '1', 'title': 't', k: 'https://cdn.x/a.jpg'});
      expect(n.imageUrl, 'https://cdn.x/a.jpg', reason: k);
    }
    expect(
        AppNotification.fromJson({
          'id': '2',
          'data': {'image': 'https://cdn.x/b.jpg'}
        }).imageUrl,
        'https://cdn.x/b.jpg');
    expect(AppNotification.fromJson({'id': '3', 'image': ''}).imageUrl, isNull);
  });

  test('image survives the on-device inbox round trip', () {
    final n = AppNotification.fromJson(
        {'id': '1', 'title': 't', 'thumbnail_url': 'https://cdn.x/a.jpg'});
    expect(
        AppNotification.fromJson(n.toJson()).imageUrl, 'https://cdn.x/a.jpg');
  });

  test('push image (FCM notification.image) is passed to the inbox', () {
    final src =
        File('lib/services/notification_service.dart').readAsStringSync();
    expect(src, contains('notification?.android?.imageUrl'));
    expect(
        RegExp(r'imageUrl: _pushImage\(message\)').allMatches(src).length, 2);
  });

  test('no image: the card falls back to the story photo', () {
    final src =
        File('lib/screens/notifications_screen.dart').readAsStringSync();
    expect(src, contains('class _StoryImage'));
    expect(src, contains('getArticleDetail'));
  });
}
