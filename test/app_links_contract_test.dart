import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/navigation/notification_deep_link_resolver.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/models/notification_target.dart';
import 'package:vaaradhi/services/sharing/share_content_builder.dart';
import 'package:vaaradhi/utils/share_service.dart';

/// Backend App Links contract (Oct 2026): vaaradhinews.com and
/// www.vaaradhinews.com open the app; share links never use the API domain.
void main() {
  NotificationTarget open(String url) =>
      NotificationDeepLinkResolver.resolveFromUri(url);

  group('every shared path opens the right screen, on both hosts', () {
    for (final host in ['vaaradhinews.com', 'www.vaaradhinews.com']) {
      test(host, () {
        expect(open('https://$host/article/gold-medal/').type,
            NotificationTargetType.article);
        expect(
            open('https://$host/article/gold-medal/').identifier, 'gold-medal');
        expect(open('https://$host/ugc/1b2c-uuid/').type,
            NotificationTargetType.ugc);
        expect(open('https://$host/poster/p-uuid/').type,
            NotificationTargetType.poster);
        expect(open('https://$host/poll/q-uuid/').type,
            NotificationTargetType.poll);
        expect(open('https://$host/video/v-uuid/').type,
            NotificationTargetType.video);
      });
    }

    test('unknown or invalid links resolve to unknown (no wrong screen)', () {
      expect(open('https://vaaradhinews.com/article/').type,
          NotificationTargetType.unknown);
      expect(open('https://vaaradhinews.com/something/else/').type,
          isNot(NotificationTargetType.article));
      expect(open('https://evil.example.com/article/x/').type,
          NotificationTargetType.unknown);
    });
  });

  group('share links use the public site, never the API domain', () {
    test('share_url on the public site is used as is', () {
      expect(
          ShareContentBuilder.trustedShareUrl(
              'https://vaaradhinews.com/article/x/'),
          'https://vaaradhinews.com/article/x/');
      expect(
          ShareContentBuilder.trustedShareUrl(
              'https://www.vaaradhinews.com/article/x/'),
          isNotNull);
    });

    test('an api.vaaradhinews.com share_url is rejected', () {
      expect(
          ShareContentBuilder.trustedShareUrl(
              'https://api.vaaradhinews.com/article/x/'),
          isNull);
    });

    test('without share_url the fallback is built on vaaradhinews.com', () {
      final a = NewsArticle.fromJson({
        'id': '1',
        'slug': 'gold-medal',
        'title': 't',
        'type': 'article',
        'share_url': 'https://api.vaaradhinews.com/article/gold-medal/',
      });
      expect(ShareService.buildWebArticleUrl(a),
          'https://vaaradhinews.com/article/gold-medal/');
    });
  });

  group('Android setup', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('App Links filter verifies both hosts', () {
      expect(manifest, contains('android:autoVerify="true"'));
      expect(manifest, contains('android:host="vaaradhinews.com"'));
      expect(manifest, contains('android:host="www.vaaradhinews.com"'));
      expect(manifest, isNot(contains('android:host="api.vaaradhinews.com"')));
    });

    test('an already-open app is reused, not restarted', () {
      expect(manifest, contains('android:launchMode="singleTop"'));
      final activity = File(
              'android/app/src/main/kotlin/com/vaaradhi/vaaradhi/MainActivity.kt')
          .readAsStringSync();
      expect(activity, contains('override fun onNewIntent'));
      // Play Console: edge-to-edge on every Android version, without the
      // Android 15-deprecated status/navigation bar colour calls that
      // androidx.activity's enableEdgeToEdge() makes on older versions.
      expect(activity, contains('WindowCompat.setDecorFitsSystemWindows(window, false)'));
      expect(activity, isNot(contains('import androidx.activity.enableEdgeToEdge')));
      final code = activity
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, isNot(contains('setStatusBarColor')));
      expect(code, isNot(contains('setNavigationBarColor')));
      expect(activity, contains('initialLinkConsumed'),
          reason: 'the launch link is handed over once, not twice');
    });

    test('a link to nothing shows "Content unavailable"', () {
      final src =
          File('lib/services/deep_link_service.dart').readAsStringSync();
      expect(src, contains('showContentUnavailable'));
    });
  });
}
