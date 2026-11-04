import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/utils/share_service.dart';

/// Play vitals: SIGSEGV in the graphics driver on a Realme C21, turning a
/// widget into an image with no screen to draw on. No share card is drawn
/// while the app is in the background.
void main() {
  final article = NewsArticle.fromJson({'id': 'a1', 'title': 'Story'});

  tearDown(() {
    ShareService.clearMadeCards();
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('foreground: a card can be drawn', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(ShareService.canDraw, isTrue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(ShareService.canDraw, isTrue,
        reason:
            'a dialog or the notification shade: the screen is still there');
  });

  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    testWidgets('$state: nothing is drawn, and nothing remembered', (t) async {
      t.binding.handleAppLifecycleStateChanged(state);
      expect(ShareService.canDraw, isFalse);
      await ShareService.prepareShare(article);
      expect(ShareService.isShareReady(article), isFalse,
          reason: 'it is made next time, not marked as done');
    });
  }

  test('every draw in the share service checks first', () {
    final src = File('lib/utils/share_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    for (final draw in [
      'captureFromLongWidget(',
      'captureFromWidget(',
      'picture.toImage(',
    ]) {
      final at = src.indexOf(draw);
      expect(at, greaterThan(0), reason: draw);
      expect(src.substring(at - 160, at), contains('canDraw'), reason: draw);
    }
  });
}
