import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/screens/profile_tab.dart';
import 'package:vaaradhi/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppState.instance
      ..isLoggedIn = false
      ..language = 'Telugu';
    await AppState.instance.setContentLanguage(null);
  });

  Future<void> pick(WidgetTester tester, String optionKey) async {
    final tile = find.byKey(const Key('profile_news_language'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(optionKey)));
    await tester.pumpAndSettle();
  }

  testWidgets('Profile → news language: Telugu, English, All', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfileTab())));
    await tester.pumpAndSettle();

    // Starts on "All" (no filter).
    expect(find.text('అన్ని భాషలు'), findsOneWidget);

    await pick(tester, 'news_lang_te');
    expect(AppState.instance.contentLanguage, 'te');
    expect(AppState.instance.feedLang, 'te');
    expect(find.text('తెలుగు'), findsWidgets);

    await pick(tester, 'news_lang_en');
    expect(AppState.instance.contentLanguage, 'en');
    expect(AppState.instance.feedLang, 'en');

    await pick(tester, 'news_lang_all');
    expect(AppState.instance.contentLanguage, isNull);
    expect(AppState.instance.feedLang, 'all');
  });
}
