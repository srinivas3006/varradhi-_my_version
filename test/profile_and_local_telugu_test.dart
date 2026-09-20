import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/localization/app_translations.dart';
import 'package:way2news_clone/localization/location_translations.dart';
import 'package:way2news_clone/screens/profile_tab.dart';
import 'package:way2news_clone/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = 'Telugu';
    AppState.instance.userName = 'Guest User';
    AppState.instance.isLoggedIn = false;
  });

  group('Location Translations & AppState Localization', () {
    test('Translates canonical districts to authentic Telugu', () {
      expect(LocationTranslations.toTelugu('Hyderabad'), 'హైదరాబాద్');
      expect(LocationTranslations.toTelugu('Suryapet'), 'సూర్యాపేట');
      expect(LocationTranslations.toTelugu('Warangal'), 'వరంగల్');
      expect(LocationTranslations.toTelugu('Visakhapatnam'), 'విశాఖపట్నం');
      expect(LocationTranslations.toTelugu('Telangana'), 'తెలంగాణ');
      expect(LocationTranslations.toTelugu('Andhra Pradesh'), 'ఆంధ్రప్రదేశ్');
    });

    test('AppState.displayLocation outputs localized Telugu location string', () {
      AppState.instance.setLocation(
        'Telangana',
        'Hyderabad',
      );
      expect(AppState.instance.displayLocation, 'హైదరాబాద్, తెలంగాణ');

      AppState.instance.setLocation(
        'Telangana',
        'Suryapet',
        subdistrict: 'Jajireddygudem',
        village: 'Kesaram',
      );
      expect(AppState.instance.displayLocation, 'కేసారం, జాజిరెడ్డిగూడెం');
    });

    test('AppTranslations includes Telugu notifications and profile items', () {
      expect(tr('notifications'), 'నోటిఫికేషన్‌లు');
      expect(tr('about'), 'వారధి గురించి');
      expect(tr('saved_articles'), 'సేవ్ చేసిన వార్తలు');
      expect(tr('advertise_with_us'), 'మాతో ప్రకటన ఇవ్వండి');
      expect(tr('privacy_policy'), 'గోప్యతా విధానం');
      expect(tr('terms_of_service'), 'సేవా నిబంధనలు');
    });
  });

  group('ProfileTab UI Localization', () {
    testWidgets('Renders all tiles and labels in authentic Telugu without English leaks',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: ProfileTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify guest user title in Telugu
      expect(find.text('గెస్ట్ యూజర్'), findsOneWidget);
      expect(find.text('స్వాగతం'), findsOneWidget);
      expect(find.text('లాగిన్ అవ్వండి'), findsOneWidget);

      // Verify notifications tile in Telugu
      expect(find.text('నోటిఫికేషన్‌లు'), findsOneWidget);

      // Verify saved articles, preferences, about in Telugu
      expect(find.text('సేవ్ చేసిన వార్తలు'), findsOneWidget);
      expect(find.text('మాతో ప్రకటన ఇవ్వండి'), findsOneWidget);
      expect(find.text('వారధి గురించి'), findsOneWidget);
      expect(find.text('గోప్యతా విధానం'), findsOneWidget);
      expect(find.text('సేవా నిబంధనలు'), findsOneWidget);

      // Verify app version in Telugu
      expect(find.text('వారధి న్యూస్ v1.0.0'), findsOneWidget);

      // Verify no raw English key leaks
      expect(find.text('notifications'), findsNothing);
      expect(find.text('Guest User'), findsNothing);
      expect(find.text('Vaaradhi v1.0.0'), findsNothing);
    });
  });
}
