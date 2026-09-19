import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = AppState.instance;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the UI language maps to a code the backend accepts', () {
    test('Telugu is te, English is en', () {
      state.language = 'Telugu';
      expect(state.uiLanguageCode, 'te');
      state.language = 'English';
      expect(state.uiLanguageCode, 'en');
    });

    test('the code is never null, so the patch always carries a value', () {
      // Regression: the patch used to send contentLanguage, which is null by
      // default, so the field was dropped and nothing was sent.
      for (final l in ['Telugu', 'English', '', 'something else']) {
        state.language = l;
        expect(state.uiLanguageCode, isIn(['en', 'te']));
      }
    });
  });

  group('the patch carries the UI language, not the content language', () {
    final src = File('lib/state/app_state.dart').readAsStringSync();

    test('setLanguage syncs uiLanguageCode', () {
      final fn = src.substring(src.indexOf('void setLanguage('));
      final body = fn.substring(0, fn.indexOf('\n  }'));
      expect(body, contains('preferredLanguage: uiLanguageCode'));
      expect(body, isNot(contains('preferredLanguage: contentLanguage')));
    });

    test('content language is still not synced', () async {
      // It stays a local, per-device choice by design.
      final fn = src.substring(src.indexOf('Future<void> setContentLanguage('));
      final body = fn.substring(0, fn.indexOf('\n  }'));
      expect(body, isNot(contains('_syncProfileToBackend')));
    });
  });

  group('the account language is applied after login', () {
    final src = File('lib/state/app_state.dart').readAsStringSync();
    final fn = src.substring(src.indexOf('Future<void> refreshRolesFromServer'));

    test('preferred_language is read back from the profile', () {
      expect(fn, contains("me['preferred_language']"),
          reason: 'the field was write-only before');
    });

    test('a server value of en selects English', () {
      expect(fn, contains("serverLang.startsWith('en') ? 'English' : 'Telugu'"));
    });

    test('the locale listener is notified so the UI actually re-renders', () {
      expect(fn, contains('themeAndLocaleNotifier.notify()'));
    });
  });

  group('UI and content language stay independent', () {
    test('setting the UI language does not touch the content language',
        () async {
      await state.setContentLanguage('en');
      state.language = 'Telugu';
      expect(state.contentLanguage, 'en',
          reason: 'a Telugu interface can still show English news');
    });

    test('an unset content language survives a UI language change', () async {
      await state.setContentLanguage(null);
      state.language = 'English';
      expect(state.contentLanguage, isNull);
    });
  });

  group('profile fields match the documented contract', () {
    final state2 = File('lib/state/app_state.dart').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    test('font size is clamped to the documented 12-24', () {
      // PATCH /auth/me/ rejects anything outside 12-24 with a 400. The
      // slider used to reach 26, so its top stops silently failed to save.
      expect(state2, contains('size.clamp(12.0, 24.0)'));
      expect(settings, contains('min: 12'));
      expect(settings, contains('max: 24'));
      expect(settings, contains('.clamp(12, 24)'));
    });

    test('the slider no longer offers a range the backend rejects', () {
      expect(settings, isNot(contains('max: 26')));
    });

    test('field-level validation errors are surfaced, not swallowed', () {
      final fn = settings.substring(settings.indexOf('Future<void> _updateProfile'));
      final body = fn.substring(0, 1600);
      expect(body, contains("errors['details']"));
      expect(body, isNot(contains('} catch (_) {\n      // Backend error')));
    });

    test('theme and font size are read back after login', () {
      final fn = state2.substring(state2.indexOf('Future<void> refreshRolesFromServer'));
      expect(fn, contains("me['theme']"));
      expect(fn, contains("me['font_size']"));
    });

    test('theme values map to the documented enum', () {
      final fn = state2.substring(state2.indexOf('Future<void> refreshRolesFromServer'));
      expect(fn, contains("'light' => ThemeMode.light"));
      expect(fn, contains("'dark' => ThemeMode.dark"));
    });
  });
}
