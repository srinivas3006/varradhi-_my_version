import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/navigation/auth_guard.dart';
import '../../services/tts_service.dart';
import '../../screens/news_detail_screen.dart';
import '../../models/news_article.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../screens/comments_screen.dart';
import '../../services/api_service.dart';
import '../../repositories/news_article_repository.dart';
import '../news_article_video_player.dart';
import '../article_media_carousel.dart';
import '../../spotlight/spotlight_media_coordinator.dart';

class SpotlightNewsCard extends StatefulWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onClose;

  // Parallax properties
  final bool isCurrent;
  final double dragDelta;
  final double dragProgress;
  final double matchCutProgress;

  const SpotlightNewsCard({
    super.key,
    required this.article,
    required this.onTap,
    required this.onShare,
    required this.onClose,
    this.isCurrent = true,
    this.dragDelta = 0.0,
    this.dragProgress = 0.0,
    this.matchCutProgress = 0.0,
  });

  @override
  State<SpotlightNewsCard> createState() => _SpotlightNewsCardState();
}

class _SpotlightNewsCardState extends State<SpotlightNewsCard> {
  bool _isDisliked = false;
  bool _isLoadingDetail = false;
  String? _detailError;
  NewsArticle? _detailArticle;
  int _detailGeneration = 0;

  @override
  void initState() {
    super.initState();
    // Fetch full article detail (content) using slug or id from feed item.
    final slugToFetch = widget.article.slug.isNotEmpty
        ? widget.article.slug
        : widget.article.id;
    if (slugToFetch.isNotEmpty && widget.article.contentKind == 'article') {
      _fetchArticleDetail(slugToFetch);
    }
  }

  @override
  void didUpdateWidget(covariant SpotlightNewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id ||
        oldWidget.article.slug != widget.article.slug) {
      ++_detailGeneration;
      _detailArticle = null;
      _isLoadingDetail = false;
      _detailError = null;
      if (widget.article.contentKind == 'article') {
        final slug = widget.article.slug.isNotEmpty
            ? widget.article.slug
            : widget.article.id;
        if (slug.isNotEmpty) _fetchArticleDetail(slug);
      }
    }
    if (oldWidget.isCurrent && !widget.isCurrent) {
      final articleId = widget.article.id.isNotEmpty
          ? widget.article.id
          : widget.article.slug;
      if (AppTtsService.instance.isArticlePlaying(articleId)) {
        AppTtsService.instance.stop();
        SpotlightMediaCoordinator.instance.notifyTtsStopped();
      }
    }
  }

  @override
  void dispose() {
    final articleId =
        widget.article.id.isNotEmpty ? widget.article.id : widget.article.slug;
    if (AppTtsService.instance.isArticlePlaying(articleId)) {
      AppTtsService.instance.stop();
      SpotlightMediaCoordinator.instance.notifyTtsStopped();
    }
    super.dispose();
  }

  void _navigateToDetail() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(
          article: _detailArticle ?? widget.article,
          slug: widget.article.slug.isNotEmpty
              ? widget.article.slug
              : widget.article.id,
        ),
      ),
    );
  }

  Future<void> _fetchArticleDetail(String slug) async {
    final generation = ++_detailGeneration;

    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      debugPrint('Spotlight: fetching detail for slug: $slug');
      final full = await NewsArticleRepository.instance.getDetail(slug);
      debugPrint(
          'Spotlight: detail fetched for $slug. Content length: ${full.body.length}');
      if (mounted && generation == _detailGeneration) {
        setState(() {
          _detailArticle = full;
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      debugPrint('Spotlight: failed to fetch detail for $slug: $e');
      if (mounted && generation == _detailGeneration) {
        setState(() {
          _detailError = e.toString();
          _isLoadingDetail = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = _detailArticle ?? widget.article;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaHeight = MediaQuery.of(context).size.height * 0.38;

    // Parallax Animation Values
    final textOpacity =
        widget.isCurrent ? (1.0 - widget.dragProgress) : widget.dragProgress;
    final imageOpacity = widget.isCurrent
        ? (1.0 - widget.matchCutProgress)
        : widget.matchCutProgress;
    final imageScale =
        widget.isCurrent ? 1.0 : (0.95 + 0.05 * widget.matchCutProgress);

    final headlineOffset = widget.dragDelta * 1.0;
    final bodyOffset = widget.dragDelta * 0.85;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            // 1. IMAGE ZONE (Top 38% with Parallax)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: mediaHeight,
              child: RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(
                      0, widget.dragDelta * 0.5), // Subtle image parallax
                  child: Opacity(
                    opacity: imageOpacity,
                    child: Transform.scale(
                      scale: imageScale,
                      child: article.mediaItems.isNotEmpty ||
                              article.orderedMedia.length > 1
                          ? ArticleMediaCarousel(
                              article: article,
                              active: widget.isCurrent,
                              onTap: widget.onTap)
                          : article.isVideo
                              ? NewsArticleVideoPlayer(
                                  article: article,
                                  isCurrent: widget.isCurrent,
                                  onDoubleTap: () {
                                    HapticFeedback.mediumImpact();
                                    if (!AppState.instance.isLoggedIn) {
                                      requireAuth(context, () {});
                                      return;
                                    }
                                    if (!AppState.instance.likedItemIds
                                        .contains(article.id)) {
                                      AppState.instance.toggleLike(article.id);
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Liked story ❤️'),
                                        duration: Duration(milliseconds: 900),
                                      ),
                                    );
                                  },
                                )
                              : GestureDetector(
                                  onTap: widget.onTap,
                                  onDoubleTap: () {
                                    HapticFeedback.mediumImpact();
                                    if (!AppState.instance.isLoggedIn) {
                                      requireAuth(context, () {});
                                      return;
                                    }
                                    if (!AppState.instance.likedItemIds
                                        .contains(article.id)) {
                                      AppState.instance.toggleLike(article.id);
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Liked story ❤️'),
                                        duration: Duration(milliseconds: 900),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl:
                                            (article.mediaItems.isNotEmpty &&
                                                    article.mediaItems.first.url
                                                        .isNotEmpty)
                                                ? article.mediaItems.first.url
                                                : article.imageUrl,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 480,
                                        memCacheHeight: 480,
                                        maxWidthDiskCache: 800,
                                        maxHeightDiskCache: 800,
                                        placeholder: (context, url) =>
                                            Container(color: AppColors.chipBg),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          color: AppColors.chipBg,
                                          child: const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: AppColors.textMuted),
                                        ),
                                      ),
                                      // Smooth Gradient Masking (Vignette) for seamless blend
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Theme.of(context)
                                                  .scaffoldBackgroundColor
                                                  .withValues(alpha: 0.5),
                                              Theme.of(context)
                                                  .scaffoldBackgroundColor,
                                            ],
                                            stops: const [0.6, 0.9, 1.0],
                                          ),
                                        ),
                                      ),
                                      // Multi-media Indicator (If multiple photos/videos)
                                      if (article.mediaItems.length > 1)
                                        Positioned(
                                          bottom: 32,
                                          left: 16,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                    Icons.photo_library_rounded,
                                                    size: 12,
                                                    color: Colors.white),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${article.mediaItems.length}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Logo Watermark (Bottom-Right of Image)
                                      Positioned(
                                        bottom: 32,
                                        right: 16,
                                        child: Opacity(
                                          opacity: 0.8,
                                          child: Image.asset(
                                            'assets/images/logo.png',
                                            width: 38,
                                            height: 38,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. CONTENT ZONE (Overlaps image slightly)
            Positioned.fill(
              top: mediaHeight - 24,
              child: Opacity(
                opacity: textOpacity.clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meta Row: Audio/Listen + Time (Utility)
                      Transform.translate(
                        offset: Offset(0, bodyOffset),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Audio Chip (Powered by AppTtsService)
                            AnimatedBuilder(
                              animation: AppTtsService.instance,
                              builder: (context, _) {
                                final articleId = widget.article.id.isNotEmpty
                                    ? widget.article.id
                                    : widget.article.slug;
                                final isPlaying = AppTtsService.instance
                                    .isArticlePlaying(articleId);
                                final isLoading = AppTtsService.instance
                                    .isArticleLoading(articleId);

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        if (isPlaying) {
                                          SpotlightMediaCoordinator.instance
                                              .notifyTtsStopped();
                                        } else {
                                          SpotlightMediaCoordinator.instance
                                              .notifyTtsStarted(articleId);
                                        }
                                        AppTtsService.instance.toggleArticleTts(
                                            _detailArticle ?? widget.article);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isPlaying
                                              ? AppColors.primary
                                              : (isDark
                                                  ? Colors.white10
                                                  : Colors.black
                                                      .withValues(alpha: 0.05)),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isPlaying
                                                ? AppColors.primary
                                                : (isDark
                                                    ? Colors.white24
                                                    : Colors.black12),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isLoading)
                                              const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            AppColors.primary),
                                              )
                                            else
                                              Icon(
                                                isPlaying
                                                    ? Icons.stop_circle_rounded
                                                    : Icons.volume_up_rounded,
                                                size: 16,
                                                color: isPlaying
                                                    ? Colors.white
                                                    : (isDark
                                                        ? Colors.white
                                                        : Colors.black87),
                                              ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isLoading
                                                  ? 'Loading...'
                                                  : (isPlaying
                                                      ? 'Playing'
                                                      : 'Listen'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isPlaying
                                                    ? Colors.white
                                                    : (isDark
                                                        ? Colors.white
                                                        : Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isPlaying) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          AppTtsService.instance.cycleSpeed();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            AppTtsService
                                                .instance.playbackSpeedText,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),

                            // Right: Breaking / Location / Time
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (article.isBreaking) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3B30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('BREAKING',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (article.village != null &&
                                    article.village!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 10, color: AppColors.primary),
                                        const SizedBox(width: 2),
                                        Text(
                                          article.village!,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ] else if (article.district != null &&
                                    article.district!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 10, color: AppColors.primary),
                                        const SizedBox(width: 2),
                                        Text(
                                          article.district!,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  article.timeAgo,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Headline
                      Transform.translate(
                        offset: Offset(0, headlineOffset),
                        child: Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.25,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      if (article.authorName.isNotEmpty &&
                          article.authorName != 'VARADHI Desk') ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_pin_rounded,
                                size: 13,
                                color:
                                    isDark ? Colors.white60 : Colors.black54),
                            const SizedBox(width: 4),
                            Text(
                              article.authorName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Body Text with Dynamic Truncation & Adaptive "Read More"
                      Expanded(
                        child: Transform.translate(
                          offset: Offset(0, bodyOffset),
                          child: Builder(builder: (context) {
                            final content = _detailArticle?.body.trim() ?? '';
                            final toShow = content.isNotEmpty
                                ? content
                                : (article.body.trim().isNotEmpty
                                    ? article.body.trim()
                                    : article.summary.trim());

                            if (_isLoadingDetail && toShow.isEmpty) {
                              return const Center(
                                child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            }

                            if (toShow.isEmpty) {
                              return Text(
                                _detailError != null
                                    ? 'Failed to load content.'
                                    : 'No content available.',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54),
                              );
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final textStyle = TextStyle(
                                  fontSize: 15.5,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.textDark
                                          .withValues(alpha: 0.85),
                                  height: 1.5,
                                  letterSpacing: 0.1,
                                );

                                // Line height based on font size and height factor (~23.25px)
                                final double lineHeight =
                                    textStyle.fontSize! * textStyle.height!;
                                const double reservedForButton = 46.0;

                                // Adapt maximum lines dynamically to available height to prevent any overflow
                                final double availableForText =
                                    (constraints.maxHeight - reservedForButton)
                                        .clamp(0.0, double.infinity);
                                final int calculatedLines =
                                    (availableForText / lineHeight).floor();
                                // Clean viewable text lines: standard 5 lines, adapted to screen size
                                final int dynamicMaxLines =
                                    calculatedLines.clamp(3, 5);

                                // Measure whether content actually exceeds dynamicMaxLines on this screen
                                final textSpan =
                                    TextSpan(text: toShow, style: textStyle);
                                final textPainter = TextPainter(
                                  text: textSpan,
                                  textDirection: Directionality.of(context),
                                  maxLines: dynamicMaxLines,
                                )..layout(maxWidth: constraints.maxWidth);

                                final bool isTruncated =
                                    textPainter.didExceedMaxLines;
                                final bool hasMoreBackend = article.hasMore ||
                                    (_detailArticle != null &&
                                        _detailArticle!.body.length >
                                            toShow.length);
                                final bool shouldShowReadMore =
                                    isTruncated || hasMoreBackend;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      toShow,
                                      maxLines: dynamicMaxLines,
                                      overflow: TextOverflow.ellipsis,
                                      style: textStyle,
                                    ),
                                    if (shouldShowReadMore) ...[
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: _navigateToDetail,
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                AppState.instance.language ==
                                                        'Telugu'
                                                    ? 'ఇంకా చదవండి'
                                                    : 'Read More',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 14,
                                                  color: AppColors.primary),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            );
                          }),
                        ),
                      ),
                      // In-Article Action Bar (Like, Dislike, Share, Comment, Save)
                      Transform.translate(
                        offset: Offset(0, bodyOffset),
                        child: RepaintBoundary(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  MediaQuery.of(context).padding.bottom + 16,
                              top: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Like
                                AnimatedBuilder(
                                  animation: AppState.instance,
                                  builder: (context, _) {
                                    final isLiked = AppState
                                        .instance.likedItemIds
                                        .contains(article.id);
                                    return _buildActionIcon(
                                      icon: isLiked
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_alt_outlined,
                                      color: isLiked
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                      label: _formatCount(
                                          article.likes + (isLiked ? 1 : 0)),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        requireAuth(
                                          context,
                                          () => AppState.instance
                                              .toggleLike(article.id),
                                        );
                                      },
                                    );
                                  },
                                ),
                                // Dislike
                                _buildActionIcon(
                                  icon: Icons.thumb_down_alt_outlined,
                                  color: _isDisliked
                                      ? Colors.red
                                      : AppColors.textMuted,
                                  label: '',
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    requireAuth(context, () {
                                      setState(
                                          () => _isDisliked = !_isDisliked);
                                      if (_isDisliked) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Feedback received'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    });
                                  },
                                ),
                                // Share (Center, Prominent)
                                GestureDetector(
                                  onTap: widget.onShare,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.share_rounded,
                                        color: AppColors.primary, size: 24),
                                  ),
                                ),
                                // Comment
                                AnimatedBuilder(
                                  animation: AppState.instance,
                                  builder: (context, _) {
                                    final count = AppState.instance
                                        .getDisplayCommentCount(
                                            article.id, article.comments);
                                    return _buildActionIcon(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      color: AppColors.textMuted,
                                      label: _formatCount(count),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        requireAuth(
                                          context,
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => CommentsScreen(
                                                    article: article)),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                // Save
                                AnimatedBuilder(
                                  animation: AppState.instance,
                                  builder: (context, _) {
                                    final isSaved = AppState.instance
                                        .isBookmarked(widget.article.id);
                                    return _buildActionIcon(
                                      icon: isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border_rounded,
                                      color: isSaved
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                      label: '',
                                      onTap: () async {
                                        HapticFeedback.lightImpact();
                                        requireAuth(context, () {
                                          AppState.instance.toggleBookmark(
                                              widget.article.id);
                                          ApiService.instance.toggleBookmark(
                                              widget.article.id);
                                        });
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count <= 0) return '';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
