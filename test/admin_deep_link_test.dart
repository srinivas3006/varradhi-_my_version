import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/navigation/notification_deep_link_resolver.dart';
import 'package:way2news_clone/models/notification_target.dart';

void main() {
  group('admin console deep links', () {
    test('/admin/ugc opens the queue', () {
      final t = NotificationDeepLinkResolver.resolveFromUri('/admin/ugc');
      expect(t.type, NotificationTargetType.admin);
      expect(t.screenName, 'queue');
      expect(t.identifier, isNull);
      expect(t.requiresAuth, isTrue);
    });

    test('named sections resolve past the second segment', () {
      for (final section in ['reports', 'logs', 'otp']) {
        final t = NotificationDeepLinkResolver.resolveFromUri('/admin/ugc/$section');
        expect(t.type, NotificationTargetType.admin, reason: section);
        expect(t.screenName, section, reason: section);
        expect(t.identifier, isNull, reason: section);
      }
    });

    test('an unrecognised tail is read as a submission id', () {
      final t = NotificationDeepLinkResolver.resolveFromUri('/admin/ugc/abc123');
      expect(t.type, NotificationTargetType.admin);
      expect(t.identifier, 'abc123');
      expect(t.screenName, isNull);
    });

    test('varadhi:// scheme resolves the same way', () {
      final t = NotificationDeepLinkResolver.resolveFromUri('varadhi://admin/ugc/reports');
      expect(t.type, NotificationTargetType.admin);
      expect(t.screenName, 'reports');
    });

    test('a non-ugc admin path is not silently accepted', () {
      final t = NotificationDeepLinkResolver.resolveFromUri('/admin/billing');
      expect(t.type, NotificationTargetType.unknown);
    });

    test('admin payloads beat the plain ugc branch', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload({
        'content_type': 'admin_ugc',
        'content_id': 'sub-9',
      });
      expect(t.type, NotificationTargetType.admin);
      expect(t.identifier, 'sub-9');
    });

    test('an admin payload with no id lands on a section', () {
      final t = NotificationDeepLinkResolver.resolveFromPayload({
        'content_type': 'admin',
        'admin_section': 'reports',
      });
      expect(t.type, NotificationTargetType.admin);
      expect(t.screenName, 'reports');
      expect(t.identifier, isNull);
    });
  });

  group('multi-segment relative paths (regression)', () {
    test('/ugc/reporter/dashboard keeps its trailing segment', () {
      final t = NotificationDeepLinkResolver.resolveFromUri('/ugc/reporter/dashboard');
      expect(t.type, NotificationTargetType.ugc);
      expect(t.screenName, 'dashboard');
      expect(t.identifier, isNull);
    });

    test('existing two-segment paths are unchanged', () {
      final a = NotificationDeepLinkResolver.resolveFromUri('/article/my-slug');
      expect(a.type, NotificationTargetType.article);
      expect(a.identifier, 'my-slug');

      final c = NotificationDeepLinkResolver.resolveFromUri('/category/sports');
      expect(c.type, NotificationTargetType.category);
      expect(c.identifier, 'sports');
    });
  });
}
