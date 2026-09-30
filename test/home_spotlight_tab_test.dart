import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final home = File('lib/screens/home_screen.dart').readAsStringSync();
  final view = File('lib/spotlight/spotlight_screen.dart').readAsStringSync();
  final nav = File('lib/widgets/bottom_nav_bar.dart').readAsStringSync();
  final splash = File('lib/screens/splash_screen.dart').readAsStringSync();

  group('Home is the hub; Spotlight is pushed over it', () {
    test('tab 0 is the Home feed, not an embedded Spotlight', () {
      final tabs = home.substring(home.indexOf('final tabs = ['));
      final body = tabs.substring(0, 400);
      expect(body, contains('NewsFeedTab()'));
      expect(home, isNot(contains('SpotlightScreenView(')));
    });

    test('cold launch opens Spotlight on top of Home', () {
      expect(splash, contains('HomeScreen(openSpotlightOnStart: true)'));
      final init = home.substring(home.indexOf('void initState()'));
      final body = init.substring(0, init.indexOf('\n  }'));
      expect(body, contains('widget.openSpotlightOnStart'));
      expect(body, contains('!hadPendingNotification'));
      expect(body, contains('_openSpotlight(isLocal: false)'));
    });

    test('Spotlight is pushed as a route, so back pops to Home', () {
      final fn = home.substring(home.indexOf('void _openSpotlight('));
      final body = fn.substring(0, fn.indexOf('\n  }'));
      expect(body, contains('AppNavigator.pushSafe'));
      expect(body, contains('SpotlightScreen(isLocal: isLocal)'));
    });

    test('the retired Local tab is not wired into Home', () {
      expect(home, isNot(contains('LocalNewsTab(')));
    });

    test('Reels (3) opens full-screen over Home, not as a tab', () {
      expect(home, contains('if (index == 3)'));
      expect(home, contains('ReelsScreen.open(context)'));
      expect(home, isNot(contains('VideoTab(')));
    });

    test('Profile is not a tab; it opens from the Home header', () {
      final tabs = home.substring(home.indexOf('final tabs = ['));
      final body = tabs.substring(0, tabs.indexOf('];'));
      expect(body, isNot(contains('ProfileTab(')));
      final feed = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      expect(feed, contains('ProfileTab.open(context)'));
    });
  });

  group('bottom nav has exactly 5 items', () {
    final keys = RegExp(r"key: '(nav_\w+)'")
        .allMatches(nav)
        .map((m) => m.group(1))
        .toList();

    test('Home, Main, Post, Reels, Local, in that order', () {
      expect(keys, [
        'nav_home',
        'nav_main_news',
        'nav_post',
        'nav_reels',
        'nav_local',
      ]);
    });

    test('the FAB gap and its tap target both use index 2', () {
      expect(nav, contains('if (index == 2)'));
      expect(nav, contains('onTap(2)'));
      expect(nav, contains('currentIndex == 2'));
      expect(nav, contains('tr(_items[2].key)'));
    });

    test('the tabs are labelled in every language', () {
      final tr =
          File('lib/localization/app_translations.dart').readAsStringSync();
      for (final key in keys) {
        expect("'$key':".allMatches(tr).length, 3, reason: key);
      }
    });
  });

  group('tapping the nav bar', () {
    final tap = home.substring(home.indexOf('onTap: (index) {'));
    final body = tap.substring(0, tap.indexOf('\n          },'));

    test('Main (1) and Local (4) open Spotlight rather than a tab', () {
      expect(body, contains('if (index == 1 || index == 4)'));
      expect(body, contains('_openSpotlight(isLocal: index == 4)'));
    });

    test('Post (2) always opens the Post tab, which gates guests itself', () {
      // A guest lands on the Post screen's "log in to post news" page
      // rather than being sent straight to the login route.
      expect(body, contains('if (index == 2)'));
      expect(body, contains('_handlePostTap'));
      final fn = home.substring(home.indexOf('void _handlePostTap()'));
      expect(fn.substring(0, 200), contains('_switchTab(2)'));
      expect(fn.substring(0, 200), isNot(contains('requireAuth')));
    });
  });

  group('pushed Spotlight owns its own back navigation', () {
    test('the bottom-overlay back arrow shows when not embedded', () {
      expect(view, contains('if (!widget.embedded)'));
      expect(view, contains("key: const Key('spotlight_home_btn')"));
    });

    test('_closeSpotlight pops back to Home', () {
      final fn = view.substring(view.indexOf('void _closeSpotlight()'));
      expect(fn.substring(0, 400), contains('Navigator.of(context).pop()'));
    });
  });
}
