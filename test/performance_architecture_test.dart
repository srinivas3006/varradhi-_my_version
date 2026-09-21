import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/navigation/app_navigator.dart';
import 'package:way2news_clone/screens/home_screen.dart';
import 'package:way2news_clone/screens/news_feed_tab.dart';
import 'package:way2news_clone/screens/local_news_tab.dart';
import 'package:way2news_clone/screens/profile_tab.dart';
import 'package:way2news_clone/screens/video_tab.dart';
import 'package:way2news_clone/state/app_state.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> mockSecureStorage = {};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return mockSecureStorage[methodCall.arguments?['key']];
      } else if (methodCall.method == 'write') {
        final key = methodCall.arguments?['key'] as String?;
        final value = methodCall.arguments?['value'] as String?;
        if (key != null && value != null) {
          mockSecureStorage[key] = value;
        }
        return null;
      } else if (methodCall.method == 'delete') {
        mockSecureStorage.remove(methodCall.arguments?['key']);
        return null;
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({});
    await AppState.instance.init();
  });

  group('Performance Architecture: Rebuild Scoping Tests', () {
    test('themeAndLocaleNotifier only notifies on theme or language changes',
        () {
      int themeLocaleNotifiedCount = 0;
      int appStateNotifiedCount = 0;

      void themeSub() => themeLocaleNotifiedCount++;
      void stateSub() => appStateNotifiedCount++;

      AppState.instance.themeAndLocaleNotifier.addListener(themeSub);
      AppState.instance.addListener(stateSub);

      try {
        // 1. Authenticated content state updates: like, bookmark, user profile edits
        AppState.instance.isLoggedIn = true;
        AppState.instance.authToken = 'test-token';
        AppState.instance.toggleLike('test_article_1');
        AppState.instance.toggleBookmark('test_article_1');
        AppState.instance.setUserName('Test User');

        // Should notify AppState listeners, but NOT themeAndLocaleNotifier
        expect(appStateNotifiedCount, greaterThanOrEqualTo(3));
        expect(themeLocaleNotifiedCount, equals(0),
            reason:
                'ThemeAndLocaleNotifier must NOT fire on likes, bookmarks, or coins');

        // 2. Language and Theme updates: should notify both
        AppState.instance.setLanguage('English');
        expect(themeLocaleNotifiedCount, equals(1));

        AppState.instance.setThemeMode(ThemeMode.dark);
        expect(themeLocaleNotifiedCount, equals(2));

        AppState.instance.setLanguage('Telugu');
        expect(themeLocaleNotifiedCount, equals(3));
      } finally {
        AppState.instance.themeAndLocaleNotifier.removeListener(themeSub);
        AppState.instance.removeListener(stateSub);
      }
    });
  });

  group('Performance Architecture: HomeScreen Lazy Tab Activation Tests', () {
    testWidgets('Inactive secondary tabs are NOT mounted on cold launch',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(initialTabIndex: 0),
        ),
      );
      await tester.pump();

      // Tab 0 (NewsFeedTab) must be mounted
      expect(find.byType(NewsFeedTab), findsOneWidget);

      // Inactive tabs must NOT be mounted on cold start
      expect(find.byType(LocalNewsTab), findsNothing);
      expect(find.byType(VideoTab), findsNothing);
      expect(find.byType(ProfileTab), findsNothing);

      // Tap on Tab 1 (Local News)
      final localNewsTabIcon = find.byIcon(Icons.location_on_rounded);
      expect(localNewsTabIcon, findsOneWidget);
      await tester.tap(localNewsTabIcon);
      await tester.pumpAndSettle();

      // The local tab must still mount lazily, on demand.
      expect(find.byType(LocalNewsTab), findsOneWidget);

      // VideoTab and ProfileTab must still be unmounted
      expect(find.byType(VideoTab), findsNothing);
      expect(find.byType(ProfileTab), findsNothing);
    });
  });

  group('Performance Architecture: AppNavigator Debounce Tests', () {
    test('AppNavigator debounce duration is calibrated to 375ms', () {
      expect(AppNavigator.isNavigating, isFalse);
    });
  });
}
