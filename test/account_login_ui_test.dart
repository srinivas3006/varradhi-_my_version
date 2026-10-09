import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/screens/account_login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(1080, 2392)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AccountLoginScreen()));
    await tester.pump();
  }

  testWidgets('brand header, form card and sign-up are shown', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('login_brand_header')), findsOneWidget);
    expect(find.byKey(const Key('login_form_card')), findsOneWidget);
    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byKey(const Key('login_signup_button')), findsOneWidget);
    expect(find.text('పాస్‌వర్డ్ మర్చిపోయారా?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card overlaps the header', (tester) async {
    await pump(tester);
    final header = tester.getRect(find.byKey(const Key('login_brand_header')));
    final card = tester.getRect(find.byKey(const Key('login_form_card')));
    expect(card.top, lessThan(header.bottom));
  });

  testWidgets('empty submit shows the error box; typing clears it',
      (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('login_error')), findsNothing);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.byKey(const Key('login_error')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('login_email_field')), 'a@b.com');
    await tester.pump();
    expect(find.byKey(const Key('login_error')), findsNothing);
  });

  testWidgets('password visibility toggles', (tester) async {
    await pump(tester);
    TextField field() =>
        tester.widget<TextField>(find.byKey(const Key('login_password_field')));
    expect(field().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('no overflow on a small phone', (tester) async {
    await pump(tester, size: const Size(720, 1280));
    expect(tester.takeException(), isNull);
  });
}
