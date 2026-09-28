import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/navigation/auth_guard.dart';
import '../../services/tts_service.dart';
import '../../screens/news_detail_screen.dart';
import '../../models/news_article.dart';
import '../../state/app_state.dart';
import '../../utils/share_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/comments_screen.dart';
import '../../repositories/news_article_repository.dart';
import '../news_article_video_player.dart';
import '../article_media_carousel.dart';
import '../smart_fit_image.dart';
import '../../spotlight/spotlight_media_coordinator.dart';
import 'story_options_sheet.dart';
import '../../services/content_engagement_service.dart';

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
  bool _posterDownloaded = false;

  /// Guards against a double-tap firing two toggles that cancel out.
  bool _bookmarkInFlight = false;

  /// Generates the branded poster and writes it to the gallery.
  Future<void> _downloadPoster(NewsArticle article) async {
    if (_downloadingPoster || _posterDownloaded) return;
    HapticFeedback.lightImpact();
    setState(() => _downloadingPoster = true);
    try {
      final result = await ShareService.downloadPoster(article);
      if (!mounted) return;
      final telugu = AppState.instance.language == 'Telugu';
      if (result == ShareService.downloadSaved) {
        setState(() => _posterDownloaded = true);
        HapticFeedback.lightImpact();
        Fluttertoast.showToast(
          msg: "గ్యాలరీలో సేవ్ చేయబడింది / Saved to your gallery",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green.shade700,
          textColor: Colors.white,
          fontSize: 15.0,
        );
      } else if (result == ShareService.downloadPermissionDenied) {
        Fluttertoast.showToast(
          msg: telugu
              ? "సేవ్ చేయడానికి గ్యాలరీ అనుమతి కావాలి"
              : "Gallery permission is needed to save",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange.shade800,
          textColor: Colors.white,
          fontSize: 15.0,
        );
      } else {
        Fluttertoast.showToast(
          msg: telugu
              ? "పోస్టర్ సేవ్ చేయడం విఫలమైంది"
              : "Could not save the poster",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red.shade700,
          textColor: Colors.white,
          fontSize: 15.0,
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPoster = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Fetch full article detail by slug. The detail API takes the slug only
    // — /articles/{id}/ is a 404 — so an item without one keeps its feed copy.
    final slugToFetch = widget.article.slug;
    if (!widget.article.isUgc && slugToFetch.isNotEmpty) {
      _fetchArticleDetail(slugToFetch);
    }
  }

  @override
  void didUpdateWidget(covariant SpotlightNewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id ||
        oldWidget.article.slug != widget.article.slug) {
      _posterDownloaded = false;
      ++_detailGeneration;
      _detailArticle = null;
      _isLoadingDetail = false;
      _detailError = null;
      final slug = widget.article.slug;
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
          slug: widget.article.slug,
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
    // The system status bar gets its own solid black band; the photo starts
    // strictly below it instead of sitting under the clock and icons.
    final statusBarHeight = MediaQuery.paddingOf(context).top;

    // Way2News-style frame: full width, a little shorter than square
    // (width / 1.22), flush against the status band. The square took half
    // the screen and cropped most photos into a zoomed look; this gives the
    // headline and body the room back. The cap only engages on a
    // landscape/very wide screen.
    final mediaHeight = (screenWidth / _mediaAspect)
        .clamp(0.0, (screenHeight - statusBarHeight) * 0.55);

    // Always fully painted. The feed is a FlipPageView now, which owns the
    // transition and passes no drag values — deriving opacity from them left
    // every card but the settled one at opacity 0, i.e. a blank white screen
    // for every story after the first.
    const textOpacity = 1.0;
    const imageOpacity = 1.0;
    const imageScale = 1.0;

    final headlineOffset = widget.dragDelta * 1.0;
    final bodyOffset = widget.dragDelta * 0.85;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light icons on the black status band, in both themes.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: requestedScale,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            // 0. STATUS BAR BAND — solid black, sized to the top safe area.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: statusBarHeight,
              child: const ColoredBox(color: Colors.black),
            ),

            // 1. IMAGE ZONE — exact square directly below the status band
            Positioned(
              top: statusBarHeight,
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
                                  dotsAtTop: true,
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
                                      // Fills the frame edge to edge — no
                                      // blur bands, never stretched.
                                      child: SmartFitImage(
                                        imageUrl:
                                            (article.mediaItems.isNotEmpty &&
                                                    article.mediaItems.first.url
                                                        .isNotEmpty)
                                                ? article.mediaItems.first.url
                                                : article.imageUrl,
                                      ),
                                    ),
                          // Dark-to-transparent scrim rising from the bottom
                          // edge, so the white attribution text stays legible
                          // over any photo. Kept short: the attribution is a
                          // single text block, not an avatar row.
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 96,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xE6000000),
                                      Color(0x80000000),
                                      Color(0x00000000),
                                    ],
                                    stops: [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Subtle Left Vertical Watermark (Non-intrusive)
                          const Positioned(
                            left: 8,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Opacity(
                                    opacity: 0.12,
                                    child: Text(
                                      'VAARADHI',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Category pill — inside the top-left corner.
                          // Shown only when the API sends a category.
                          if (article.category.isNotEmpty)
                            Positioned(
                              top: _mediaInset,
                              left: _mediaInset,
                              child: _CategoryPill(label: article.category),
                            ),

                          // Multi-media count — top-right, clear of the
                          // attribution block.
                          if (article.mediaItems.length > 1)
                            Positioned(
                              top: _mediaInset,
                              right: _mediaInset,
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

                          // Reporter attribution on the bottom inside edge:
                          // name + designation on the left, location pin on
                          // the right. No logo or link — the photo stays clean.
                          Positioned(
                            left: _mediaInset,
                            right: _mediaInset,
                            bottom: 10,
                            child: _ReporterAttribution(article: article),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),

            // 2. CONTENT ZONE
            Positioned.fill(
              top: statusBarHeight + mediaHeight,
              child: Opacity(
                opacity: textOpacity,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: _bodyGutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Listen + time sit directly under the image, above the headline.
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
                                        // Slim pill, same height as the
                                        // time text beside it.
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPlaying
                                              ? AppColors.primary
                                              : AppColors.primary
                                                  .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(14),
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
                                                    : Icons.headphones_rounded,
                                                size: 15,
                                                color: isPlaying
                                                    ? Colors.white
                                                    : AppColors.primary,
                                              ),
                                            const SizedBox(width: 5),
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
                                                    : AppColors.primary,
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
                                  // A Spacer here sat in a min-size Row with
                                  // unbounded width — a flex layout error.
                                  const SizedBox(width: 10),
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
                      const SizedBox(height: 8),

                      // Headline — below the Listen row. Bold, with
                      // generous leading for the height of Telugu clusters
                      // (vowel signs above, ottulu below).
                      Transform.translate(
                        offset: Offset(0, headlineOffset),
                        child: Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: GoogleFonts.notoSansTelugu(
                            fontSize: 19.0,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.readingTitleDark
                                : const Color(0xFF1E1E1E),
                            height: 1.45,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
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
                                // Larger and airier than before (was 14.8pt
                                // at 1.42) so older readers can read it
                                // comfortably — Way2News reference.
                                const double bodyLineHeight = 1.55;
                                const double referenceBody = 214.0; // compact
                                const double referenceFont = 17.2;

                                final fitted = referenceFont *
                                    (constraints.maxHeight / referenceBody)
                                        .clamp(1.0, 1.20);

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
                                    (fitted * preference).clamp(16.5, 19.0);

                                final textStyle = GoogleFonts.notoSansTelugu(
                                  fontSize: effectiveFontSize,
                                  color: isDark
                                      ? AppColors.readingBodyDark
                                      : const Color(0xFF333333),
                                  height: bodyLineHeight,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.1,
                                );

                                const double reservedForButton = 34.0;

                                // Ask the engine for the real line metrics
                                // rather than assuming fontSize * height.
                                // After shaping, a Telugu line is as tall as
                                // its tallest cluster — a base consonant with
                                // a vowel sign above and an ottu below is
                                // taller than the nominal figure, so the
                                // estimate ran high and pushed the Read More
                                // button off its line.
                                // The same span is measured and painted, so
                                // the paragraph gaps are counted in the fit.
                                final bodySpan =
                                    _paragraphSpan(toShow, textStyle);
                                final textPainter = TextPainter(
                                  text: bodySpan,
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
                                    Text.rich(
                                      bodySpan,
                                      maxLines: dynamicMaxLines,
                                      overflow: TextOverflow.ellipsis,
                                      // Justified Telugu opened wide gaps
                                      // between words; start-aligned reads
                                      // evenly.
                                      textAlign: TextAlign.start,
                                      textHeightBehavior:
                                          const TextHeightBehavior(
                                        applyHeightToFirstAscent: false,
                                        applyHeightToLastDescent: false,
                                      ),
                                      style: textStyle,
                                    ),
                                    if (shouldShowReadMore) ...[
                                      const SizedBox(height: 6),
                                      // Compact link-style pill: a quiet
                                      // cue, not a second headline.
                                      GestureDetector(
                                        onTap: _navigateToDetail,
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                AppState.instance.language ==
                                                        'Telugu'
                                                    ? 'ఇంకా చదవండి'
                                                    : 'Read more',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 12,
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
                                          // Same call for desk and citizen stories.
                                          final res = await ContentEngagementService
                                              .instance
                                              .react(article, nextReaction);
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
                                          // Same call for desk and citizen stories.
                                          final res = await ContentEngagementService
                                              .instance
                                              .react(article, nextReaction);
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
                                        : (_posterDownloaded
                                            ? Icons.check_circle_rounded
                                            : Icons.download_rounded),
                                    color: _posterDownloaded
                                        ? Colors.green
                                        : (isDark
                                            ? AppColors.readingMetaDark
                                            : const Color(0xFF6B7280)),
                                    label: '',
                                    onTap: () {
                                      if (_downloadingPoster || _posterDownloaded) return;
                                      _downloadPoster(article);
                                    },
                                  ),
                                // Share (Center, Prominent Red Circle)
                                GestureDetector(
                                  onTap: widget.onShare,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.share_rounded,
                                        color: Colors.white, size: 22),
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
                                // More (⋮): Report Story + Bookmark live in
                                // a bottom sheet instead of the bar.
                                Semantics(
                                  button: true,
                                  label: AppState.instance.language ==
                                          'Telugu'
                                      ? 'మరిన్ని ఎంపికలు'
                                      : 'More options',
                                  child: _buildActionIcon(
                                    key: const Key('spotlight_more_btn'),
                                    icon: Icons.more_vert_rounded,
                                    color: isDark
                                        ? AppColors.readingMetaDark
                                        : const Color(0xFF6B7280),
                                    label: '',
                                    onTap: () => _showMoreSheet(article),
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
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// Inset of the overlays inside the square (spec: 32px on a ~2.75x
  /// 1080px-wide screen ≈ 12 logical px).
  static const double _mediaInset = 12.0;

  /// Width / height of the media frame (Way2News reference ≈ 1.22).
  static const double _mediaAspect = 1.22;

  /// Left/right gutter of the headline and body (spec: ~48px ≈ 18 logical
  /// px).
  static const double _bodyGutter = 18.0;

  /// Gap between paragraphs (spec: 24px ≈ 9 logical px).
  static const double _paragraphGap = 9.0;

  /// Body text with a fixed gap between paragraphs. Runs of blank lines
  /// collapse to one gap. The gap is an empty line set at [_paragraphGap],
  /// so the TextPainter that fits the copy measures it exactly.
  static TextSpan _paragraphSpan(String text, TextStyle style) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n|\r\n\s*\r\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.length <= 1) return TextSpan(text: text, style: style);
    final gap = style.copyWith(fontSize: _paragraphGap, height: 1.0);
    return TextSpan(style: style, children: [
      for (var i = 0; i < paragraphs.length; i++) ...[
        if (i > 0) ...[
          const TextSpan(text: '\n'),
          TextSpan(text: '\n', style: gap),
        ],
        TextSpan(text: paragraphs[i]),
      ],
    ]);
  }

  /// ⋮ in the action bar: Report Story and Bookmark.
  Future<void> _showMoreSheet(NewsArticle article) async {
    HapticFeedback.selectionClick();
    final targetId = article.id.isNotEmpty ? article.id : article.slug;
    final isSaved = article.isBookmarked ||
        AppState.instance.isBookmarked(targetId) ||
        (widget.article.id.isNotEmpty &&
            AppState.instance.isBookmarked(widget.article.id));

    final choice = await StoryOptionsSheet.show(
      context,
      isBookmarked: isSaved,
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case StoryOption.bookmark:
        _handleBookmarkTap(
            targetId: targetId, isSaved: isSaved, article: article);
        break;
      case StoryOption.report:
        await StoryActions.report(context, article);
        break;
    }
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
      final saved = await ContentEngagementService.instance
          .setSaved(article, nowSaved: nowSaved);
      if (saved == null) {
        failed = true;
      } else if (saved != nowSaved) {
        // The server's toggle is the truth; adopt it.
        AppState.instance.setBookmarked(targetId, saved);
        if (mounted) setState(() => article.isBookmarked = saved);
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
    Key? key,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
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

/// Category tag in the top-left corner of the square.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 6),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Attribution along the bottom inside edge of the image: the reporter's
/// name (left) and the story's location (right) — only what the API sends.
/// No hard-coded "News Desk / Editorial Team / Reporter" text; when neither
/// is known, nothing is drawn.
class _ReporterAttribution extends StatelessWidget {
  const _ReporterAttribution({required this.article});

  final NewsArticle article;

  /// Most specific place first, up to two levels ("Kesaram, Suryapet").
  String get _location {
    final parts = <String>[
      for (final p in [
        article.village,
        article.subdistrict,
        article.district,
        article.state,
      ])
        if (p != null && p.trim().isNotEmpty) p.trim(),
    ];
    final unique = <String>[];
    for (final p in parts) {
      if (!unique.contains(p)) unique.add(p);
    }
    return unique.take(2).join(', ');
  }

  static const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 4)];

  @override
  Widget build(BuildContext context) {
    final name = article.byline;
    final location = _location;
    if (name.isEmpty && location.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: name.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    shadows: _shadow,
                  ),
                ),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 13, color: Colors.white, shadows: _shadow),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      shadows: _shadow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
