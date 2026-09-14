import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/feed/feed_block.dart';
import 'package:way2news_clone/core/feed/feed_engine.dart';
import 'package:way2news_clone/core/feed/feed_block_renderer.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/models/category.dart';
import 'package:way2news_clone/models/poll.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  NewsArticle createDummyArticle(String id, String title) {
    return NewsArticle(
      id: id,
      title: title,
      summary: 'Sample summary',
      body: 'Sample body',
      imageUrl: 'https://example.com/$id.jpg',
      source: 'Vaaradhi',
      category: 'General',
      publishedAt: DateTime.now(),
      likes: 10,
      comments: 5,
      shares: 2,
      readTimeMinutes: 3,
      viewCount: 100,
    );
  }

  AdBanner createDummyAd(String id) {
    return AdBanner(
      id: id,
      title: 'Ad $id',
      imageUrl: 'https://example.com/ad_$id.jpg',
      destinationUrl: 'https://example.com',
      adType: 'banner',
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: 5,
      ctr: 0.0,
    );
  }

  group('FeedEngine Architecture & Composition Tests', () {
    test('1. Initial Paint reduction contains strictly essential sections', () {
      const engine = FeedEngine(
        config: FeedEngineConfig(
          minArticlesBeforeFirstAd: 2,
          defaultAdFrequency: 5,
        ),
      );

      final breaking = [createDummyArticle('b1', 'Breaking 1')];
      final categories = [
        Category(
          id: 'cat-1',
          name: 'రాజకీయాలు',
          slug: 'politics',
          icon: 'politics',
          order: 1,
          isActive: true,
        ),
      ];
      final villageArticles = [createDummyArticle('v1', 'Village 1')];
      final mandalArticles = [createDummyArticle('m1', 'Mandal 1')];
      final districtArticles = [createDummyArticle('d1', 'District 1')];
      final recommended = [
        createDummyArticle('r1', 'Rec 1'),
        createDummyArticle('r2', 'Rec 2'),
        createDummyArticle('r3', 'Rec 3'),
      ];
      final ads = [createDummyAd('ad-1')];

      // Test FIRST PAINT
      final firstPaintBlocks = engine.compose(
        breakingNews: breaking,
        categories: categories,
        recommendedArticles: recommended,
        adPool: ads,
        selectedVillage: 'మోతే',
        selectedSubdistrict: 'సూర్యాపేట',
        selectedDistrict: 'సూర్యాపేట',
        villageArticles: villageArticles,
        mandalArticles: mandalArticles,
        districtArticles: districtArticles,
        isInitialPaint: true,
      );

      // Verify first paint only contains village (tier 1) and NO mandal/district
      final hasVillage = firstPaintBlocks
          .any((b) => b is HyperLocalBlock && b.tier == HyperlocalTier.village);
      final hasMandal = firstPaintBlocks
          .any((b) => b is HyperLocalBlock && b.tier == HyperlocalTier.mandal);
      final hasDistrict = firstPaintBlocks.any(
          (b) => b is HyperLocalBlock && b.tier == HyperlocalTier.district);

      expect(hasVillage, isTrue);
      expect(hasMandal, isFalse);
      expect(hasDistrict, isFalse);
    });

    test('2. Hydrated state attaches secondary tiers and community widgets',
        () {
      const engine = FeedEngine();

      final breaking = [createDummyArticle('b1', 'Breaking 1')];
      final categories = [
        Category(
          id: 'cat-1',
          name: 'రాజకీయాలు',
          slug: 'politics',
          icon: 'politics',
          order: 1,
          isActive: true,
        ),
      ];
      final villageArticles = [createDummyArticle('v1', 'Village 1')];
      final mandalArticles = [createDummyArticle('m1', 'Mandal 1')];
      final districtArticles = [createDummyArticle('d1', 'District 1')];
      final recommended = [createDummyArticle('r1', 'Rec 1')];
      final poll = Poll(
        id: 'p1',
        question: 'Opinion test?',
        options: const ['Option 1', 'Option 2'],
        votes: const [10, 5],
        isActive: true,
      );

      final hydratedBlocks = engine.compose(
        breakingNews: breaking,
        categories: categories,
        recommendedArticles: recommended,
        adPool: const [],
        selectedVillage: 'మోతే',
        selectedSubdistrict: 'సూర్యాపేట',
        selectedDistrict: 'సూర్యాపేట',
        villageArticles: villageArticles,
        mandalArticles: mandalArticles,
        districtArticles: districtArticles,
        poll: poll,
        dailyQuote: {'text': 'Wisdom', 'author': 'Vivekananda'},
        isInitialPaint: false,
      );

      expect(
        hydratedBlocks.any(
            (b) => b is HyperLocalBlock && b.tier == HyperlocalTier.village),
        isTrue,
      );
      expect(
        hydratedBlocks.any(
            (b) => b is HyperLocalBlock && b.tier == HyperlocalTier.mandal),
        isTrue,
      );
      expect(
        hydratedBlocks.any(
            (b) => b is HyperLocalBlock && b.tier == HyperlocalTier.district),
        isTrue,
      );
      expect(hydratedBlocks.any((b) => b is PollBlock), isTrue);
      expect(hydratedBlocks.any((b) => b is DailyGreetingBlock), isTrue);
    });

    test(
        '3. Deterministic Ad Placement with exact intervals and zero duplicates',
        () {
      const engine = FeedEngine(
        config: FeedEngineConfig(
          minArticlesBeforeFirstAd: 2,
          defaultAdFrequency: 3,
        ),
      );

      final articles = List.generate(
        10,
        (i) => createDummyArticle('art-$i', 'Article $i'),
      );
      final ads = [
        createDummyAd('ad-1'),
        createDummyAd('ad-2'),
      ];

      final blocks = engine.compose(
        breakingNews: const [],
        categories: const [],
        recommendedArticles: articles,
        adPool: ads,
        isInitialPaint: false,
      );

      final adBlocks = blocks.whereType<AdBlock>().toList();
      // Each backend ad requests five parent cards, regardless of legacy config.
      expect(adBlocks.length, equals(2));
      expect(adBlocks.map((block) => block.ad.id), ['ad-1', 'ad-2']);

      // Assert unique exposureKeys
      final exposureKeys = adBlocks.map((a) => a.exposureKey).toSet();
      expect(exposureKeys.length, equals(adBlocks.length));
    });

    testWidgets('4. FeedBlockRenderer renders FeedBlock elements cleanly',
        (tester) async {
      final callbacks = FeedRendererCallbacks(
        onSelectCategory: (_) {},
        onArticleTap: (_) {},
        onLiveStreamTap: (_) {},
        onSpotlightTap: () {},
      );

      final renderer = FeedBlockRenderer(
        callbacks: callbacks,
        cardColor: Colors.grey.shade100,
        borderColor: Colors.grey.shade300,
      );

      final testBlock = ArticleBlock(
        article: createDummyArticle('art-100', 'ఆర్కిటెక్చర్ వార్త'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => renderer.buildFeedItem(context, testBlock),
            ),
          ),
        ),
      );

      expect(find.text('ఆర్కిటెక్చర్ వార్త'), findsOneWidget);
    });
  });
}
