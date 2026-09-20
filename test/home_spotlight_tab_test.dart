import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final home = File('lib/screens/home_screen.dart').readAsStringSync();
  final feed = File('lib/screens/news_feed_tab.dart').readAsStringSync();
  final view = File('lib/spotlight/spotlight_screen.dart').readAsStringSync();

  group('the local slot hosts Spotlight', () {
    test('LocalNewsTab is no longer mounted', () {
      expect(home, isNot(contains('LocalNewsTab()')));
    });

    test('Spotlight takes its place', () {
      expect(home, contains('SpotlightScreen(isLocal: true'));
    });

    test('it keeps the local scope of that tab', () {
      // Tab 1 is the district-labelled position.
      expect(home, contains('isLocal: true'));
    });
  });

  group('the top-bar Spotlight shortcut is gone', () {
    test('the sparkle button was removed', () {
      expect(feed, isNot(contains('Icons.auto_awesome_rounded')));
    });

    test('the feed no longer pushes Spotlight', () {
      expect(feed, isNot(contains('SpotlightScreen()')));
    });

    test('search and notifications remain', () {
      expect(feed, contains('Icons.search_rounded'));
      expect(feed, contains('Icons.notifications_none_rounded'));
    });
  });

  group('closing an embedded Spotlight cannot rebuild Home', () {
    test('the tab is mounted in embedded mode', () {
      expect(home, contains('embedded: true'));
    });

    test('close returns early rather than navigating', () {
      // As a tab there is no route to pop, so the fallback would
      // pushReplacement a fresh HomeScreen and lose the active tab.
      final fn = view.substring(view.indexOf('void _closeSpotlight()'));
      final body = fn.substring(0, 700);
      expect(body, contains('if (widget.embedded) return;'));
      expect(body.indexOf('if (widget.embedded) return;'),
          lessThan(body.indexOf('canPop()')));
    });

    test('playback still stops on close', () {
      final fn = view.substring(view.indexOf('void _closeSpotlight()'));
      final body = fn.substring(0, 400);
      expect(body, contains('stopAll()'));
      expect(body, contains('AppTtsService.instance.stop()'));
    });

    test('a pushed Spotlight still pops as before', () {
      final fn = view.substring(view.indexOf('void _closeSpotlight()'));
      expect(fn.substring(0, 900), contains('Navigator.of(context).pop()'));
    });
  });
}
