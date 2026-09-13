import 'package:flutter/material.dart';
import '../../models/news_article.dart';
import '../../models/ad_banner.dart';
import '../../models/category.dart';
import '../../models/poll.dart';
import '../../models/live_news.dart';

/// Distinct block types for feed engine virtualization.
enum FeedBlockType {
  categorySelector,
  liveStream,
  spotlightHero,
  breakingNews,
  hyperlocalSection,
  dailyGreeting,
  poll,
  postersStrip,
  sectionDivider,
  article,
  ad,
  loadingFooter,
}

/// Supported hyperlocal tier depth levels.
enum HyperlocalTier {
  village,
  mandal,
  district,
  state,
  nationalGlobal,
}

/// Abstract base class for all items in the virtualized feed list.
abstract class FeedBlock {
  final String id;
  final FeedBlockType type;

  const FeedBlock({
    required this.id,
    required this.type,
  });
}

/// 1. Category selector block
class CategorySelectorBlock extends FeedBlock {
  final List<Category> categories;
  final String? selectedCategory;

  const CategorySelectorBlock({
    required this.categories,
    this.selectedCategory,
  }) : super(id: 'block-category-selector', type: FeedBlockType.categorySelector);
}

/// 2. Active live video stream block (conditional)
class LiveStreamBlock extends FeedBlock {
  final LiveNews liveNews;

  LiveStreamBlock({
    required this.liveNews,
  }) : super(id: 'block-live-stream-${liveNews.id}', type: FeedBlockType.liveStream);
}

/// 3. Spotlight hero banner block
class SpotlightHeroBlock extends FeedBlock {
  const SpotlightHeroBlock()
      : super(id: 'block-spotlight-hero', type: FeedBlockType.spotlightHero);
}

/// 4. Breaking news hero carousel block
class BreakingNewsBlock extends FeedBlock {
  final List<NewsArticle> articles;

  const BreakingNewsBlock({
    required this.articles,
  }) : super(id: 'block-breaking-carousel', type: FeedBlockType.breakingNews);
}

/// 5. Hyperlocal multi-tier section block
class HyperLocalBlock extends FeedBlock {
  final String title;
  final String location;
  final IconData icon;
  final Color accent;
  final List<NewsArticle> articles;
  final HyperlocalTier tier;
  final bool showWhenEmpty;
  final String emptyMessage;

  const HyperLocalBlock({
    required super.id,
    required this.title,
    required this.location,
    required this.icon,
    required this.accent,
    required this.articles,
    required this.tier,
    this.showWhenEmpty = true,
    this.emptyMessage = 'ఈ విభాగంలో ఇంకా వార్తలు లేవు.',
  }) : super(type: FeedBlockType.hyperlocalSection);
}

/// 6. Daily quote / greeting card block
class DailyGreetingBlock extends FeedBlock {
  final String quote;
  final String author;
  final String imageUrl;

  const DailyGreetingBlock({
    required this.quote,
    required this.author,
    required this.imageUrl,
  }) : super(id: 'block-daily-greeting', type: FeedBlockType.dailyGreeting);
}

/// 7. Interactive community poll block
class PollBlock extends FeedBlock {
  final Poll poll;

  PollBlock({
    required this.poll,
  }) : super(id: 'block-poll-${poll.id}', type: FeedBlockType.poll);
}

/// 8. Posters horizontal strip block
class PostersBlock extends FeedBlock {
  final List<dynamic> posters;

  const PostersBlock({
    required this.posters,
  }) : super(id: 'block-posters-strip', type: FeedBlockType.postersStrip);
}

/// 9. Feed transition divider block
class SectionDividerBlock extends FeedBlock {
  final String title;

  const SectionDividerBlock({
    required this.title,
  }) : super(id: 'block-divider-$title', type: FeedBlockType.sectionDivider);
}

/// 10. Individual standard article card in infinite feed
class ArticleBlock extends FeedBlock {
  final NewsArticle article;
  final String stableKey;

  ArticleBlock({
    required this.article,
    String? stableKey,
  })  : stableKey = stableKey ?? 'feed-art-${article.id}',
        super(id: stableKey ?? 'feed-art-${article.id}', type: FeedBlockType.article);
}

/// 11. In-feed advertisement block
class AdBlock extends FeedBlock {
  final AdBanner ad;
  final String placementZone;
  final String exposureKey;

  const AdBlock({
    required this.ad,
    required this.exposureKey,
    this.placementZone = 'feed',
  }) : super(id: exposureKey, type: FeedBlockType.ad);
}

/// 12. Infinite scroll pagination loader footer block
class LoadingFooterBlock extends FeedBlock {
  const LoadingFooterBlock()
      : super(id: 'block-loading-footer', type: FeedBlockType.loadingFooter);
}
