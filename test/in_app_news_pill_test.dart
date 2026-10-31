import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/in_app_news_pill.dart';

/// A push while the reader is in the app: one quiet line at the top, not a
/// sound, a heads-up popup and a big banner over the story.
void main() {
  late OverlayState overlay;

  Future<void> host(WidgetTester t) async {
    AppState.instance.language = 'Telugu';
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return const Scaffold(body: Text('story text'));
      }),
    ));
    overlay = t.state<OverlayState>(find.byType(Overlay).first);
  }

  tearDown(InAppNewsPill.hide);

  testWidgets('one line, title only, at the top', (t) async {
    await host(t);
    InAppNewsPill.show(overlay,
        title: 'టీ20ల్లో శ్రేయస్ అయ్యర్ అరుదైన రికార్డు అంతర్జాతీయ', onTap: () {});
    await t.pump(); // the slide starts on the next frame
    await t.pump(const Duration(milliseconds: 300));

    final pill = find.byKey(const Key('in_app_news_pill'));
    expect(pill, findsOneWidget);
    final title = t.widget<Text>(find.descendant(
        of: pill, matching: find.textContaining('శ్రేయస్')));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(find.text('చూడండి'), findsOneWidget);
    // Above the story, small.
    expect(t.getRect(pill).height, lessThan(60));
    expect(t.getRect(pill).top, lessThan(100));
    InAppNewsPill.hide();
    await t.pumpAndSettle();
  });

  testWidgets('tap opens the story and the pill goes', (t) async {
    await host(t);
    var opened = 0;
    InAppNewsPill.show(overlay, title: 'News', onTap: () => opened++);
    await t.pump(); // the slide starts on the next frame
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const Key('in_app_news_pill')));
    await t.pump();
    expect(opened, 1);
    expect(InAppNewsPill.isShowing, isFalse);
  });

  testWidgets('it leaves by itself after about 3 seconds', (t) async {
    await host(t);
    InAppNewsPill.show(overlay, title: 'News', onTap: () {});
    await t.pump(); // the slide starts on the next frame
    await t.pump(const Duration(milliseconds: 300));
    expect(InAppNewsPill.isShowing, isTrue);
    await t.pump(InAppNewsPill.visibleFor);
    await t.pumpAndSettle();
    expect(InAppNewsPill.isShowing, isFalse);
    expect(find.byKey(const Key('in_app_news_pill')), findsNothing);
  });

  testWidgets('swipe up dismisses it', (t) async {
    await host(t);
    InAppNewsPill.show(overlay, title: 'News', onTap: () {});
    await t.pump(); // the slide starts on the next frame
    await t.pump(const Duration(milliseconds: 300));
    await t.fling(
        find.byKey(const Key('in_app_news_pill')), const Offset(0, -300), 1000);
    await t.pumpAndSettle();
    expect(InAppNewsPill.isShowing, isFalse);
  });

  testWidgets('a newer push replaces the older one', (t) async {
    await host(t);
    InAppNewsPill.show(overlay, title: 'First', onTap: () {});
    await t.pump(const Duration(milliseconds: 100));
    InAppNewsPill.show(overlay, title: 'Second', onTap: () {});
    await t.pump(); // the slide starts on the next frame
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byKey(const Key('in_app_news_pill')), findsOneWidget);
    InAppNewsPill.hide();
    await t.pumpAndSettle();
  });

  test('foreground pushes: quiet tray entry and the pill, no big banner', () {
    final src =
        File('lib/services/notification_service.dart').readAsStringSync();
    final onMessage = src.substring(
        src.indexOf('FirebaseMessaging.onMessage.listen'),
        src.indexOf('Future<void> requestPermissionAfterArticlesLoaded'));
    expect(onMessage, contains('InAppNewsPill.show('));
    expect(onMessage, isNot(contains('showSnackBar(')));
    final local = src.substring(
        src.indexOf('Future<void> _showLocalNotification'),
        src.indexOf('Future<void> initEarly('));
    expect(local, contains('_quietChannel.id'));
    expect(local, contains('Importance.low'));
    expect(local, isNot(contains('Importance.high')));
    // Closed / background app: the loud channel stays the default.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:value="vaaradhi_news"'));
  });
}
