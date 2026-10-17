import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/saved_item.dart';

void main() {
  final settings =
      File('lib/screens/settings_screen.dart').readAsStringSync();
  final api = File('lib/services/api_service.dart').readAsStringSync();

  group('saved articles are reachable from Settings', () {
    // It was only reachable from the Profile tab and a notification deep
    // link — Settings had no way in at all.
    test('the entry exists', () {
      expect(settings, contains('BookmarksScreen()'));
    });

    test('it is labelled in both languages', () {
      expect(settings, contains('సేవ్ చేసిన వార్తలు'));
      expect(settings, contains("'Saved Articles'"));
    });

    test('it is shown to guests, whose bookmarks live on the phone', () {
      final entry = settings.indexOf('BookmarksScreen()');
      final block = settings.substring(entry - 700, entry);
      expect(block, isNot(contains('if (state.isLoggedIn) ...[')));
    });
  });

  group('the bookmark list parser handles what the API may send', () {
    test('a nested article object is unwrapped', () {
      final item = SavedItem.fromJson({
        'id': 'bm1',
        'article_id': 'a1',
        'article': {'title': 'Nested'},
      });
      expect(item.story.id, 'a1');
      expect(item.story.title, 'Nested');
    });

    test('a flat article object is accepted too', () {
      final item = SavedItem.fromJson({'id': 'bm1', 'title': 'Flat'});
      expect(item.story.title, 'Flat');
    });

    test('items are marked bookmarked regardless of payload', () {
      // The list endpoint returns saved items by definition, so the flag is
      // forced rather than trusted.
      final item = SavedItem.fromJson({
        'id': 'bm1',
        'article': {'id': 'a1', 'is_bookmarked': false},
      });
      expect(item.story.isBookmarked, isTrue);
    });

    test('several envelope shapes are unwrapped', () {
      for (final key in ['results', 'items', 'articles']) {
        expect(api, contains("map['$key'] is List"), reason: key);
      }
    });
  });

  group('a failed load is reported, not left blank', () {
    final screen = File('lib/screens/bookmarks_screen.dart').readAsStringSync();

    test('the screen keeps an error field', () {
      expect(screen, contains('_error = tr('));
    });

    test('loading stops even when the request fails', () {
      final catchBlock = screen.substring(screen.indexOf('} catch (e) {'));
      expect(catchBlock.substring(0, 400), contains('_isLoading = false'));
    });
  });
}
