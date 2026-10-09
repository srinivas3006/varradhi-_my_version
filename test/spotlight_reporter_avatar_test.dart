import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/models/unified_feed_item.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

NewsArticle _citizenPost({Map<String, dynamic>? uploader}) =>
    UnifiedFeedItem.fromJson({
      'id': '7cb8',
      'type': 'ugc',
      'title': 'రూ.300 శ్రీవారి దర్శన టికెట్లు విడుదల',
      'description': 'తిరుమల',
      'source': 'USER_UPLOAD',
      'state': 'Telangana',
      'thumbnail_url': 'https://cdn.test/p.jpg',
      'created_at': DateTime.now().toIso8601String(),
      'uploader': uploader ??
          {
            'id': 'u1',
            'display_name': 'Ramakrishna Sagar',
            'trust_level': 'VERIFIED_USER',
          },
    }).toArticle();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uploader photo and level are read', () {
    final a = _citizenPost(uploader: {
      'display_name': 'Ramakrishna Sagar',
      'trust_level': 'TRUSTED_REPORTER',
      'avatar_url': 'https://cdn.test/u1.jpg',
    });
    expect(a.authorAvatarUrl, 'https://cdn.test/u1.jpg');
    expect(a.authorLevel, 'TRUSTED_REPORTER');
  });

  testWidgets('reporter row: circle, name, level line', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpotlightNewsCard(
          article: _citizenPost(),
          isCurrent: true,
          onTap: () {},
          onShare: () {},
          onClose: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('spotlight_reporter')), findsOneWidget);
    expect(find.text('Ramakrishna Sagar'), findsOneWidget);
    expect(find.text('ధృవీకరించిన రిపోర్టర్'), findsOneWidget);
    // No photo sent: the first letter in the circle.
    expect(find.byKey(const Key('spotlight_reporter_initial')), findsOneWidget);
    expect(find.text('R'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
