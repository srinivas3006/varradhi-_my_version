import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/screens/news_detail_screen.dart';

void main() {
  testWidgets('UGC detail uses feed content and only supported actions',
      (tester) async {
    final report = NewsArticle(
      id: 'ugc-123',
      title: 'Road damage reported in Kesaram',
      slug: 'ugc-123',
      summary: 'Residents requested urgent repairs.',
      body: 'Residents requested urgent repairs.',
      imageUrl: '',
      source: 'Citizen Reporter',
      category: 'UGC',
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
      contentKind: 'ugc',
    );

    await tester.pumpWidget(
      MaterialApp(home: NewsDetailScreen(article: report)),
    );
    await tester.pump();

    expect(find.text('Road damage reported in Kesaram'), findsOneWidget);
    expect(find.text('Residents requested urgent repairs.'), findsOneWidget);
    expect(find.text('పౌర వార్త'), findsOneWidget);
    expect(find.text('నివేదించండి'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('నివేదించండి'));
    await tester.pumpAndSettle();

    expect(find.text('పౌర వార్తను నివేదించండి'), findsOneWidget);
    expect(find.text('తప్పుడు లేదా తప్పుదారి పట్టించే సమాచారం'), findsOneWidget);
  });
}
