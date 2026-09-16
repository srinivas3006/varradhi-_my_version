import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/navigation/auth_guard.dart';
import '../../services/tts_service.dart';
import '../../screens/news_detail_screen.dart';
import '../../models/news_article.dart';
import '../../state/app_state.dart';
import '../../state/engagement_store.dart';
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

  /// Position of this card in the feed and how many cards are loaded, for
  /// the "3 of 6 Pages" marker. Zero count hides it.
  final int pageIndex;
  final int pageCount;

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
    this.pageIndex = 0,
    this.pageCount = 0,
    this.isCurrent = true,
    this.dragDelta = 0.0,
    this.dragProgress = 0.0,
    this.matchCutProgress = 0.0,
  });

  @override
  State<SpotlightNewsCard> createState() => _SpotlightNewsCardState();
}

class _SpotlightNewsCardState extends State<SpotlightNewsCard> {
  bool _isLoadingDetail = false;
  String? _detailError;
  NewsArticle? _detailArticle;
  int _detailGeneration = 0;

  /// Identity this card's engagement is filed under. Uses the article id
  /// where there is one, falling back to the slug, so the same story keyed
  /// either way lands on one entry.
  String get _engagementId =>
      widget.article.id.isNotEmpty ? widget.article.id : widget.article.slug;

  String get _engagementKey => EngagementStore.keyFor(
        kind: widget.article.contentKind,
        id: _engagementId,
      );

  /// Publishes the counts that arrived with the feed payload, and the
  /// viewer's own state as it was persisted locally, so the card renders real
  /// numbers on first paint rather than zeroes that jump a frame later.
  void _seedEngagement(NewsArticle article) {
    EngagementStore.instance.seed(
      _engagementKey,
      likeCount: article.likes,
      dislikeCount: article.dislikes,
      commentCount: article.comments,
      reaction: AppState.instance.isLiked(_engagementId) ? Reaction.like : null,
      bookmarked: AppState.instance.bookmarkedItemIds.contains(_engagementId),
    );
  }

  @override
  void initState() {
    super.initState();
    _seedEngagement(widget.article);
    // Fetch full article detail (content) using slug or id from feed item.
    final slugToFetch = widget.article.slug.isNotEmpty
        ? widget.article.slug
        : widget.article.id;
    if (slugToFetch.isNotEmpty) {
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
      final slug = widget.article.slug.isNotEmpty
          ? widget.article.slug
          : widget.article.id;
      if (slug.isNotEmpty) _fetchArticleDetail(slug);
    }
    if ((oldWidget.isCurrent && !widget.isCurrent) ||
        (widget.isCurrent && widget.dragProgress > 0.05)) {
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
        // Detail carries fresher counts than the feed summary did.
        _seedEngagement(full);
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

  /// Media aspect ratio, width : height.
  ///
  /// The image is full-bleed width and its height follows from that ratio,
  /// rather than being a share of the screen height — so it presents the same
  /// shape on every device instead of growing taller on tall phones. The
  /// content below then takes whatever is left, sized by its own title and
  /// body.
  static const double _mediaAspectRatio = 9 / 8;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder, not MediaQuery.size: the card is not the screen, and the
    // media height is derived from the card's own width.
    return LayoutBuilder(
      builder: (context, constraints) => _buildCard(context, constraints),
    );
  }

  Widget _buildCard(BuildContext context, BoxConstraints constraints) {
    final article = _detailArticle ?? widget.article;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // height = width / (w:h). Capped so a short landscape screen still
    // leaves room for the headline.
    final mediaHeight =
        (constraints.maxWidth / _mediaAspectRatio).clamp(0.0, constraints.maxHeight * 0.72);

    // Always fully painted. FlipPageView owns the transition now, so a card
    // must render at full opacity whether or not it is the settled one — the
    // neighbour it pre-builds is on screen during the swipe, and the page you
    // land on is not "current" until onPageChanged fires afterwards.
    //
    // These used to be derived from the drag values, which meant a card that
    // was not current painted at opacity 0: every story after the first was a
    // blank white screen.
    const textOpacity = 1.0;
    const imageOpacity = 1.0;
    const imageScale = 1.0;

    const headlineOffset = 0.0;
    final bodyOffset = widget.dragDelta * -0.15;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            // 1. IMAGE ZONE (full width at 9:8, cover, with parallax)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: mediaHeight,
              child: RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(
                      0, widget.dragDelta * -0.5), // Subtle image parallax
                  child: Opacity(
                    opacity: imageOpacity,
                    child: Transform.scale(
                      scale: imageScale,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          article.orderedMedia.length > 1
                              ? ArticleMediaCarousel(
                                  article: article,
                                  active: widget.isCurrent,
                                  fit: BoxFit.cover,
                                  onTap: widget.onTap)
                              : article.isVideo
                                  ? NewsArticleVideoPlayer(
                                      article: article,
                                      isCurrent: widget.isCurrent,
                                      fit: BoxFit.cover,
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
                                      child: CachedNetworkImage(
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
                                    ),
                          // Smooth Gradient Masking (Vignette) for seamless blend
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 70,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Theme.of(context)
                                        .scaffoldBackgroundColor
                                        .withValues(alpha: 0.6),
                                    Theme.of(context).scaffoldBackgroundColor,
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Multi-media Indicator (If multiple photos/videos)
                          if (article.mediaItems.length > 1)
                            Positioned(
                              bottom: 28,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library_rounded,
                                        size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${article.mediaItems.length}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Logo Watermark (Always positioned in Bottom-Right of Media Zone)
                          Positioned(
                            bottom: 28,
                            right: 16,
                            child: Opacity(
                              opacity: 0.88,
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 42,
                                height: 42,
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

            // 2. CONTENT ZONE (auto height from title + body, below the image)
            Positioned.fill(
              top: mediaHeight,
              child: Opacity(
                opacity: textOpacity,
                child: Padding(
                  // 16, not 18: the gutter sets the measure, and the column
                  // has to match for the text to break on the same words.
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                                if (widget.pageCount > 0) ...[
                                  const Spacer(),
                                  Text(
                                    '${widget.pageIndex + 1} of ${widget.pageCount} Pages',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
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
                          // Telugu needs more vertical room than Latin at the
                          // same size: vowel signs sit well above the baseline
                          // and ottulu hang below it, and Flutter lets glyphs
                          // overflow a short line box rather than clipping —
                          // so 1.25 let two headline lines collide.
                          //
                          // letterSpacing stays at 0. Negative tracking is a
                          // Latin display-type habit; on Telugu it tightens
                          // conjunct clusters that are already dense.
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.4,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Body Text with Dynamic Auto-Adjusting & Adaptive "Read More"
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
                                // Measured against the Way2News card: ~9
                                // lines of Telugu across a 342dp column at a
                                // 26.5dp line rhythm, which is 16 / 1.65.
                                final textStyle = TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.textDark
                                          .withValues(alpha: 0.88),
                                  height: 1.65,
                                  letterSpacing: 0,
                                );

                                const double reservedForButton = 44.0;

                                // Ask the engine for the real line metrics
                                // rather than assuming fontSize * height.
                                // After shaping, a Telugu line is as tall as
                                // its tallest cluster — a base consonant
                                // carrying a vowel sign above and an ottu
                                // below is taller than the nominal figure, so
                                // the estimate ran high and pushed the Read
                                // More button off its line.
                                final textPainter = TextPainter(
                                  text: TextSpan(text: toShow, style: textStyle),
                                  textDirection: Directionality.of(context),
                                )..layout(maxWidth: constraints.maxWidth);

                                final lines = textPainter.computeLineMetrics();
                                final int totalLines = lines.length;

                                /// Whole measured lines that fit in [available].
                                int linesThatFit(double available) {
                                  var used = 0.0;
                                  var fitted = 0;
                                  for (final line in lines) {
                                    if (used + line.height > available) break;
                                    used += line.height;
                                    fitted++;
                                  }
                                  return fitted;
                                }

                                final int maxPossibleLines = totalLines == 0
                                    ? 1
                                    : linesThatFit(constraints.maxHeight)
                                        .clamp(1, totalLines);

                                // Short enough to sit on screen whole: no
                                // Read More button at all.
                                final bool shouldShowReadMore =
                                    maxPossibleLines < totalLines;

                                final int dynamicMaxLines = shouldShowReadMore
                                    ? linesThatFit(constraints.maxHeight -
                                            reservedForButton)
                                        .clamp(1, totalLines)
                                    : maxPossibleLines;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      toShow,
                                      maxLines: dynamicMaxLines,
                                      overflow: TextOverflow.ellipsis,
                                      // Ragged right. Justifying a ~350px
                                      // column of Telugu stretches the gaps
                                      // around its long compound words into
                                      // visible rivers of whitespace.
                                      textAlign: TextAlign.start,
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
                                // Like. Reads from the shared EngagementStore
                                // so the count here, on the detail screen and
                                // on the feed card are the same number, and
                                // moves the instant the reader taps.
                                ValueListenableBuilder<Engagement>(
                                  valueListenable: EngagementStore.instance
                                      .listenableFor(_engagementKey),
                                  builder: (context, engagement, _) {
                                    return _buildActionIcon(
                                      icon: engagement.liked
                                          ? Icons.thumb_up_rounded
                                          : Icons.thumb_up_alt_outlined,
                                      color: engagement.liked
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                      label: _formatCount(engagement.likeCount),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        EngagementStore.instance.toggleLike(
                                          _engagementKey,
                                          _engagementId,
                                        );
                                      },
                                    );
                                  },
                                ),
                                // Dislike. Same store as like, so the two
                                // are one reaction rather than two
                                // independent flags that could both be on.
                                ValueListenableBuilder<Engagement>(
                                  valueListenable: EngagementStore.instance
                                      .listenableFor(_engagementKey),
                                  builder: (context, engagement, _) {
                                    return _buildActionIcon(
                                      icon: engagement.disliked
                                          ? Icons.thumb_down_rounded
                                          : Icons.thumb_down_alt_outlined,
                                      color: engagement.disliked
                                          ? Colors.redAccent
                                          : AppColors.textMuted,
                                      label: _formatCount(
                                          engagement.dislikeCount),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        final wasDisliked = engagement.disliked;
                                        EngagementStore.instance.toggleDislike(
                                          _engagementKey,
                                          _engagementId,
                                        );
                                        final telugu =
                                            AppState.instance.language ==
                                                'Telugu';
                                        ScaffoldMessenger.of(context)
                                          ..removeCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(wasDisliked
                                                  ? (telugu
                                                      ? 'డిస్‌లైక్ తీసివేయబడింది'
                                                      : 'Dislike removed')
                                                  : (telugu
                                                      ? 'మీ అభిప్రాయం నమోదు చేయబడింది'
                                                      : 'Feedback received')),
                                              duration:
                                                  const Duration(seconds: 1),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                      },
                                    );
                                  },
                                ),
                                // Share. A labelled pill rather than another
                                // bare icon: sharing to WhatsApp is the single
                                // most-used action on a card like this, and it
                                // should not look like one more of the four
                                // counters beside it.
                                Material(
                                  color: const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(22),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(22),
                                    onTap: widget.onShare,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 9),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.share_rounded,
                                              color: Colors.white, size: 18),
                                          SizedBox(width: 7),
                                          Text(
                                            'SHARE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Comment (Opens directly without auth gate)
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
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CommentsScreen(
                                                article: _detailArticle ??
                                                    widget.article),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                // Save / Bookmark
                                AnimatedBuilder(
                                  animation: AppState.instance,
                                  builder: (context, _) {
                                    final targetId = article.id.isNotEmpty
                                        ? article.id
                                        : article.slug;
                                    final isSaved = AppState.instance
                                            .isBookmarked(targetId) ||
                                        (widget.article.id.isNotEmpty &&
                                            AppState.instance.isBookmarked(
                                                widget.article.id));
                                    return _buildActionIcon(
                                      icon: isSaved
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      color: isSaved
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                      label: '',
                                      onTap: () async {
                                        HapticFeedback.lightImpact();
                                        final nowSaved = !isSaved;
                                        AppState.instance
                                            .toggleBookmark(targetId);
                                        if (AppState.instance.isLoggedIn) {
                                          ApiService.instance
                                              .toggleBookmark(targetId)
                                              .catchError((_) => false);
                                        }
                                        ScaffoldMessenger.of(context)
                                            .removeCurrentSnackBar();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(nowSaved
                                                ? (AppState.instance.language ==
                                                        'Telugu'
                                                    ? 'వార్త సేవ్ చేయబడింది'
                                                    : 'Article saved to bookmarks')
                                                : (AppState.instance.language ==
                                                        'Telugu'
                                                    ? 'బుక్‌మార్క్ తీసివేయబడింది'
                                                    : 'Bookmark removed')),
                                            duration: const Duration(
                                                milliseconds: 1200),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
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
