import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/navigation/notification_deep_link_resolver.dart';
import 'package:vaaradhi/models/notification_target.dart';
import 'package:vaaradhi/services/notification_service.dart';

/// Notification tap navigation (APK handover): tapping a notification opens
/// the exact article or UGC item.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  NotificationTarget payload(Map<String, dynamic> d) =>
      NotificationService.targetForTap(d);
  NotificationTarget link(String l) =>
      NotificationDeepLinkResolver.resolveFromUri(l);

  group('payload priority', () {
    test('the backend article payload opens the article by slug', () {
      final t = payload({
        'notification_id': '77accce8-aec3-4338-9391-15b4c55b629a',
        'type': 'content',
        'notification_type': 'article',
        'content_type': 'article',
        'content_id': 'd837b876-0d8c-4064-a190-fc26cdb2c7a1',
        'content_slug': 'article-f187341121af',
        'deep_link': '/article/article-f187341121af',
        'schema_version': '2',
      });
      expect(t.type, NotificationTargetType.article);
      expect(t.identifier, 'article-f187341121af');
      expect(t.notificationId, '77accce8-aec3-4338-9391-15b4c55b629a');
    });

    test('ugc by content_id', () {
      final t = payload({'content_type': 'ugc', 'content_id': 'u-1'});
      expect(t.type, NotificationTargetType.ugc);
      expect(t.identifier, 'u-1');
    });

    test('deep_link when the structured fields address nothing', () {
      final t = payload({'content_type': 'article', 'deep_link': '/ugc/u-9'});
      expect(t.type, NotificationTargetType.ugc);
      expect(t.identifier, 'u-9');
    });

    test('Home when nothing resolves', () {
      final t = payload({'deep_link': '/nowhere'});
      expect(t.type, NotificationTargetType.screen);
      expect(t.screenName, 'home');
    });
  });

  group('every backend link format', () {
    const cases = {
      '/article/s-1': (NotificationTargetType.article, 's-1'),
      '/article/s-1/': (NotificationTargetType.article, 's-1'),
      'article://s-1': (NotificationTargetType.article, 's-1'),
      'https://vaaradhinews.com/article/s-1/':
          (NotificationTargetType.article, 's-1'),
      '/ugc/u-1': (NotificationTargetType.ugc, 'u-1'),
      'https://vaaradhinews.com/ugc/u-1/': (NotificationTargetType.ugc, 'u-1'),
      '/poster/p-1': (NotificationTargetType.poster, 'p-1'),
      '/poll/q-1': (NotificationTargetType.poll, 'q-1'),
      '/video/v-1': (NotificationTargetType.video, 'v-1'),
      '/short/v-2': (NotificationTargetType.video, 'v-2'),
    };
    cases.forEach((raw, expected) {
      test(raw, () {
        final t = link(raw);
        expect(t.type, expected.$1);
        expect(t.identifier, expected.$2);
      });
    });
  });

  group('one notification opens once', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a second tap of the same notification_id is ignored', () async {
      final s = NotificationService.instance;
      expect(await s.claimNotificationTap({'notification_id': 'once-1'}),
          isTrue);
      expect(await s.claimNotificationTap({'notification_id': 'once-1'}),
          isFalse);
      expect(await s.claimNotificationTap({'notification_id': 'once-2'}),
          isTrue);
    });

    test('an id opened in an earlier launch is not reopened', () async {
      SharedPreferences.setMockInitialValues({
        'opened_notification_ids': ['old-1'],
      });
      expect(
          await NotificationService.instance
              .claimNotificationTap({'notification_id': 'old-1'}),
          isFalse);
    });

    test('payloads without an id are always handled', () async {
      final s = NotificationService.instance;
      expect(await s.claimNotificationTap({}), isTrue);
      expect(await s.claimNotificationTap({}), isTrue);
    });
  });

  test('the main activity accepts FLUTTER_NOTIFICATION_CLICK', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest,
        contains('<action android:name="FLUTTER_NOTIFICATION_CLICK" />'));
    expect(manifest, contains('android:launchMode="singleTop"'));
  });

  group('citizen post notifications', () {
    test('submission status notices are told apart from news', () {
      for (final kind in [
        'ugc_approved',
        'UGC_REJECTED',
        'submission_pending',
        'ugc_under_review',
        'submission_status',
      ]) {
        expect(
            NotificationService.isSubmissionStatusNotice(
                {'notification_type': kind, 'content_type': 'ugc'}),
            isTrue,
            reason: kind);
      }
      for (final kind in ['ugc', 'citizen_news', 'content', 'breaking']) {
        expect(
            NotificationService.isSubmissionStatusNotice(
                {'notification_type': kind, 'type': 'content'}),
            isFalse,
            reason: kind);
      }
      expect(NotificationService.isSubmissionStatusNotice(null), isFalse);
    });

    test('a status notice opens the submission status screen', () {
      final src =
          File('lib/services/notification_service.dart').readAsStringSync();
      final ugc = src.substring(src.indexOf('case NotificationTargetType.ugc:'),
          src.indexOf('case NotificationTargetType.admin:'));
      expect(ugc, contains('isSubmissionStatusNotice('));
      expect(ugc, contains('SubmissionStatusScreen('));
    });

    test('an unloadable bare post id shows a message, not an empty page', () {
      final src =
          File('lib/services/notification_service.dart').readAsStringSync();
      final ugc = src.substring(src.indexOf('case NotificationTargetType.ugc:'),
          src.indexOf('case NotificationTargetType.admin:'));
      expect(ugc, contains('article.title.trim().isNotEmpty'));
      expect(ugc, contains('_showLoadFailure(navContext, e'));
    });
  });

  group('reporter submission notifications (backend contract)', () {
    for (final kind in [
      'submission_pending',
      'ugc_under_review',
      'ugc_approved',
      'ugc_rejected',
    ]) {
      test('$kind opens the submission status, signed in', () {
        final t = payload({
          'notification_id': 'n-$kind',
          'content_type': 'ugc',
          'content_id': 'sub-1',
          'notification_type': kind,
          'deep_link': '/ugc/reporter/submissions/sub-1/status/',
        });
        expect(t.type, NotificationTargetType.ugc);
        expect(t.identifier, 'sub-1');
        expect(t.screenName, 'status');
        expect(t.requiresAuth, isTrue);
      });
    }

    test('citizen_news opens the published post', () {
      final t = payload({
        'content_type': 'ugc',
        'content_id': 'sub-2',
        'notification_type': 'citizen_news',
        'deep_link': '/ugc/sub-2',
      });
      expect(t.identifier, 'sub-2');
      expect(t.screenName, isNull);
      expect(t.requiresAuth, isFalse);
    });

    test('the status deep link alone (inbox) resolves to the submission', () {
      final t = link('/ugc/reporter/submissions/sub-3/status/');
      expect(t.type, NotificationTargetType.ugc);
      expect(t.identifier, 'sub-3');
      expect(t.screenName, 'status');
    });
  });
}
