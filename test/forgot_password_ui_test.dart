import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/screens/forgot_password_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(1080, 2392)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    await tester.pump();
  }

  testWidgets('header, card, email field, send and back-to-login',
      (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('forgot_brand_header')), findsOneWidget);
    expect(find.byKey(const Key('forgot_form_card')), findsOneWidget);
    expect(find.byKey(const Key('forgot_email_field')), findsOneWidget);
    expect(find.byKey(const Key('forgot_submit')), findsOneWidget);
    expect(find.byKey(const Key('forgot_back_to_login')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty send shows the error box; typing clears it',
      (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.byKey(const Key('forgot_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forgot_submit')));
    await tester.pump();
    expect(find.byKey(const Key('forgot_error')), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('forgot_email_field')), 'a@b.com');
    await tester.pump();
    expect(find.byKey(const Key('forgot_error')), findsNothing);
  });

  testWidgets('no overflow on a small phone', (tester) async {
    await pump(tester, size: const Size(720, 1280));
    expect(tester.takeException(), isNull);
  });
}
