import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/screens/cms_page_screen.dart';
import 'package:vaaradhi/screens/profile_tab.dart';
import 'package:vaaradhi/services/cms_service.dart';
import 'package:vaaradhi/state/app_state.dart';

/// Play News policy (version code 12 rejected for "in-app experience"):
/// Contact Us must be easy to find — on Profile's first screen, no scrolling.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    // An ordinary phone screen (360 x 800).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: ProfileTab())));
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  for (final loggedIn in [false, true]) {
    testWidgets(
        '${loggedIn ? 'logged in' : 'guest'}: Contact Us is on screen at once',
        (tester) async {
      AppState.instance.isLoggedIn = loggedIn;
      addTearDown(() => AppState.instance.isLoggedIn = false);
      await pump(tester);

      final button = find.byKey(const Key('profile_contact_us_top'));
      expect(button, findsOneWidget);
      final rect = tester.getRect(button);
      expect(rect.bottom, lessThan(800), reason: 'visible without scrolling');
      expect(find.textContaining('Contact Us'), findsWidgets);
      await done(tester);
    });
  }

  testWidgets('it opens the CMS Contact Us page', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('profile_contact_us_top')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final page = tester.widget<CMSPageScreen>(find.byType(CMSPageScreen));
    expect(page.slug, CmsSlugs.contact);
    await done(tester);
  });
}
