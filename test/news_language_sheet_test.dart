import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/spotlight/news_language_sheet.dart';

Future<void> _open(WidgetTester tester, {required bool settings}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => settings
              ? NewsLanguageSheet.show(context)
              : NewsLanguageSheet.showIfNeeded(context),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.contentLanguagePrompted = false;
  });

  testWidgets('first launch: heading, three options, chevrons, disclaimer',
      (tester) async {
    await _open(tester, settings: false);
    expect(find.text('వార్తల భాషను ఎంచుకోండి'), findsOneWidget);
    expect(find.text('Choose News Language'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('తెలుగు'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byType(Divider), findsNWidgets(2),
        reason: 'dividers only between rows');
    expect(find.textContaining('యాప్ భాషను మార్చదు'), findsOneWidget);
  });

  testWidgets('picking a language stores it and closes', (tester) async {
    await _open(tester, settings: false);
    await tester.tap(find.byKey(const ValueKey('news_lang_en')));
    await tester.pumpAndSettle();
    expect(AppState.instance.contentLanguage, 'en');
    expect(find.text('Choose News Language'), findsNothing);
  });

  testWidgets('settings marks the current language', (tester) async {
    await AppState.instance.setContentLanguage('te');
    await _open(tester, settings: true);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
  });

  test('settings opens this sheet, not a separate dialog', () {
    final src = File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(src, contains('NewsLanguageSheet.show(context)'));
    expect(src, isNot(contains('_showContentLanguageDialog')));
  });
}
