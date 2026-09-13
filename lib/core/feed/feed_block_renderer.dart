import 'package:flutter/material.dart';
import '../../models/news_article.dart';
import '../../models/live_news.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ads/unified_ad_widget.dart';
import '../../widgets/feed/daily_greeting_widget.dart';
import '../../widgets/poll_card.dart';
import 'feed_block.dart';

/// Callbacks required by the feed block renderer.
class FeedRendererCallbacks {
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<NewsArticle> onArticleTap;
  final ValueChanged<LiveNews> onLiveStreamTap;
  final VoidCallback onSpotlightTap;
  final ValueChanged<NewsArticle>? onBookmarkToggle;
  final ValueChanged<NewsArticle>? onShareTap;

  const FeedRendererCallbacks({
    required this.onSelectCategory,
    required this.onArticleTap,
    required this.onLiveStreamTap,
    required this.onSpotlightTap,
    this.onBookmarkToggle,
    this.onShareTap,
  });
}

/// Decoupled, pure item renderer mapping `FeedBlock` models to performant widgets.
class FeedBlockRenderer {
  final FeedRendererCallbacks callbacks;
  final Color cardColor;
  final Color borderColor;

  const FeedBlockRenderer({
    required this.callbacks,
    required this.cardColor,
    required this.borderColor,
  });

  /// The primary dispatch function: takes a [FeedBlock] and renders its optimized UI.
  Widget buildFeedItem(BuildContext context, FeedBlock block) {
    switch (block.type) {
      case FeedBlockType.categorySelector:
        return _buildCategorySelector(context, block as CategorySelectorBlock);

      case FeedBlockType.liveStream:
        return _buildLiveStreamBanner(context, block as LiveStreamBlock);

      case FeedBlockType.spotlightHero:
        return _buildSpotlightHero(context);

      case FeedBlockType.breakingNews:
        return _buildBreakingNewsCarousel(context, block as BreakingNewsBlock);

      case FeedBlockType.hyperlocalSection:
        return _buildHyperlocalSection(context, block as HyperLocalBlock);

      case FeedBlockType.dailyGreeting:
        final greeting = block as DailyGreetingBlock;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DailyGreetingWidget(
            imageUrl: greeting.imageUrl,
            title: greeting.author,
            quote: greeting.quote,
          ),
        );

      case FeedBlockType.poll:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: PollCard(poll: (block as PollBlock).poll),
        );

      case FeedBlockType.postersStrip:
        return _buildPostersStrip(context, block as PostersBlock);

      case FeedBlockType.sectionDivider:
        return _buildSectionDivider(context, (block as SectionDividerBlock).title);

      case FeedBlockType.article:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _buildStandardArticleCard(context, (block as ArticleBlock).article),
        );

      case FeedBlockType.ad:
        final adBlock = block as AdBlock;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: UnifiedAdWidget(
            key: ValueKey(adBlock.exposureKey),
            ad: adBlock.ad,
            placementZone: adBlock.placementZone,
            exposureKey: adBlock.exposureKey,
          ),
        );

      case FeedBlockType.loadingFooter:
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: CircularProgressIndicator(),
          ),
        );
    }
  }

  // --- Specialized Sub-Renderers with RepaintBoundary / Layout Isolation ---

  Widget _buildCategorySelector(BuildContext context, CategorySelectorBlock block) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: block.categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAll = block.selectedCategory == null;
            return ChoiceChip(
              label: const Text('అన్నీ'),
              selected: isAll,
              onSelected: (_) => callbacks.onSelectCategory(null),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isAll ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }
          final cat = block.categories[index - 1];
          final isSelected = block.selectedCategory == cat.id || block.selectedCategory == cat.name;
          return ChoiceChip(
            label: Text(cat.name),
            selected: isSelected,
            onSelected: (_) => callbacks.onSelectCategory(cat.id),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveStreamBanner(BuildContext context, LiveStreamBlock block) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => callbacks.onLiveStreamTap(block.liveNews),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade900.withValues(alpha: 0.8), Colors.black87],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    block.liveNews.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotlightHero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: callbacks.onSpotlightTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.2), cardColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'స్పాట్‌లైట్ | శీఘ్ర ముఖ్యాంశాలు స్వైప్ చేసి చదవండి',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakingNewsCarousel(BuildContext context, BreakingNewsBlock block) {
    if (block.articles.isEmpty) return const SizedBox.shrink();
    final article = block.articles.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: RepaintBoundary(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => callbacks.onArticleTap(article),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cardColor,
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (article.imageUrl.isNotEmpty)
                  Image.network(
                    article.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    ),
                  ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.3, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '⚡ తాజా వార్తలు',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHyperlocalSection(BuildContext context, HyperLocalBlock block) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(block.icon, size: 18, color: block.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  block.location,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: block.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (block.articles.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                block.emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            )
          else
            ...block.articles.map(
              (art) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildStandardArticleCard(context, art),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostersStrip(BuildContext context, PostersBlock block) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: block.posters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final poster = block.posters[index];
          final imgUrl = poster is Map ? (poster['image_url'] ?? poster['imageUrl'] ?? '') : '';
          return Container(
            width: 100,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: imgUrl.isNotEmpty
                ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))
                : const Icon(Icons.image),
          );
        },
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildStandardArticleCard(BuildContext context, NewsArticle article) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => callbacks.onArticleTap(article),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 100,
                height: 75,
                child: article.imageUrl.isNotEmpty
                    ? Image.network(
                        article.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 24),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.article, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        article.timeAgo,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const Spacer(),
                      if (article.comments > 0) ...[
                        const Icon(Icons.comment_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          '${article.comments}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
