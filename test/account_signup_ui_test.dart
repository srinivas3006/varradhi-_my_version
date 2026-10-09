import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/screens/account_signup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(1080, 2392)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AccountSignupScreen()));
    await tester.pump();
  }

  Icon ruleIcon(WidgetTester tester, String key) =>
      tester.widget<Icon>(find.descendant(
          of: find.byKey(Key('signup_rule_$key')),
          matching: find.byType(Icon)));

  testWidgets('header, card, four fields and login link', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('signup_brand_header')), findsOneWidget);
    expect(find.byKey(const Key('signup_form_card')), findsOneWidget);
    for (final k in ['name', 'email', 'password', 'confirm']) {
      expect(find.byKey(Key('signup_${k}_field')), findsOneWidget);
    }
    expect(find.byKey(const Key('signup_submit')), findsOneWidget);
    expect(find.byKey(const Key('signup_login_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password checklist follows what is typed', (tester) async {
    await pump(tester);
    expect(ruleIcon(tester, 'length').icon, Icons.circle_outlined);

    await tester.enterText(
        find.byKey(const Key('signup_password_field')), '12345678');
    await tester.pumpAndSettle();
    expect(ruleIcon(tester, 'length').icon, Icons.check_circle_rounded);
    expect(ruleIcon(tester, 'not_numeric').icon, Icons.circle_outlined);

    await tester.enterText(
        find.byKey(const Key('signup_password_field')), 'abc12345');
    await tester.enterText(
        find.byKey(const Key('signup_confirm_field')), 'abc12345');
    await tester.pumpAndSettle();
    expect(ruleIcon(tester, 'not_numeric').icon, Icons.check_circle_rounded);
    expect(ruleIcon(tester, 'match').icon, Icons.check_circle_rounded);
  });

  testWidgets('empty submit shows the error box; typing clears it',
      (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.byKey(const Key('signup_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signup_submit')));
    await tester.pump();
    expect(find.byKey(const Key('signup_error')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('signup_name_field')), 'Ravi');
    await tester.pump();
    expect(find.byKey(const Key('signup_error')), findsNothing);
  });

  testWidgets('no overflow on a small phone', (tester) async {
    await pump(tester, size: const Size(720, 1280));
    expect(tester.takeException(), isNull);
  });

  group('terms & privacy agreement', () {
    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.enterText(
          find.byKey(const Key('signup_name_field')), 'Ravi');
      await tester.enterText(
          find.byKey(const Key('signup_email_field')), 'ravi@example.com');
      await tester.enterText(
          find.byKey(const Key('signup_password_field')), 'abc12345');
      await tester.enterText(
          find.byKey(const Key('signup_confirm_field')), 'abc12345');
      await tester.pumpAndSettle();
    }

    Future<void> tapSubmit(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('signup_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('signup_submit')));
      await tester.pump();
    }

    testWidgets('the box starts unticked', (tester) async {
      await pump(tester);
      final box = tester
          .widget<Checkbox>(find.byKey(const Key('signup_terms_checkbox')));
      expect(box.value, isFalse);
    });

    testWidgets('a valid form is still blocked until the box is ticked',
        (tester) async {
      await pump(tester);
      await fillValidForm(tester);
      await tapSubmit(tester);

      expect(find.byKey(const Key('signup_error')), findsOneWidget);
      expect(
          find.text(
              'కొనసాగడానికి నిబంధనలు మరియు గోప్యతా విధానాన్ని అంగీకరించండి.'),
          findsOneWidget);
    });

    testWidgets('ticking the box clears the warning', (tester) async {
      await pump(tester);
      await fillValidForm(tester);
      await tapSubmit(tester);
      expect(find.byKey(const Key('signup_error')), findsOneWidget);

      await tester
          .ensureVisible(find.byKey(const Key('signup_terms_checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('signup_terms_checkbox')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Checkbox>(find.byKey(const Key('signup_terms_checkbox')))
              .value,
          isTrue);
      expect(find.byKey(const Key('signup_error')), findsNothing);
    });

    testWidgets('the sentence links to both documents', (tester) async {
      await pump(tester);
      expect(find.textContaining('నిబంధనలు మరియు షరతులు', findRichText: true),
          findsWidgets);
      expect(find.textContaining('గోప్యతా విధానం', findRichText: true),
          findsWidgets);
    });
  });
}
