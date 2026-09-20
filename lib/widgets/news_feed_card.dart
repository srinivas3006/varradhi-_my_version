import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/navigation/auth_guard.dart';
import '../models/news_article.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../localization/app_translations.dart';
import '../services/api_service.dart';
import 'reaction_buttons.dart';
import 'news_article_video_player.dart';
import 'watermark/article_watermark_overlay.dart';

class NewsFeedCard extends StatefulWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onComment;

  const NewsFeedCard({
    super.key,
    required this.article,
    required this.onTap,
    required this.onLike,
    required this.onBookmark,
    required this.onShare,
    required this.onComment,
  });

  @override
  State<NewsFeedCard> createState() => _NewsFeedCardState();
}

class _NewsFeedCardState extends State<NewsFeedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;

  int _currentImageIndex = 0;
  // Local optimistic reaction state (keeps UI responsive without mutating model counts)
  late Reaction _localReaction;
  late int _localLikes;
  late int _localDislikes;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 20),
    ]).animate(
        CurvedAnimation(parent: _heartController, curve: Curves.easeInOut));

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartController);

    _localReaction = widget.article.isLiked
        ? Reaction.like
        : (widget.article.isDisliked ? Reaction.dislike : Reaction.none);
    _localLikes = widget.article.likes;
    _localDislikes = widget.article.dislikes;
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    requireAuth(context, () {
      if (!widget.article.isLiked) {
        widget.onLike();
      }
    });
    _heartController.forward(from: 0.0);
  }

  void _handleBookmark() {
    HapticFeedback.lightImpact();
    requireAuth(context, widget.onBookmark);
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  void _handleComment() {
    HapticFeedback.selectionClick();
    widget.onComment();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final article = widget.article;
    final hasMultipleImages =
        article.imageUrls != null && article.imageUrls!.length > 1;
    final images = hasMultipleImages ? article.imageUrls! : [article.imageUrl];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkNavy : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(color: AppColors.borderDark, width: 0.8)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image with gradient + category tag
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onDoubleTap: _handleDoubleTap,
                  child: hasMultipleImages
                      ? PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return _buildImage(images[index]);
                          },
                        )
                      : _buildMediaPreview(),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      categoryLabel(article.category).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: AnimatedBuilder(
                      animation: AppState.instance,
                      builder: (context, _) {
                        final isSaved =
                            AppState.instance.isBookmarked(article.id);
                        return _iconPill(
                          icon:
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                          onTap: _handleBookmark,
                          active: isSaved,
                        );
                      }),
                ),
                if (hasMultipleImages)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == index
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Video Play Overlay & Duration Badge
                if (article.isVideo) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  if (article.formattedVideoDuration.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              article.formattedVideoDuration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                // Double tap heart animation
                Center(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _heartController,
                      builder: (context, child) {
                        if (_heartOpacity.value == 0.0) {
                          return const SizedBox.shrink();
                        }
                        return Opacity(
                          opacity: _heartOpacity.value,
                          child: Transform.scale(
                            scale: _heartScale.value,
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 100,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Text + meta content
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (article.isBreaking) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.2)),
                          ),
                          child: Text(tr('breaking_news').toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: isDark
                            ? AppColors.surfaceElevatedDark
                            : AppColors.chipBg,
                        child: Text(
                          article.source.isNotEmpty ? article.source[0] : '?',
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textDark),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        article.district ?? article.state ?? article.source,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('·',
                          style: TextStyle(
                              color: isDark
                                  ? AppColors.readingMetaDark
                                  : AppColors.readingMetaLight)),
                      const SizedBox(width: 6),
                      Text(
                        article.timeAgo,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.readingMetaDark
                                : AppColors.readingMetaLight),
                      ),
                      const Spacer(),
                      Icon(Icons.visibility,
                          size: 13,
                          color: isDark
                              ? AppColors.readingMetaDark
                              : AppColors.readingMetaLight),
                      const SizedBox(width: 4),
                      Text(
                        '${article.viewCount}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.readingMetaDark
                                : AppColors.readingMetaLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 17.0,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.readingTitleDark
                          : AppColors.readingTitleLight,
                      height: 1.35,
                      letterSpacing: 0.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final toShow = article.summary.trim().isNotEmpty
                            ? article.summary.trim()
                            : article.body.trim();

                        final textStyle = GoogleFonts.notoSansTelugu(
                          fontSize: 14.5,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.readingBodyLight,
                          height: 1.68,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.15,
                        );

                        final double lineHeight =
                            textStyle.fontSize! * textStyle.height!;
                        const double reservedForButton = 28.0;
                        final double availableForText =
                            (constraints.maxHeight - reservedForButton)
                                .clamp(0.0, double.infinity);
                        final int calculatedLines =
                            (availableForText / lineHeight).floor();
                        final int dynamicMaxLines = calculatedLines.clamp(2, 5);

                        final textSpan =
                            TextSpan(text: toShow, style: textStyle);
                        final textPainter = TextPainter(
                          text: textSpan,
                          textDirection: Directionality.of(context),
                          maxLines: dynamicMaxLines,
                        )..layout(maxWidth: constraints.maxWidth);

                        final bool isTruncated = textPainter.didExceedMaxLines;
                        final bool hasMoreBackend = article.hasMore ||
                            (article.body.trim().isNotEmpty &&
                                article.body.trim().length > toShow.length);
                        final bool shouldShowReadMore =
                            isTruncated || hasMoreBackend;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                toShow,
                                maxLines: dynamicMaxLines,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.start,
                                style: textStyle,
                              ),
                            ),
                            if (shouldShowReadMore) ...[
                              const SizedBox(height: 3),
                              GestureDetector(
                                onTap: _handleTap,
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppState.instance.language == 'Telugu'
                                          ? 'ఇంకా చదవండి'
                                          : 'Read More',
                                      style: const TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 12, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  Divider(
                    height: 16,
                    color: isDark ? AppColors.borderDark : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Reaction buttons (like/dislike) - mutually exclusive, optimistic update
                      ReactionButtons(
                        articleId: article.id,
                        requireLogin: true,
                        initialReaction: _localReaction,
                        initialLikeCount: _localLikes,
                        initialDislikeCount: _localDislikes,
                        onServerSync: (articleId, reaction) async {
                          // Map Reaction enum to backend string and call ApiService
                          await ApiService.instance.postArticleReaction(
                              articleId,
                              reaction == Reaction.like
                                  ? 'like'
                                  : (reaction == Reaction.dislike
                                      ? 'dislike'
                                      : 'none'));
                        },
                        onChanged: (reaction, likes, dislikes) {
                          setState(() {
                            _localReaction = reaction;
                            _localLikes = likes;
                            _localDislikes = dislikes;
                            widget.article.isLiked = reaction == Reaction.like;
                            widget.article.isDisliked = reaction == Reaction.dislike;
                            widget.article.likes = likes;
                            widget.article.dislikes = dislikes;
                          });
                        },
                      ),
                      AnimatedBuilder(
                          animation: AppState.instance,
                          builder: (context, _) {
                            final count = AppState.instance
                                .getDisplayCommentCount(
                                    article.id, article.comments);
                            return _actionButton(
                              icon: Icons.mode_comment_outlined,
                              label: _formatCount(count),
                              onTap: _handleComment,
                            );
                          }),
                      _actionButton(
                        icon: Icons.share_outlined,
                        label: _formatCount(article.shares),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onShare();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    final article = widget.article;
    final previewUrl = article.imageUrl.isNotEmpty
        ? article.imageUrl
        : (article.imageUrls != null && article.imageUrls!.isNotEmpty
            ? article.imageUrls!.first
            : '');
    final shouldShowVideoCard =
        article.isVideo && article.effectiveVideoUrl.isNotEmpty;

    if (shouldShowVideoCard) {
      return NewsArticleVideoPlayer(
        article: article,
        onDoubleTap: _handleDoubleTap,
      );
    }

    return _buildImage(previewUrl);
  }

  Widget _buildImage(String url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor =
        isDark ? AppColors.surfaceElevatedDark : AppColors.chipBg;
    final iconColor = isDark ? AppColors.iconMutedDark : AppColors.textMuted;

    if (url.isEmpty) {
      return Container(
        color: placeholderColor,
        child: Icon(Icons.image_not_supported_outlined,
            color: iconColor, size: 40),
      );
    }

    return ArticleWatermarkOverlay(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 800,
        placeholder: (context, url) => Container(color: placeholderColor),
        errorWidget: (context, url, error) => Container(
          color: placeholderColor,
          child: Icon(Icons.image_not_supported_outlined,
              color: iconColor, size: 40),
        ),
      ),
    );
  }

  Widget _iconPill(
      {required IconData icon,
      required VoidCallback onTap,
      bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 18, color: active ? AppColors.primary : Colors.white),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor =
        isDark ? AppColors.readingMetaDark : const Color(0xFF6B7280);
    final defaultTextColor =
        isDark ? AppColors.readingMetaDark : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon,
              size: 21,
              color: active ? AppColors.primary : defaultIconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: active ? AppColors.primary : defaultTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
