import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/spotlight/story_options_sheet.dart';

Future<StoryOption?> _open(WidgetTester tester,
    {bool saved = false, String? tapKey}) async {
  StoryOption? result;
  var done = false;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await StoryOptionsSheet.show(context,
                isBookmarked: saved);
            done = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (tapKey != null) {
    await tester.tap(find.byKey(Key(tapKey)));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  }
  return result;
}

void main() {
  setUp(() => AppState.instance.language = 'English');

  testWidgets('shows close, disclaimer, Report Story and Bookmark',
      (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('story_options_close')), findsOneWidget);
    expect(find.textContaining('does not reflect the views of',
        findRichText: true), findsOneWidget);
    expect(find.text('Report Story'), findsOneWidget);
    expect(find.text('Help us improve better'), findsOneWidget);
    expect(find.text('Bookmark'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
  });


  testWidgets('a saved story shows the filled ribbon', (tester) async {
    await _open(tester, saved: true);
    expect(find.text('Bookmarked'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });

  testWidgets('each option returns its choice', (tester) async {
    expect(await _open(tester, tapKey: 'story_option_report'),
        StoryOption.report);
    expect(await _open(tester, tapKey: 'story_option_bookmark'),
        StoryOption.bookmark);
    expect(await _open(tester, tapKey: 'story_options_close'), isNull);
  });

  test('the action bar has ⋮ instead of a bookmark icon', () {
    final src = File('lib/widgets/spotlight/spotlight_news_card.dart')
        .readAsStringSync();
    expect(src, contains('Icons.more_vert_rounded'));
    expect(src, contains('_showMoreSheet(article)'));
    expect(src, isNot(contains('Icons.bookmark_border_rounded')));
  });
}
