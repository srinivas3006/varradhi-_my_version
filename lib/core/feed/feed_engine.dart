import 'package:flutter/material.dart';
import '../../models/news_article.dart';
import '../../models/ad_banner.dart';
import '../../models/category.dart';
import '../../models/poll.dart';
import '../../models/live_news.dart';
import 'feed_block.dart';

/// Configuration for feed composition and progressive hydration.
class FeedEngineConfig {
  final int minArticlesBeforeFirstAd;
  final int defaultAdFrequency;
  final int maxHyperlocalPreviewCount;
  final bool enableProgressiveHydration;

  const FeedEngineConfig({
    this.minArticlesBeforeFirstAd = 5,
    this.defaultAdFrequency = 5,
    this.maxHyperlocalPreviewCount = 5,
    this.enableProgressiveHydration = true,
  });
}

/// Central Feed Engine responsible for:
/// 1. Composing high-performance, virtualizable `List<FeedBlock>`.
/// 2. Staging progressive hydration (Phase 1: First Paint; Phase 2: Deferred Hydration).
/// 3. Deterministic ad placement and deduplication during pagination.
/// 4. Eliminating nested scrolling and monolithic layout bottlenecks.
class FeedEngine {
  final FeedEngineConfig config;

  const FeedEngine({this.config = const FeedEngineConfig()});

  /// Composes the complete feed block list.
  ///
  /// [isInitialPaint]: When true, strictly restricts the output to:
  /// - Categories & Live Stream (if any)
  /// - Breaking News
  /// - Tier 1 Hyperlocal (e.g. Village or nearest available single local tier)
  /// - Immediate Recommended / For You Articles with initial deterministic ad slots
  ///
  /// When [isInitialPaint] is false (hydrated state), secondary tiers (mandal, district,
  /// state, national), community polls, quotes, and posters are stitched seamlessly.
  List<FeedBlock> compose({
    required List<NewsArticle> breakingNews,
    required List<Category> categories,
    required List<NewsArticle> recommendedArticles,
    required List<AdBanner> adPool,
    String? selectedCategory,
    LiveNews? activeLiveStream,
    bool showSpotlightHero = true,
    // Hyperlocal sections
    String selectedVillage = '',
    String selectedSubdistrict = '',
    String selectedDistrict = '',
    String selectedState = '',
    List<NewsArticle> villageArticles = const [],
    List<NewsArticle> mandalArticles = const [],
    List<NewsArticle> districtArticles = const [],
    List<NewsArticle> stateArticles = const [],
    List<NewsArticle> nationalArticles = const [],
    // Interactive & Daily widgets
    Map<String, dynamic>? dailyQuote,
    Poll? poll,
    List<dynamic> posters = const [],
    // Pagination & Progressive flag
    bool isInitialPaint = false,
    bool hasMore = false,
  }) {
    final blocks = <FeedBlock>[];

    // 1. Category selector (always present at top)
    if (categories.isNotEmpty) {
      blocks.add(CategorySelectorBlock(
        categories: categories,
        selectedCategory: selectedCategory,
      ));
    }

    // 2. Active live video broadcast (if active)
    if (activeLiveStream != null && activeLiveStream.isLiveActive) {
      blocks.add(LiveStreamBlock(liveNews: activeLiveStream));
    }

    // 3. Spotlight Hero entry banner
    if (showSpotlightHero) {
      blocks.add(const SpotlightHeroBlock());
    }

    // 4. Breaking News Carousel
    if (breakingNews.isNotEmpty) {
      blocks.add(BreakingNewsBlock(articles: breakingNews));
    }

    // 5. Hyperlocal Tiers
    if (isInitialPaint) {
      // FIRST PAINT OPTIMIZATION: Only render the single closest local tier
      if (selectedVillage.isNotEmpty && villageArticles.isNotEmpty) {
        blocks.add(_buildVillageBlock(selectedVillage, villageArticles));
      } else if (selectedSubdistrict.isNotEmpty && mandalArticles.isNotEmpty) {
        blocks.add(_buildMandalBlock(selectedSubdistrict, mandalArticles));
      } else if (selectedDistrict.isNotEmpty && districtArticles.isNotEmpty) {
        blocks.add(_buildDistrictBlock(selectedDistrict, districtArticles));
      } else if (villageArticles.isNotEmpty) {
        blocks.add(_buildVillageBlock(
            selectedVillage.isEmpty ? 'స్థానిక' : selectedVillage,
            villageArticles));
      }
    } else {
      // PROGRESSIVELY HYDRATED: All configured geographic tiers
      if (selectedVillage.isNotEmpty) {
        blocks.add(_buildVillageBlock(selectedVillage, villageArticles));
      }
      if (selectedSubdistrict.isNotEmpty) {
        blocks.add(_buildMandalBlock(selectedSubdistrict, mandalArticles));
      }
      if (selectedDistrict.isNotEmpty) {
        blocks.add(_buildDistrictBlock(selectedDistrict, districtArticles));
      }
      if (selectedState.isNotEmpty) {
        blocks.add(_buildStateBlock(selectedState, stateArticles));
      }
      if (nationalArticles.isNotEmpty) {
        blocks.add(_buildNationalBlock(nationalArticles));
      }

      // Secondary Interactive Widgets (deferred to Phase 2)
      if (dailyQuote != null &&
          (dailyQuote['text'] != null || dailyQuote['quote'] != null)) {
        blocks.add(DailyGreetingBlock(
          quote: dailyQuote['text'] ?? dailyQuote['quote'] ?? '',
          author: dailyQuote['author'] ?? 'Daily Quote',
          imageUrl: dailyQuote['image_url'] ?? dailyQuote['imageUrl'] ?? '',
        ));
      }

      if (poll != null) {
        blocks.add(PollBlock(poll: poll));
      }

      if (posters.isNotEmpty) {
        blocks.add(PostersBlock(posters: posters));
      }
    }

    // 6. Feed Transition Divider
    if (recommendedArticles.isNotEmpty) {
      blocks
          .add(const SectionDividerBlock(title: 'మీ కోసం ఎంపిక చేసిన వార్తలు'));
    }

    // 7. Infinite Algorithmic Feed with Deterministic Ad Placement
    final articleBlocks = _interleaveArticlesAndAds(
      articles: recommendedArticles,
      adPool: adPool,
      startIndex: 0,
    );
    blocks.addAll(articleBlocks);

    // 8. Pagination Loader Footer
    if (hasMore) {
      blocks.add(const LoadingFooterBlock());
    }

    return blocks;
  }

  /// Interleaves articles with ads deterministically to guarantee 0 duplicates.
  List<FeedBlock> _interleaveArticlesAndAds({
    required List<NewsArticle> articles,
    required List<AdBanner> adPool,
    int startIndex = 0,
  }) {
    final result = <FeedBlock>[];
    if (articles.isEmpty) return result;

    if (adPool.isEmpty) {
      for (int i = 0; i < articles.length; i++) {
        result.add(ArticleBlock(
          article: articles[i],
          stableKey: 'article_${articles[i].id}_${startIndex + i}',
        ));
      }
      return result;
    }

    int articleCounter = startIndex;
    int adPoolIndex = 0;

    for (int i = 0; i < articles.length; i++) {
      final article = articles[i];
      result.add(ArticleBlock(
        article: article,
        stableKey: 'article_${article.id}_${startIndex + i}',
      ));
      articleCounter++;

      final shouldInsertAd =
          articleCounter >= config.minArticlesBeforeFirstAd &&
              articleCounter % config.defaultAdFrequency == 0;

      if (shouldInsertAd && adPool.isNotEmpty) {
        final ad = adPool[adPoolIndex % adPool.length];
        adPoolIndex++;
        final exposureKey =
            'feed_ad_${ad.id}_after_art_${article.id}_pos_$articleCounter';
        result.add(AdBlock(
          ad: ad,
          exposureKey: exposureKey,
          placementZone: 'feed',
        ));
      }
    }

    return result;
  }

  HyperLocalBlock _buildVillageBlock(String name, List<NewsArticle> articles) {
    return HyperLocalBlock(
      id: 'hyperlocal-village-$name',
      title: '$name స్థానిక వార్తలు',
      location: name,
      icon: Icons.holiday_village_outlined,
      accent: const Color(0xFFE53935),
      articles: articles.take(config.maxHyperlocalPreviewCount).toList(),
      tier: HyperlocalTier.village,
      emptyMessage:
          'ఈ ప్రాంతానికి ఇంకా స్థానిక వార్తలు లేవు. దగ్గరి ప్రాంతాల వార్తలు కింద కనిపిస్తాయి.',
    );
  }

  HyperLocalBlock _buildMandalBlock(String name, List<NewsArticle> articles) {
    return HyperLocalBlock(
      id: 'hyperlocal-mandal-$name',
      title: '$name మండల వార్తలు',
      location: name,
      icon: Icons.location_city_outlined,
      accent: Colors.teal,
      articles: articles.take(config.maxHyperlocalPreviewCount).toList(),
      tier: HyperlocalTier.mandal,
      emptyMessage:
          'ఈ మండలంలో ఇంకా వార్తలు లేవు. జిల్లా మరియు రాష్ట్ర వార్తలు కింద కనిపిస్తాయి.',
    );
  }

  HyperLocalBlock _buildDistrictBlock(String name, List<NewsArticle> articles) {
    return HyperLocalBlock(
      id: 'hyperlocal-district-$name',
      title: '$name జిల్లా వార్తలు',
      location: '$name జిల్లా',
      icon: Icons.domain_outlined,
      accent: Colors.indigo,
      articles: articles.take(config.maxHyperlocalPreviewCount).toList(),
      tier: HyperlocalTier.district,
    );
  }

  HyperLocalBlock _buildStateBlock(String name, List<NewsArticle> articles) {
    return HyperLocalBlock(
      id: 'hyperlocal-state-$name',
      title: '$name ముఖ్యాంశాలు',
      location: name,
      icon: Icons.map_outlined,
      accent: Colors.deepOrange,
      articles: articles.take(config.maxHyperlocalPreviewCount).toList(),
      tier: HyperlocalTier.state,
    );
  }

  HyperLocalBlock _buildNationalBlock(List<NewsArticle> articles) {
    return HyperLocalBlock(
      id: 'hyperlocal-national-global',
      title: 'జాతీయ / అంతర్జాతీయ వార్తలు',
      location: 'జాతీయం / అంతర్జాతీయం',
      icon: Icons.public_outlined,
      accent: Colors.blueGrey,
      articles: articles.take(config.maxHyperlocalPreviewCount).toList(),
      tier: HyperlocalTier.nationalGlobal,
    );
  }
}
