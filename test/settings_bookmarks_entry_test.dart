import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

    test('it is hidden from guests, who have none', () {
      final entry = settings.indexOf('BookmarksScreen()');
      final gate = settings.lastIndexOf('if (state.isLoggedIn) ...[', entry);
      expect(gate, greaterThan(-1),
          reason: 'bookmarks require an account');
    });
  });

  group('the bookmark list parser handles what the API may send', () {
    test('a nested article object is unwrapped', () {
      expect(api, contains("final nested = map['article']"));
      expect(api, contains("map['article_id']"));
    });

    test('a flat article object is accepted too', () {
      expect(api, contains('articleData = Map<String, dynamic>.from(map)'));
    });

    test('items are marked bookmarked regardless of payload', () {
      // The list endpoint returns saved items by definition, so the flag is
      // forced rather than trusted.
      expect(api, contains("articleData['is_bookmarked'] = true"));
      expect(api, contains("articleData['is_bookmarked_by_user'] = true"));
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
