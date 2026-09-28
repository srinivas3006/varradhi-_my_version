import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/screens/news_detail_screen.dart';

NewsArticle _story({required String kind}) => NewsArticle(
      id: '$kind-123',
      title: 'Road damage reported in Kesaram',
      slug: '$kind-123',
      summary: 'Residents requested urgent repairs.',
      body: 'Residents requested urgent repairs.',
      imageUrl: '',
      source: 'Reporter',
      category: 'Local',
      publishedAt: DateTime(2026, 1, 1),
      likes: 0,
      comments: 0,
      shares: 0,
      readTimeMinutes: 1,
      viewCount: 0,
      state: 'Telangana',
      district: 'Suryapet',
      subdistrict: 'Jajireddygudem',
      village: 'Kesaram',
      coverageLevel: 'local',
      contentKind: kind,
    );

void main() {
  testWidgets('a citizen post opens exactly like a desk article',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: NewsDetailScreen(article: _story(kind: 'ugc'))),
    );
    await tester.pump();

    expect(find.text('Road damage reported in Kesaram'), findsOneWidget);
    expect(
        find.textContaining('esidents requested urgent repairs.',
            findRichText: true),
        findsOneWidget);
    // No separate citizen-only strip.
    expect(find.text('పౌర వార్త'), findsNothing);
    // Same header menu and engagement bar as every story.
    expect(find.byKey(const Key('detail_more_btn')), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Report lives in the shared ⋮ sheet.
    await tester.tap(find.byKey(const Key('detail_more_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story_option_report')), findsOneWidget);
    expect(find.byKey(const Key('story_option_bookmark')), findsOneWidget);
  });
}
