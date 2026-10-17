import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/localization/location_translations.dart';

void main() {
  setUp(() => LocationTranslations.restoreLearned(const {}));

  group('Telugu place names from the location API', () {
    test('a learned mandal or village name is used', () {
      expect(LocationTranslations.toTelugu('Testpalli'), 'Testpalli',
          reason: 'not in the built-in table');
      LocationTranslations.learn('Testpalli', 'టెస్ట్‌పల్లి');
      expect(LocationTranslations.toTelugu('Testpalli'), 'టెస్ట్‌పల్లి');
      expect(LocationTranslations.toTelugu('testpalli '), 'టెస్ట్‌పల్లి',
          reason: 'case and spacing do not matter');
    });

    test('composite names translate part by part', () {
      LocationTranslations.learn('Yousufguda', 'యూసుఫ్‌గూడ');
      expect(LocationTranslations.toTelugu('Yousufguda, Hyderabad'),
          'యూసుఫ్‌గూడ, హైదరాబాద్');
    });

    test('a non-Telugu or empty name_te is ignored', () {
      LocationTranslations.learn('Samplepet', 'Samplepet');
      LocationTranslations.learn('Samplepet', '');
      LocationTranslations.learn('', 'సాంపుల్‌పేట');
      expect(LocationTranslations.learnedNames, isEmpty);
    });

    test('the learned names survive a restart (restore)', () {
      LocationTranslations.learn('Samplepet', 'సాంపుల్‌పేట');
      final saved = jsonEncode(LocationTranslations.learnedNames);
      LocationTranslations.restoreLearned(const {});
      expect(LocationTranslations.toTelugu('Samplepet'), 'Samplepet');
      LocationTranslations.restoreLearned(
          Map<String, String>.from(jsonDecode(saved) as Map));
      expect(LocationTranslations.toTelugu('Samplepet'), 'సాంపుల్‌పేట');
    });

    test('the store is capped', () {
      for (var i = 0; i < 350; i++) {
        LocationTranslations.learn('place$i', 'ఊరు$i');
      }
      expect(LocationTranslations.learnedNames.length, 300);
      expect(LocationTranslations.toTelugu('place349'), 'ఊరు349');
    });
  });

  group('every way of setting a location keeps the Telugu names', () {
    test('picking a place (search or drill-down) learns name_te', () {
      final src =
          File('lib/providers/location_provider.dart').readAsStringSync();
      expect(src, contains('LocationTranslations.learn(result.nameEn, result.nameTe)'));
      expect(src, contains('LocationTranslations.learn(parent.nameEn, parent.nameTe)'));
    });

    test('a GPS match learns name_te', () {
      final src = File('lib/services/api_service.dart').readAsStringSync();
      expect(src, contains("LocationTranslations.learn(name, item['name_te']"));
    });

    test('they are saved and restored with the app settings', () {
      final src = File('lib/state/app_state.dart').readAsStringSync();
      expect(src, contains('LocationTranslations.learnedNames'));
      expect(src, contains('LocationTranslations.restoreLearned('));
    });
  });
}
