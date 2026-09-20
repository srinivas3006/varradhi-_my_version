import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/navigation/auth_guard.dart';
import '../../services/tts_service.dart';
import '../../screens/news_detail_screen.dart';
import '../../models/news_article.dart';
import '../../state/app_state.dart';
import '../../utils/share_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/comments_screen.dart';
import '../../services/api_service.dart';
import '../../repositories/news_article_repository.dart';
import '../news_article_video_player.dart';
import '../article_media_carousel.dart';
import '../../spotlight/spotlight_media_coordinator.dart';
import '../watermark/article_watermark_overlay.dart';
import '../watermark/watermark_banner.dart';

class SpotlightNewsCard extends StatefulWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onClose;

  // Parallax properties
  /// Position in the feed and how many cards are loaded, for the
  /// "3 of 12 Pages" marker. Zero count hides it.
  final int pageIndex;
  final int pageCount;

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

  bool _downloadingPoster = false;

  /// Guards against a double-tap firing two toggles that cancel out.
  bool _bookmarkInFlight = false;

  /// Generates the branded PNG poster and hands it to the share sheet, where
  /// both platforms expose "save to device" next to every social app.
  Future<void> _downloadPoster(NewsArticle article) async {
    setState(() => _downloadingPoster = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ShareService.downloadPoster(article);
      if (!mounted) return;
      final telugu = AppState.instance.language == 'Telugu';
      final String message;
      switch (result) {
        case ShareService.downloadSaved:
          message = telugu
              ? 'గ్యాలరీలో సేవ్ చేయబడింది'
              : 'Saved to your gallery';
          break;
        case ShareService.downloadPermissionDenied:
          message = telugu
              ? 'సేవ్ చేయడానికి గ్యాలరీ అనుమతి కావాలి'
              : 'Gallery permission is needed to save';
          break;
        default:
          message = telugu
              ? 'పోస్టర్ సేవ్ చేయడం విఫలమైంది'
              : 'Could not save the poster';
      }
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
    } finally {
      if (mounted) setState(() => _downloadingPoster = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Fetch full article detail (content) using slug or id from feed item.
    final slugToFetch = widget.article.slug.isNotEmpty
        ? widget.article.slug
        : widget.article.id;
    if (!widget.article.isUgc && slugToFetch.isNotEmpty) {
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
      if (!widget.article.isUgc && slug.isNotEmpty) {
        _fetchArticleDetail(slug);
      }
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
    if (widget.article.isUgc) return;
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // The card's chrome — headline, meta row, action bar — is laid out at
    // fixed sizes against a measured height budget. Android's accessibility
    // scale multiplies every one of those without the budget being
    // recomputed, so at 150% the headline and meta row overflow before the
    // body is even measured.
    //
    // Capped rather than ignored: scaling up to 1.3x still reaches the
    // reader, and the body size derived below already grows with the room
    // available, so large-text users are not left with phone-sized copy.
    final requestedScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3);
    // One fixed aspect, so the same photo is cropped identically on every
    // device. The previous rule asked for 16:10 and then clamped it to
    // 38–40% of viewport height — and the clamp won on every phone, so the
    // image ran from 1.48:1 on a compact screen down to 0.88:1 on a tall
    // one. It was never 16:10 anywhere except a tablet.
    //
    // Height now follows width. A taller screen gets no more image; it gets
    // more room for the story, which the body below turns into larger type
    // rather than more lines.
    const mediaAspect = 16 / 10;
    final mediaHeight = (screenWidth / mediaAspect)
        // Still bounded, but only to stop a very wide screen handing the
        // image half the card.
        .clamp(0.0, screenHeight * 0.45);

    // Always fully painted. The feed is a FlipPageView now, which owns the
    // transition and passes no drag values — deriving opacity from them left
    // every card but the settled one at opacity 0, i.e. a blank white screen
    // for every story after the first.
    const textOpacity = 1.0;
    const imageOpacity = 1.0;
    const imageScale = 1.0;

    final headlineOffset = widget.dragDelta * 1.0;
    final bodyOffset = widget.dragDelta * 0.85;

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: requestedScale,
      child: GestureDetector(
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
              // Clipped to the media slot. A Transform paints outside its
              // bounds, and an embedded player sizes itself from its own
              // content — without this, either can spill over the chrome
              // above the card.
              child: ClipRect(
                child: RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(
                      0, widget.dragDelta * 0.5), // Subtle image parallax
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
                                          SnackBar(
                                            content: Text(AppState.instance.language == 'Telugu'
                                                ? 'స్టోరీని లైక్ చేసారు ❤️'
                                                : 'Liked story ❤️'),
                                            duration: const Duration(milliseconds: 900),
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
                                          SnackBar(
                                            content: Text(AppState.instance.language == 'Telugu'
                                                ? 'స్టోరీని లైక్ చేసారు ❤️'
                                                : 'Liked story ❤️'),
                                            duration: const Duration(milliseconds: 900),
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
                          // Non-intrusive Vaaradhi Watermark (Bottom-Right Logo + Left Vertical Text)
                          const Positioned.fill(
                            child: ArticleWatermarkOverlay(),
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
                opacity: textOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Masthead band, sitting on the seam between the media
                      // and the story.
                      const WatermarkBanner(height: 26),

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
                                                  ? (AppState.instance.language == 'Telugu' ? 'లోడ్ అవుతోంది...' : 'Loading...')
                                                  : (isPlaying
                                                      ? (AppState.instance.language == 'Telugu' ? 'వింటున్నారు' : 'Playing')
                                                      : (AppState.instance.language == 'Telugu' ? 'వినండి' : 'Listen')),
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

                            // Right: Breaking / UGC / Location / Time
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
                                    child: const Text('బ్రేకింగ్',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (article.isUgc) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.amber.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_pin_circle_rounded,
                                            size: 11, color: Colors.amber),
                                        const SizedBox(width: 3),
                                        Text(
                                          article.authorName.isNotEmpty
                                              ? article.authorName
                                              : 'సిటిజెన్ రిపోర్ట్',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.amber,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
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
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.readingMetaDark
                                          : AppColors.readingMetaLight,
                                      fontWeight: FontWeight.w400),
                                ),
                                if (widget.pageCount > 0) ...[
                                  const Spacer(),
                                  Text(
                                    '${widget.pageIndex + 1} of ${widget.pageCount} Pages',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? AppColors.readingMetaDark
                                            : AppColors.readingMetaLight,
                                        fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Headline with Noto Sans Telugu shaping
                      Transform.translate(
                        offset: Offset(0, headlineOffset),
                        child: Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansTelugu(
                            fontSize: 20.0,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.readingTitleDark
                                : const Color(0xFF212121),
                            height: 1.4,
                            letterSpacing: 0.0,
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
                                color: isDark ? Colors.white60 : Colors.black54),
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
                      const SizedBox(height: 10),

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
                                    ? (AppState.instance.language == 'Telugu'
                                        ? 'కంటెంట్‌ను లోడ్ చేయడంలో విఫలమైంది.'
                                        : 'Failed to load content.')
                                    : (AppState.instance.language == 'Telugu'
                                        ? 'సమాచారం అందుబాటులో లేదు.'
                                        : 'No content available.'),
                                style: TextStyle(
                                    fontSize: 15,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54),
                              );
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                // Type scales with the room available, so
                                // the story is not set at phone size on a
                                // tablet. A fixed 16pt looked cramped on a
                                // compact screen and undersized on a tall
                                // one.
                                //
                                // It scales gently and stops: holding the
                                // line count itself constant across a
                                // 640–1080px range would need 44pt body text
                                // on the tallest device, so taller screens
                                // still show somewhat more text — they just
                                // show it at a readable size.
                                const double bodyLineHeight = 1.65;
                                const double referenceBody = 214.0; // compact
                                const double referenceFont = 15.0;

                                final fitted = referenceFont *
                                    (constraints.maxHeight / referenceBody)
                                        .clamp(1.0, 1.30);

                                // The reader's own size setting stays a
                                // preference, applied as a ratio around the
                                // 19pt default rather than an absolute.
                                final preference =
                                    AppState.instance.readingFontSize > 0
                                        ? AppState.instance.readingFontSize /
                                            19.0
                                        : 1.0;

                                // Bounded so neither a tiny nor a huge screen
                                // produces type nobody can read.
                                final effectiveFontSize =
                                    (fitted * preference).clamp(14.0, 21.0);

                                final textStyle = GoogleFonts.notoSansTelugu(
                                  fontSize: effectiveFontSize,
                                  color: isDark
                                      ? AppColors.readingBodyDark
                                      : const Color(0xFF424242),
                                  height: bodyLineHeight,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                );

                                const double reservedForButton = 44.0;

                                // Ask the engine for the real line metrics
                                // rather than assuming fontSize * height.
                                // After shaping, a Telugu line is as tall as
                                // its tallest cluster — a base consonant with
                                // a vowel sign above and an ottu below is
                                // taller than the nominal figure, so the
                                // estimate ran high and pushed the Read More
                                // button off its line.
                                final textPainter = TextPainter(
                                  text:
                                      TextSpan(text: toShow, style: textStyle),
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
                                // Like
                                AnimatedBuilder(
                                  animation: AppState.instance,
                                  builder: (context, _) {
                                    final targetId = article.id.isNotEmpty
                                        ? article.id
                                        : article.slug;
                                    final isLiked = article.isLiked ||
                                        AppState.instance.isLiked(targetId) ||
                                        (article.id.isNotEmpty &&
                                            AppState.instance.isLiked(article.id));
                                    final isDisliked = article.isDisliked ||
                                        AppState.instance.isDisliked(targetId) ||
                                        (article.id.isNotEmpty &&
                                            AppState.instance.isDisliked(article.id));
                                    return _buildActionIcon(
                                      icon: isLiked
                                          ? Icons.thumb_up_rounded
                                          : Icons.thumb_up_alt_outlined,
                                      color: isLiked
                                          ? AppColors.primary
                                          : (isDark
                                              ? AppColors.readingMetaDark
                                              : const Color(0xFF6B7280)),
                                      label: _formatCount(article.likes),
                                      onTap: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        HapticFeedback.lightImpact();
                                        final wasLiked = isLiked;
                                        final wasDisliked = isDisliked;
                                        final nextReaction = wasLiked ? 'none' : 'like';

                                        // 1. Optimistic local update
                                        AppState.instance.setReaction(targetId, nextReaction);
                                        final prevLikes = article.likes;
                                        final prevDislikes = article.dislikes;
                                        setState(() {
                                          article.isLiked = (nextReaction == 'like');
                                          if (nextReaction == 'like') {
                                            article.likes = wasLiked ? prevLikes : prevLikes + 1;
                                            if (wasDisliked) {
                                              article.isDisliked = false;
                                              article.dislikes = prevDislikes > 0 ? prevDislikes - 1 : 0;
                                            }
                                          } else {
                                            article.likes = prevLikes > 0 ? prevLikes - 1 : 0;
                                          }
                                        });

                                        // 2. Sync to backend (guest or authenticated)
                                        try {
                                          final res = await ApiService.instance.postArticleReaction(
                                            targetId,
                                            nextReaction,
                                          );
                                          if (mounted) {
                                            setState(() {
                                              final l = res['like_count'] ?? res['likes_count'] ?? res['likes'];
                                              if (l != null) {
                                                article.likes = (l as num).toInt();
                                              }
                                              final d = res['dislike_count'] ?? res['dislikes_count'] ?? res['dislikes'];
                                              if (d != null) {
                                                article.dislikes = (d as num).toInt();
                                              }
                                            });
                                          }
                                        } catch (e) {
                                          debugPrint('[SpotlightNewsCard] Like sync failed: $e');
                                          if (mounted) {
                                            AppState.instance.setReaction(
                                                targetId,
                                                wasLiked
                                                    ? 'like'
                                                    : (wasDisliked ? 'dislike' : 'none'));
                                            setState(() {
                                              article.isLiked = wasLiked;
                                              article.likes = prevLikes;
                                              article.isDisliked = wasDisliked;
                                              article.dislikes = prevDislikes;
                                            });
                                            messenger.removeCurrentSnackBar();
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(AppState.instance.language == 'Telugu'
                                                    ? 'స్పందనను నమోదు చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.'
                                                    : 'Could not sync reaction. Please try again.'),
                                                duration: const Duration(seconds: 2),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    );
                                  },
                                ),
                                // Dislike
                                AnimatedBuilder(
                                  animation: AppState.instance,
                                  builder: (context, _) {
                                    final targetId = article.id.isNotEmpty
                                        ? article.id
                                        : article.slug;
                                    final isDisliked = article.isDisliked ||
                                        AppState.instance.isDisliked(targetId) ||
                                        (article.id.isNotEmpty &&
                                            AppState.instance.isDisliked(article.id));
                                    final isLiked = article.isLiked ||
                                        AppState.instance.isLiked(targetId) ||
                                        (article.id.isNotEmpty &&
                                            AppState.instance.isLiked(article.id));
                                    return _buildActionIcon(
                                      icon: isDisliked
                                          ? Icons.thumb_down_rounded
                                          : Icons.thumb_down_alt_outlined,
                                      color: isDisliked
                                          ? Colors.redAccent
                                          : (isDark
                                              ? AppColors.readingMetaDark
                                              : const Color(0xFF6B7280)),
                                      label: _formatCount(article.dislikes),
                                      onTap: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        HapticFeedback.lightImpact();
                                        final wasDisliked = isDisliked;
                                        final wasLiked = isLiked;
                                        final nextReaction = wasDisliked ? 'none' : 'dislike';

                                        // 1. Optimistic local update
                                        AppState.instance.setReaction(targetId, nextReaction);
                                        final prevLikes = article.likes;
                                        final prevDislikes = article.dislikes;
                                        setState(() {
                                          article.isDisliked = (nextReaction == 'dislike');
                                          if (nextReaction == 'dislike') {
                                            article.dislikes = wasDisliked ? prevDislikes : prevDislikes + 1;
                                            if (wasLiked) {
                                              article.isLiked = false;
                                              article.likes = prevLikes > 0 ? prevLikes - 1 : 0;
                                            }
                                          } else {
                                            article.dislikes = prevDislikes > 0 ? prevDislikes - 1 : 0;
                                          }
                                        });

                                        // 2. Sync to backend (guest or authenticated)
                                        try {
                                          final res = await ApiService.instance.postArticleReaction(
                                            targetId,
                                            nextReaction,
                                          );
                                          if (mounted) {
                                            setState(() {
                                              final l = res['like_count'] ?? res['likes_count'] ?? res['likes'];
                                              if (l != null) {
                                                article.likes = (l as num).toInt();
                                              }
                                              final d = res['dislike_count'] ?? res['dislikes_count'] ?? res['dislikes'];
                                              if (d != null) {
                                                article.dislikes = (d as num).toInt();
                                              }
                                            });
                                          }
                                        } catch (e) {
                                          debugPrint('[SpotlightNewsCard] Dislike sync failed: $e');
                                          if (mounted) {
                                            AppState.instance.setReaction(
                                                targetId,
                                                wasDisliked
                                                    ? 'dislike'
                                                    : (wasLiked ? 'like' : 'none'));
                                            setState(() {
                                              article.isDisliked = wasDisliked;
                                              article.dislikes = prevDislikes;
                                              article.isLiked = wasLiked;
                                              article.likes = prevLikes;
                                            });
                                            messenger.removeCurrentSnackBar();
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(AppState.instance.language == 'Telugu'
                                                    ? 'స్పందనను నమోదు చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.'
                                                    : 'Could not sync reaction. Please try again.'),
                                                duration: const Duration(seconds: 2),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                            return;
                                          }
                                        }

                                        if (mounted) {
                                          messenger.removeCurrentSnackBar();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(nextReaction == 'dislike'
                                                  ? (AppState.instance.language == 'Telugu'
                                                      ? 'మీ అభిప్రాయం నమోదు చేయబడింది'
                                                      : 'Feedback received')
                                                  : (AppState.instance.language == 'Telugu'
                                                      ? 'డిస్‌లైక్ తీసివేయబడింది'
                                                      : 'Dislike removed')),
                                              duration: const Duration(seconds: 1),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                                // Download poster. Only offered where a
                                // poster can actually be generated — without
                                // an image there is nothing to put text on.
                                if (ShareService.canGeneratePoster(article))
                                  _buildActionIcon(
                                    icon: _downloadingPoster
                                        ? Icons.hourglass_top_rounded
                                        : Icons.download_rounded,
                                    color: isDark
                                        ? AppColors.readingMetaDark
                                        : const Color(0xFF6B7280),
                                    label: '',
                                    onTap: () {
                                      if (_downloadingPoster) return;
                                      _downloadPoster(article);
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
                                // Comment (Opens directly without auth gate)
                                AnimatedBuilder(
                                  animation: AppState.instance,
                                  builder: (context, _) {
                                    final count = AppState.instance
                                        .getDisplayCommentCount(
                                            article.id, article.comments);
                                    return _buildActionIcon(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      color: isDark
                                          ? AppColors.readingMetaDark
                                          : const Color(0xFF6B7280),
                                      label: _formatCount(count),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        // Sheet, not a pushed page: the post
                                        // stays on screen behind it.
                                        CommentsScreen.showSheet(
                                          context,
                                          _detailArticle ?? widget.article,
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
                                    // article.isBookmarked is the reader's
                                    // saved state from the backend; the local
                                    // set is the optimistic overlay. Reading
                                    // only the set meant a bookmark made in
                                    // an earlier session never showed.
                                    final isSaved = article.isBookmarked ||
                                        AppState.instance
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
                                          : (isDark
                                              ? AppColors.readingMetaDark
                                              : const Color(0xFF6B7280)),
                                      label: '',
                                      onTap: () => _handleBookmarkTap(
                                        targetId: targetId,
                                        isSaved: isSaved,
                                        article: article,
                                      ),
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
      ),
    );
  }

  void _handleBookmarkTap({
    required String targetId,
    required bool isSaved,
    required NewsArticle article,
  }) {
    if (_bookmarkInFlight) return;
    if (!AppState.instance.isLoggedIn) {
      requireAuth(context, () {
        if (!mounted) return;
        _executeBookmarkToggle(
          targetId: targetId,
          currentSaved: isSaved,
          article: article,
        );
      });
      return;
    }
    _executeBookmarkToggle(
      targetId: targetId,
      currentSaved: isSaved,
      article: article,
    );
  }

  Future<void> _executeBookmarkToggle({
    required String targetId,
    required bool currentSaved,
    required NewsArticle article,
  }) async {
    if (_bookmarkInFlight) return;
    _bookmarkInFlight = true;
    HapticFeedback.lightImpact();

    final messenger = ScaffoldMessenger.of(context);
    final telugu = AppState.instance.language == 'Telugu';
    final nowSaved = !currentSaved;

    // Optimistic: flip both the model field and the local set so they cannot disagree.
    AppState.instance.setBookmarked(targetId, nowSaved);
    if (widget.article.id.isNotEmpty && widget.article.id != targetId) {
      AppState.instance.setBookmarked(widget.article.id, nowSaved);
    }
    if (mounted) {
      setState(() => article.isBookmarked = nowSaved);
    }

    var failed = false;
    try {
      final success = await ApiService.instance.toggleBookmark(targetId);
      if (!success) {
        failed = true;
      }
    } catch (e) {
      debugPrint('[SpotlightNewsCard] Bookmark sync failed: $e');
      failed = true;
    }

    if (failed) {
      // Roll back rather than claim a save the server never made.
      AppState.instance.setBookmarked(targetId, currentSaved);
      if (widget.article.id.isNotEmpty && widget.article.id != targetId) {
        AppState.instance.setBookmarked(widget.article.id, currentSaved);
      }
      if (mounted) {
        setState(() => article.isBookmarked = currentSaved);
      }
    }

    _bookmarkInFlight = false;
    if (!mounted) return;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(failed
            ? (telugu
                ? 'బుక్‌మార్క్ సేవ్ చేయలేకపోయాము.'
                : 'Could not save the bookmark.')
            : nowSaved
                ? (telugu
                    ? 'వార్త సేవ్ చేయబడింది'
                    : 'Article saved to bookmarks')
                : (telugu
                    ? 'బుక్‌మార్క్ తీసివేయబడింది'
                    : 'Bookmark removed')),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
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