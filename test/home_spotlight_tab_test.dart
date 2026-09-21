import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final home = File('lib/screens/home_screen.dart').readAsStringSync();
  final feed = File('lib/screens/news_feed_tab.dart').readAsStringSync();
  final view = File('lib/spotlight/spotlight_screen.dart').readAsStringSync();
  final wrapper =
      File('lib/screens/spotlight_screen.dart').readAsStringSync();

  group('Spotlight is a screen, not a Home tab', () {
    test('Home does not mount Spotlight in its tab list', () {
      final tabs = home.substring(home.indexOf('final tabs = ['));
      expect(tabs.substring(0, 800), isNot(contains('SpotlightScreen(')),
          reason: 'it must be pushed, not embedded');
    });

    test('the local slot keeps its own tab', () {
      expect(home, contains('LocalNewsTab()'));
    });
  });

  group('Home carries the button that opens it', () {
    test('the Spotlight button is in the top bar', () {
      expect(feed, contains('Icons.auto_awesome_rounded'));
    });

    test('it pushes a route rather than switching a tab', () {
      final btn = feed.substring(feed.indexOf('Icons.auto_awesome_rounded'));
      final body = btn.substring(0, 700);
      expect(body, contains('AppNavigator.pushSafe'));
      expect(body, contains('MaterialPageRoute'));
      expect(body, contains('SpotlightScreen()'));
    });

    test('the route is named, as the app names its others', () {
      final btn = feed.substring(feed.indexOf('Icons.auto_awesome_rounded'));
      expect(btn.substring(0, 700), contains("RouteSettings(name: '/spotlight')"));
    });

    test('it is labelled in both languages', () {
      expect(feed, contains('స్పాట్‌లైట్'));
      expect(feed, contains("'Spotlight'"));
    });

    test('search and notifications are still there', () {
      expect(feed, contains('Icons.search_rounded'));
      expect(feed, contains('Icons.notifications_none_rounded'));
    });
  });

  group('closing returns to Home', () {
    test('a pushed Spotlight pops', () {
      final fn = view.substring(view.indexOf('void _closeSpotlight()'));
      final body = fn.substring(0, 700);
      expect(body, contains('canPop()'));
      expect(body, contains('Navigator.of(context).pop()'));
    });

    test('a cold-start Spotlight still lands on Home', () {
      // Opened from a notification there is nothing to pop, so it replaces
      // itself with Home rather than trapping the reader.
      final fn = view.substring(view.indexOf('void _closeSpotlight()'));
      expect(fn.substring(0, 900), contains('HomeScreen(openSpotlightOnStart: false)'));
    });

    test('playback stops on the way out', () {
      final fn = view.substring(view.indexOf('void _closeSpotlight()'));
      final body = fn.substring(0, 400);
      expect(body, contains('stopAll()'));
      expect(body, contains('AppTtsService.instance.stop()'));
    });
  });

  group('the embed-only escape hatch is gone with the embedding', () {
    test('no unused embedded flag remains', () {
      expect(view, isNot(contains('widget.embedded')));
      expect(wrapper, isNot(contains('embedded')));
    });
  });

  group('Spotlight has its own bottom-nav tab', () {
    final nav = File('lib/widgets/bottom_nav_bar.dart').readAsStringSync();
    // Order the items are declared in, which is the order they render.
    final keys = RegExp(r"key: '(nav_\w+)'")
        .allMatches(nav)
        .map((m) => m.group(1))
        .toList();

    test('the item sits directly beside Home', () {
      expect(keys.take(2), ['nav_home', 'nav_spotlight']);
    });

    test('Post keeps the centre slot the floating button needs', () {
      // The Row renders a gap at index 2 and the button label reads
      // _items[2]; anything else there swallows a real tab.
      expect(keys[2], 'nav_post');
    });

    test('the other tabs follow unchanged', () {
      expect(keys.skip(3), ['nav_local', 'nav_video', 'nav_profile']);
    });

    test('the tab is labelled in both languages', () {
      final tr =
          File('lib/localization/app_translations.dart').readAsStringSync();
      expect(tr, contains("'nav_spotlight': 'Spotlight'"));
      expect(tr, contains("'nav_spotlight': 'స్పాట్‌లైట్'"));
    });
  });

  group('tapping the tab pushes rather than switching the stack', () {
    test('index 1 pushes the Spotlight route', () {
      final tap = home.substring(home.indexOf('onTap: (index) {'));
      final body = tap.substring(0, 900);
      expect(body, contains('if (index == 1)'));
      expect(body, contains('AppNavigator.pushSafe'));
      expect(body, contains('SpotlightScreen()'));
    });

    test('it leaves _navIndex alone, so Back lands where you were', () {
      final tap = home.substring(home.indexOf('onTap: (index) {'));
      final branch = tap.substring(
          tap.indexOf('if (index == 1)'), tap.indexOf('if (index == 2)'));
      expect(branch, isNot(contains('_navIndex = 1')),
          reason: 'selecting the tab would strand the reader on a blank slot');
    });

    test('the stack slot at index 1 is an empty placeholder', () {
      final tabs = home.substring(home.indexOf('final tabs = ['));
      expect(tabs.substring(0, 700), isNot(contains('SpotlightScreen(')));
    });

    test('Post still requires an account', () {
      final tap = home.substring(home.indexOf('onTap: (index) {'));
      final body = tap.substring(0, tap.indexOf('\n          },'));
      expect(body, contains('if (index == 2)'));
      expect(body, contains('requireAuth'));
    });
  });
}
