import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/news_article.dart';
import '../../theme/app_theme.dart';

/// A horizontal run of trending stories, shown beneath a utility card.
///
/// Poll and sponsored pages carry very little content, so on a tall phone
/// most of the page was blank. This fills that space with something worth the
/// tap rather than padding — and horizontally, so the page stays one screen
/// and never competes with the vertical pager for a drag.
class SpotlightTrendingStrip extends StatelessWidget {
  const SpotlightTrendingStrip({
    super.key,
    required this.articles,
    required this.onOpen,
    this.title = 'ట్రెండింగ్',
  });

  final List<NewsArticle> articles;
  final ValueChanged<NewsArticle> onOpen;
  final String title;

  /// Enough for a 16:9 thumbnail plus two lines of Telugu headline.
  static const double stripHeight = 168;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: stripHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const ClampingScrollPhysics(),
              itemCount: articles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _TrendingCard(
                article: articles[i],
                isDark: isDark,
                onTap: () => onOpen(articles[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({
    required this.article,
    required this.isDark,
    required this.onTap,
  });

  final NewsArticle article;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Material(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: article.imageUrl.isEmpty
                    ? Container(color: Colors.black12)
                    : CachedNetworkImage(
                        imageUrl: article.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.black12),
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.black12),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
