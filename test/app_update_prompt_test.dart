import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/services/app_update_service.dart';

const _channel = MethodChannel('de.ffuf.in_app_update/methods');

/// Fakes Google Play's answer to "is there a newer version?".
void _play({required int availability, bool fail = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    if (fail) throw PlatformException(code: 'ERROR_API_NOT_AVAILABLE');
    return {
      'updateAvailability': availability,
      'immediateAllowed': true,
      'flexibleAllowed': true,
      'availableVersionCode': 20,
      'installStatus': 0,
      'packageName': 'com.varadhi',
      'updatePriority': 0,
    };
  });
}

Future<void> _check(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      return TextButton(
        onPressed: () => AppUpdateService.instance.checkAndPrompt(context),
        child: const Text('check'),
      );
    }),
  ));
  await tester.tap(find.text('check'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppUpdateService.instance.resetForTest());
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  testWidgets('a newer version on Play shows the update popup',
      (tester) async {
    _play(availability: 2);
    await _check(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byIcon(Icons.system_update_rounded), findsOneWidget);

    // "Later" lets the reader carry on.
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  }, variant: android);

  testWidgets('no popup when the app is up to date', (tester) async {
    _play(availability: 1);
    await _check(tester);
    expect(find.byType(AlertDialog), findsNothing);
  }, variant: android);

  testWidgets('no popup and no crash when Play is unavailable',
      (tester) async {
    _play(availability: 0, fail: true);
    await _check(tester);
    expect(find.byType(AlertDialog), findsNothing);
  }, variant: android);

  testWidgets('asked once per launch', (tester) async {
    _play(availability: 2);
    await _check(tester);
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  }, variant: android);
}
