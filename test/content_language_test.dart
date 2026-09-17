import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = AppState.instance;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('fresh install', () {
    test('content language is unset, so the feed sends no lang', () async {
      await state.setContentLanguage(null);
      expect(state.contentLanguage, isNull);
    });

    test('is not derived from the UI language', () async {
      await state.setContentLanguage(null);
      state.language = 'Telugu';
      expect(state.contentLanguage, isNull,
          reason: 'a Telugu interface must not force Telugu-only news');
      state.language = 'English';
      expect(state.contentLanguage, isNull);
    });
  });

  group('selection maps to the lang parameter', () {
    test('Telugu sends te, English sends en', () async {
      await state.setContentLanguage('te');
      expect(state.contentLanguage, 'te');
      await state.setContentLanguage('en');
      expect(state.contentLanguage, 'en');
    });

    test('"All" clears it rather than becoming te', () async {
      await state.setContentLanguage('te');
      await state.setContentLanguage('all');
      expect(state.contentLanguage, isNull);
    });

    test('empty string is treated as All, never as te', () async {
      await state.setContentLanguage('');
      expect(state.contentLanguage, isNull);
    });
  });

  group('independence from UI language', () {
    test('Telugu UI + English news is representable', () async {
      state.language = 'Telugu';
      await state.setContentLanguage('en');
      expect(state.language, 'Telugu');
      expect(state.contentLanguage, 'en');
    });

    test('English UI + Telugu news is representable', () async {
      state.language = 'English';
      await state.setContentLanguage('te');
      expect(state.language, 'English');
      expect(state.contentLanguage, 'te');
    });
  });

  group('the first-launch prompt asks exactly once', () {
    test('an unprompted reader is asked', () async {
      state.contentLanguagePrompted = false;
      expect(state.contentLanguagePrompted, isFalse);
      await state.markContentLanguagePrompted();
      expect(state.contentLanguagePrompted, isTrue);
    });

    test('choosing All does not re-trigger the prompt', () async {
      state.contentLanguagePrompted = false;
      await state.markContentLanguagePrompted();
      await state.setContentLanguage(null);
      // null content language is a valid answer, not an unanswered one.
      expect(state.contentLanguage, isNull);
      expect(state.contentLanguagePrompted, isTrue);
    });
  });
}
