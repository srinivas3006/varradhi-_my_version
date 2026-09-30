import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/screens/create_post_screen.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/bottom_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the floating Post button always takes the tap', () {
    Future<List<int>> tapAt(WidgetTester tester, Offset Function(Rect) at) async {
      final taps = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar:
              BottomNavBar(currentIndex: 0, onTap: taps.add),
        ),
      ));
      final rect = tester.getRect(find.byKey(const Key('nav_post_button')));
      await tester.tapAt(at(rect));
      await tester.pump();
      return taps;
    }

    testWidgets('on its centre', (tester) async {
      expect(await tapAt(tester, (r) => r.center), [2]);
    });

    testWidgets('on the part that rises above the bar', (tester) async {
      // This strip used to sit outside the bar's bounds, so taps there
      // were silently dropped.
      expect(await tapAt(tester, (r) => r.topCenter + const Offset(0, 4)),
          [2]);
    });
  });

  testWidgets('the guest page is laid out like the login screen',
      (tester) async {
    AppState.instance.isLoggedIn = false;
    await tester.pumpWidget(const MaterialApp(home: CreatePostScreen()));
    await tester.pump();

    // Top bar, left-aligned content, full-width button, sign-up link.
    expect(find.widgetWithText(AppBar, 'పోస్ట్'), findsOneWidget);
    expect(find.text('వార్త పోస్ట్ చేయడానికి లాగిన్ అవ్వండి'), findsOneWidget);
    final title =
        tester.getRect(find.text('వార్త పోస్ట్ చేయడానికి లాగిన్ అవ్వండి'));
    expect(title.left, lessThan(40), reason: 'left-aligned, not centred');

    final button = tester.getSize(find.byKey(const Key('post_login_button')));
    expect(button.height, 52);
    expect(find.byKey(const Key('post_signup_link')), findsOneWidget);
    expect(find.textContaining('ఖాతాను సృష్టించండి', findRichText: true),
        findsOneWidget);
    // No big round icon badge any more.
    expect(
        find.descendant(
            of: find.byKey(const Key('post_login_required')),
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle)),
        findsNothing);
  });

  group('a guest reaches the Post screen', () {
    String code(String path) => File(path)
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('the nav Post button is not gated on login', () {
      final home = code('lib/screens/home_screen.dart');
      expect(home, contains('void _handlePostTap() => _switchTab(2);'));
      expect(home, isNot(contains('requireAuth')));
    });

    test('the Spotlight + button is not gated on login', () {
      final spotlight = code('lib/spotlight/spotlight_screen.dart');
      expect(spotlight, isNot(contains('requireAuth')));
    });

    test('the Post screen shows its login page instead of bouncing', () {
      final post = code('lib/screens/create_post_screen.dart');
      expect(post, contains('return _buildLoginRequired();'));
      // The only login call left is the page's own Log in button.
      expect('requireAuth('.allMatches(post).length, 1);
    });
  });
}
