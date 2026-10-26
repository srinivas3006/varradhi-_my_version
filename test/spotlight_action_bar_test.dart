import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/news_action_button.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

NewsArticle _story() => NewsArticle.fromJson({
      'id': '11111111-2222-3333-4444-555555555555',
      'title': 'శీర్షిక',
      'content': 'కథనం',
      'image_url': 'https://cdn.test/a.jpg',
      'like_count': 1234,
      'dislike_count': 12,
      'comment_count': 56,
      'published_at': DateTime(2026, 10, 1).toIso8601String(),
    });

/// The Spotlight action bar with the pastel action buttons.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = 'Telugu';
  });

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('all six actions fit a ${width.toInt()} px phone',
        (tester) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var shared = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpotlightNewsCard(
            article: _story(),
            onTap: () {},
            onShare: () => shared++,
            onClose: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'no overflow');

      final actions = tester
          .widgetList<NewsActionButton>(find.byType(NewsActionButton))
          .map((b) => b.action)
          .toSet();
      expect(actions, containsAll(NewsAction.values));

      // Share still opens the share flow at once.
      await tester.tap(find.byIcon(Icons.share_rounded));
      expect(shared, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  }

  test('dislike shows no confirmation pop-up', () {
    final src = File('lib/widgets/spotlight/spotlight_news_card.dart')
        .readAsStringSync();
    expect(src, isNot(contains('Feedback received')));
    expect(src, isNot(contains('Dislike removed')));
    expect(src, isNot(contains('మీ అభిప్రాయం నమోదు చేయబడింది')));
    expect(src, isNot(contains('డిస్‌లైక్ తీసివేయబడింది')));
  });

  testWidgets('the white strip spans the screen; Share rises above it',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpotlightNewsCard(
          article: _story(),
          onTap: () {},
          onShare: () {},
          onClose: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    final strip = find.byKey(const Key('spotlight_action_strip'));
    final rect = tester.getRect(strip);
    expect(rect.left, 0);
    expect(rect.width, 360, reason: 'edge to edge, past the story margins');
    final box = tester.widget<DecoratedBox>(strip).decoration as BoxDecoration;
    expect(box.color, Colors.white);

    final share = tester.getRect(find.byWidgetPredicate(
        (w) => w is NewsActionButton && w.action == NewsAction.share));
    expect(share.top, lessThan(rect.top), reason: 'raised over the top edge');
    expect(share.center.dx, closeTo(180, 1), reason: 'centred');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('a count appearing never moves the other actions',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final story = NewsArticle.fromJson({
      'id': '11111111-2222-3333-4444-555555555555',
      'title': 't',
      'content': 'c',
      'image_url': 'https://cdn.test/a.jpg',
      'published_at': DateTime(2026, 10, 1).toIso8601String(),
    }); // 0 likes: no count yet
    late StateSetter set;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (c, s) {
          set = s;
          return SpotlightNewsCard(
            article: story,
            onTap: () {},
            onShare: () {},
            onClose: () {},
          );
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    Rect dislike() => tester.getRect(find.byWidgetPredicate(
        (w) => w is NewsActionButton && w.action == NewsAction.dislike));
    final before = dislike();
    set(() => story.likes = 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(dislike(), before);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
