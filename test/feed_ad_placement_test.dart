import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/services/ad_manager.dart';

void main() {
  group('Feed Presentation Placement Tests', () {
    late AdManager manager;

    final ad1 = AdBanner(
      id: 'ad_feed_1',
      title: 'Feed Ad 1',
      imageUrl: 'https://example.com/ad1.jpg',
      destinationUrl: 'https://example.com/1',
      adType: 'native',
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: 4,
      ctr: 1.0,
    );

    final ad2 = AdBanner(
      id: 'ad_feed_2',
      title: 'Feed Ad 2',
      imageUrl: 'https://example.com/ad2.jpg',
      destinationUrl: 'https://example.com/2',
      adType: 'native',
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: 4,
      ctr: 1.5,
    );

    setUp(() {
      manager = AdManager.createTest();
    });

    test('returns pure content items when ads pool is empty', () {
      final articles = ['Art 1', 'Art 2', 'Art 3', 'Art 4', 'Art 5'];
      final presentation = manager.buildFeedPresentation<String>(
        contentItems: articles,
        adsPool: [],
      );

      expect(presentation.length, 5);
      expect(presentation.every((p) => !p.isAd), isTrue);
      expect(presentation.map((p) => p.content).toList(), articles);
    });

    test('does NOT mutate the original content list', () {
      final originalList = ['Art 1', 'Art 2', 'Art 3', 'Art 4', 'Art 5'];
      final listCopy = List<String>.from(originalList);

      manager.buildFeedPresentation<String>(
        contentItems: originalList,
        adsPool: [ad1, ad2],
      );

      expect(originalList, listCopy);
    });

    test('inserts ads after minArticlesBeforeFirstAd based on displayFrequency', () {
      // 10 articles with displayFrequency = 4
      final articles = List.generate(10, (i) => 'Article ${i + 1}');

      final presentation = manager.buildFeedPresentation<String>(
        contentItems: articles,
        adsPool: [ad1, ad2],
        overrideFrequency: 4,
      );

      // Total items should have 10 articles + 2 ads inserted at intervals
      final adItems = presentation.where((p) => p.isAd).toList();
      final contentItems = presentation.where((p) => !p.isAd).toList();

      expect(contentItems.length, 10);
      expect(adItems.length, 2);

      // Verify no ad before first 2 articles
      expect(presentation[0].isAd, isFalse);
      expect(presentation[1].isAd, isFalse);

      // First ad inserted after 4 content items (at index 4 + 1 = 5)
      expect(presentation[4].isAd, isTrue);
      expect(presentation[4].ad!.id, 'ad_feed_1');

      // Verify stable keys
      expect(presentation[4].stableKey.startsWith('ad_ad_feed_1'), isTrue);
      expect(presentation[0].stableKey, 'content_0');
    });

    test('handles pagination cleanly by rebuilding presentation with appended articles', () {
      final page1 = List.generate(5, (i) => 'P1 Item $i');
      final p1 = manager.buildFeedPresentation<String>(
        contentItems: page1,
        adsPool: [ad1, ad2],
        overrideFrequency: 3,
      );

      expect(p1.where((i) => i.isAd).length, 1);

      // Page 2 arrives
      final page2 = [...page1, ...List.generate(5, (i) => 'P2 Item $i')];
      final p2 = manager.buildFeedPresentation<String>(
        contentItems: page2,
        adsPool: [ad1, ad2],
        overrideFrequency: 3,
      );

      expect(p2.where((i) => i.isAd).length, 3);
      expect(p2.where((i) => !i.isAd).length, 10);
    });
  });
}
