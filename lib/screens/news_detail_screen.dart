import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/news_article.dart';
import '../localization/app_translations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_service.dart';
import '../services/tts_service.dart';
import '../repositories/news_article_repository.dart';
import '../services/ad_manager.dart';
import '../widgets/ads/banner_ad_slot.dart';
import '../widgets/ads/interstitial_ad_overlay.dart';
import '../widgets/article_media_carousel.dart';
import 'comments_screen.dart';
import '../widgets/spotlight/story_options_sheet.dart';
import '../services/content_engagement_service.dart';
import '../services/api_service.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  final String? slug;

  const NewsDetailScreen({super.key, required this.article, this.slug});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late NewsArticle article;
  int _currentImageIndex = 0;
  bool _isLoadingDetail = false;
  String? _detailError;

  bool get _isUgc => article.isUgc;

  Future<void> _fetchFullArticleDetail() async {
    if (_isUgc) {
      await _fetchUgcDetail();
      return;
    }

    // Slug only: the detail API is /api/v1/articles/{slug}/, and an id there
    // is always a 404. Without a slug the feed copy already on screen stands.
    final slugToFetch = (widget.slug?.isNotEmpty ?? false)
        ? widget.slug!
        : widget.article.slug;
    if (slugToFetch.isEmpty) {
      debugPrint('Detail: no slug for article ${widget.article.id}; '
          'showing feed copy');
      if (mounted) setState(() => _isLoadingDetail = false);
      return;
    }

    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      debugPrint('Fetching full detail for slug: $slugToFetch');
      final fullArticle =
          await NewsArticleRepository.instance.getDetail(slugToFetch);
      debugPrint(
          'Detail API success for slug "$slugToFetch". Body length: ${fullArticle.body.length}');

      if (mounted) {
        setState(() {
          article = fullArticle;
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      debugPrint('Detail API error for slug "$slugToFetch": $e');
      if (mounted) {
        setState(() {
          _detailError = e.toString();
          _isLoadingDetail = false;
        });
      }
    }
  }

  /// Citizen post: `GET /api/v1/ugc/{id}/` brings full media and the
  /// reader's engagement state. The feed copy stays on screen meanwhile, and
  /// remains if the request fails — unless there is nothing to show (opened
  /// from a bare link), in which case the error and Retry appear.
  Future<void> _fetchUgcDetail() async {
    final id = widget.article.id;
    if (id.isEmpty) return;
    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });
    try {
      final full = await ApiService.instance.getUgcDetail(id);
      if (!mounted) return;
      setState(() {
        // Keep whatever the detail payload leaves blank from the feed copy.
        article = full.title.isEmpty && article.title.isNotEmpty
            ? article
            : full;
        _isLoadingDetail = false;
      });
    } catch (e) {
      debugPrint('UGC detail error for "$id": $e');
      if (mounted) {
        setState(() {
          _detailError = e.toString();
          _isLoadingDetail = false;
        });
      }
    }
  }

  bool _isTogglingReaction = false;

  Future<void> _toggleReaction(String tapped) async {
    if (_isTogglingReaction) return;
    _isTogglingReaction = true;
    HapticFeedback.selectionClick();

    final targetId = article.id.isNotEmpty ? article.id : article.slug;
    if (targetId.isEmpty) {
      _isTogglingReaction = false;
      return;
    }

    final isCurrentlyLiked =
        AppState.instance.isLiked(targetId) || article.isLiked;
    final isCurrentlyDisliked =
        AppState.instance.isDisliked(targetId) || article.isDisliked;

    String nextReaction;
    if (tapped == 'like') {
      nextReaction = isCurrentlyLiked ? 'none' : 'like';
    } else if (tapped == 'dislike') {
      nextReaction = isCurrentlyDisliked ? 'none' : 'dislike';
    } else {
      nextReaction = 'none';
    }

    AppState.instance.setReaction(targetId, nextReaction);
    final prevLikes = article.likes;
    final prevDislikes = article.dislikes;

    setState(() {
      if (nextReaction == 'like') {
        article.isLiked = true;
        article.likes = isCurrentlyLiked ? prevLikes : prevLikes + 1;
        if (isCurrentlyDisliked) {
          article.isDisliked = false;
          article.dislikes = prevDislikes > 0 ? prevDislikes - 1 : 0;
        }
      } else if (nextReaction == 'dislike') {
        article.isDisliked = true;
        article.dislikes = isCurrentlyDisliked ? prevDislikes : prevDislikes + 1;
        if (isCurrentlyLiked) {
          article.isLiked = false;
          article.likes = prevLikes > 0 ? prevLikes - 1 : 0;
        }
      } else {
        if (isCurrentlyLiked) {
          article.isLiked = false;
          article.likes = prevLikes > 0 ? prevLikes - 1 : 0;
        }
        if (isCurrentlyDisliked) {
          article.isDisliked = false;
          article.dislikes = prevDislikes > 0 ? prevDislikes - 1 : 0;
        }
      }
    });

    try {
      final res =
          await ContentEngagementService.instance.react(article, nextReaction);
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
      debugPrint('[NewsDetailScreen] Could not sync reaction to backend: $e');
      if (mounted) {
        AppState.instance.setReaction(
            targetId,
            isCurrentlyLiked
                ? 'like'
                : (isCurrentlyDisliked ? 'dislike' : 'none'));
        setState(() {
          article.isLiked = isCurrentlyLiked;
          article.likes = prevLikes;
          article.isDisliked = isCurrentlyDisliked;
          article.dislikes = prevDislikes;
        });
      }
    } finally {
      _isTogglingReaction = false;
    }
  }


  String _formatCount(int count) {
    if (count <= 0) return '';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Future<void> _toggleBookmark() async {
    // Guests bookmark too (kept on the phone until they log in), so there
    // is no login gate here.
    final targetId = AppState.bookmarkKey(article);
    if (targetId.isEmpty || _bookmarkInFlight) return;
    _bookmarkInFlight = true;
    try {
      await _runBookmarkToggle(targetId);
    } finally {
      _bookmarkInFlight = false;
    }
  }

  /// One bookmark request at a time: a second tap while one is running is
  /// ignored rather than sent (bookmark handover §10).
  bool _bookmarkInFlight = false;

  Future<void> _runBookmarkToggle(String targetId) async {
    HapticFeedback.lightImpact();
    final wasBookmarked = AppState.instance.isStoryBookmarked(article);
    final nowBookmarked = !wasBookmarked;
    // Set, never flip: flipping the local copy inverted it whenever it
    // disagreed with the story's own is_bookmarked, which left a removed
    // bookmark stuck as "saved".
    _applyBookmark(targetId, nowBookmarked);

    try {
      // Same call for desk and citizen stories.
      final bookmarked = await ContentEngagementService.instance
          .setBookmarked(article, nowBookmarked: nowBookmarked);
      if (bookmarked == null) throw Exception('bookmark not saved');
      // The server's answer is the truth; adopt it.
      if (bookmarked != nowBookmarked) _applyBookmark(targetId, bookmarked);
    } catch (e) {
      _applyBookmark(targetId, wasBookmarked);
      debugPrint('Error syncing article bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(tr('bookmark_update_failed')),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppState.instance.isStoryBookmarked(article)
                  ? tr('saved_to_bookmarks')
                  : tr('removed_from_bookmarks'),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Puts one bookmark state everywhere this screen can reach: the shared
  /// state every screen reads, this screen's copy of the story, and the feed
  /// copy it was opened from.
  void _applyBookmark(String targetId, bool bookmarked) {
    AppState.instance.setBookmarked(targetId, bookmarked);
    widget.article.isBookmarked = bookmarked;
    if (mounted) {
      setState(() => article.isBookmarked = bookmarked);
    } else {
      article.isBookmarked = bookmarked;
    }
  }

  /// ⋮ in the header: the same Report Story / Bookmark sheet as Spotlight,
  /// for desk articles and citizen posts alike.
  Future<void> _showMoreSheet() async {
    HapticFeedback.selectionClick();
    final isSaved = AppState.instance.isStoryBookmarked(article);
    final choice =
        await StoryOptionsSheet.show(context, isBookmarked: isSaved);
    if (!mounted || choice == null) return;
    switch (choice) {
      case StoryOption.bookmark:
        await _toggleBookmark();
        break;
      case StoryOption.report:
        await StoryActions.report(context, article);
        break;
    }
  }

  void _share() {
    // The detail payload can lack a usable still; the feed article this
    // screen opened from is what Spotlight shares, so it backs it up.
    ShareService.shareArticle(article, fallback: widget.article);
  }

  void _goBack() {
    HapticFeedback.lightImpact();
    // This screen is gone once popped, so the ad is shown from the
    // navigator's context, which outlives it.
    final navigator = Navigator.of(context);
    final navContext = navigator.context;
    navigator.pop();
    if (AdManager.instance.canShowInterstitial()) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (navContext.mounted) showInterstitialAd(navContext);
      });
    }
  }

  void _openComments() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommentsScreen(article: article)),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    article = widget.article;
    final targetId = article.id.isNotEmpty ? article.id : article.slug;
    if (AppState.instance.isLiked(targetId)) {
      article.isLiked = true;
    }
    _fetchFullArticleDetail();
  }

  @override
  void dispose() {
    AppTtsService.instance.stop();
    super.dispose();
  }

  /// Layout, top to bottom: a black band under the status bar, then one
  /// scrolling column — photo, meta, headline, listen, story, ad — with the
  /// engagement bar pinned to the bottom. The photo scrolls with the story
  /// instead of sitting fixed behind a draggable-looking sheet, and back / ⋮
  /// float over everything so they are always reachable.
  ///
  /// The VAARADHI masthead is not shown here: it belongs on shared and
  /// downloaded images (ShareService), not on the reading screen.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppColors.cardDarkNavy : Colors.white;
    final size = MediaQuery.sizeOf(context);
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    // Same frame as the Spotlight card (width / 1.22), so a story keeps its
    // crop when it is opened.
    final heroHeight = (size.width / 1.22).clamp(220.0, size.height * 0.5);

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: _clampedTextScale(context),
      child: Scaffold(
        backgroundColor: pageBg,
        bottomNavigationBar: _buildReactionSection(isDark),
        body: Column(
          children: [
            // Status bar band: the photo starts right below the clock and
            // icons, never under them.
            AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.black,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
              child: SizedBox(
                height: statusBarHeight,
                width: double.infinity,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: Stack(
                  children: [
                    CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHero(heroHeight)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          sliver: SliverToBoxAdapter(
                            child: _buildStory(isDark),
                          ),
                        ),
                      ],
                    ),
                    // Floating header controls, always reachable.
                    Positioned(
                      top: 10,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          _circleButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            iconSize: 18,
                            onTap: _goBack,
                          ),
                          const Spacer(),
                          // More (⋮): Report Story + Bookmark — the same
                          // sheet as Spotlight, for every story.
                          Semantics(
                            button: true,
                            label: AppState.instance.language == 'Telugu'
                                ? 'మరిన్ని ఎంపికలు'
                                : 'More options',
                            child: _circleButton(
                              key: const Key('detail_more_btn'),
                              icon: Icons.more_vert_rounded,
                              iconSize: 20,
                              onTap: _showMoreSheet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    Key? key,
    required IconData icon,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }

  /// The photo, edge to edge, with a light top shade so the floating
  /// buttons stay legible over bright images.
  Widget _buildHero(double height) {
    final imageCount = article.imageUrls?.length ?? 0;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArticleMediaCarousel(
            article: article,
            showWatermark: false,
            onPageChanged: (index) =>
                setState(() => _currentImageIndex = index),
          ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (imageCount > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/$imageCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStory(bool isDark) {
    final bodyColor =
        isDark ? AppColors.readingBodyDark : AppColors.readingBodyLight;
    final mutedTextColor =
        isDark ? AppColors.readingMetaDark : AppColors.readingMetaLight;
    final metaStyle = TextStyle(
        fontSize: 12.5, color: mutedTextColor, fontWeight: FontWeight.w500);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category · time · read time. Only what the API sends — no
        // hard-coded "General" placeholder.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            if (article.category.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  article.category,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            Text(article.timeAgo, style: metaStyle),
            Text('•', style: metaStyle),
            Text('${article.readTimeMinutes} నిమిషాల పఠనం', style: metaStyle),
          ],
        ),
        const SizedBox(height: 14),

        Text(
          article.title,
          style: GoogleFonts.notoSansTelugu(
            fontSize: 22.0,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: isDark ? AppColors.readingTitleDark : const Color(0xFF1A1A1A),
          ),
        ),

        if (article.byline.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(article.byline, style: metaStyle),
        ],

        const SizedBox(height: 16),
        _buildListenButton(),
        const SizedBox(height: 18),
        Divider(
          height: 1,
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        ),
        const SizedBox(height: 18),

        // Article Content Body
        if (_isLoadingDetail && article.body.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_detailError != null && article.body.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('full_article_load_failed'),
                  style: const TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _fetchFullArticleDetail,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(tr('retry')),
                ),
                const SizedBox(height: 12),
                if (article.summary.isNotEmpty)
                  AnimatedBuilder(
                    animation: AppState.instance,
                    builder: (context, _) => Text(
                      article.summary,
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: AppState.instance.readingFontSize > 0
                            ? (AppState.instance.readingFontSize * (18.5 / 19.0))
                            : 18.5,
                        height: 1.65,
                        letterSpacing: 0.2,
                        color: isDark
                            ? AppColors.readingBodyDark
                            : const Color(0xFF424242),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) => _buildArticleBodyText(
              article.body.isNotEmpty
                  ? article.body
                  : (article.summary.isNotEmpty ? article.summary : ''),
              bodyColor,
            ),
          ),

        // Every story carries the same ad.
        const BannerAdSlot(placementZone: 'article'),
      ],
    );
  }

  /// Listen pill, plus a speed chip while it plays.
  Widget _buildListenButton() {
    return AnimatedBuilder(
      animation: AppTtsService.instance,
      builder: (context, _) {
        final targetId = article.id.isNotEmpty ? article.id : article.slug;
        final isPlaying = AppTtsService.instance.isArticlePlaying(targetId);
        final isLoading = AppTtsService.instance.isArticleLoading(targetId);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                AppTtsService.instance.toggleArticleTts(article);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    else
                      Icon(
                        isPlaying
                            ? Icons.stop_circle_rounded
                            : Icons.headphones_rounded,
                        size: 18,
                        color: isPlaying ? Colors.white : AppColors.primary,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      isLoading
                          ? tr('loading')
                          : (isPlaying
                              ? tr('stop_audio')
                              : tr('listen_article')),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPlaying ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isPlaying) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppTtsService.instance.cycleSpeed();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    AppTtsService.instance.playbackSpeedText,
                    style: const TextStyle(
                      fontSize: 12,
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
    );
  }

  /// Caps runaway system text scaling, as the spotlight card does.
  ///
  /// This screen lays out its chrome — meta row, engagement bar, buttons — at
  /// fixed sizes, so Android's accessibility scale multiplied all of them and
  /// overflowed the row on smaller devices.
  double _clampedTextScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3);

  /// Engagement bar pinned to the bottom of the screen: four equal slots,
  /// icon over label, so it never overflows the way the old inline row did
  /// ("Share" was cut off on narrow phones).
  Widget _buildReactionSection(bool isDark) {
    final targetId = article.id.isNotEmpty ? article.id : article.slug;
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final telugu = AppState.instance.language == 'Telugu';
        final isLiked = article.isLiked ||
            AppState.instance.isLiked(targetId) ||
            (article.id.isNotEmpty && AppState.instance.isLiked(article.id));
        final isDisliked = article.isDisliked ||
            AppState.instance.isDisliked(targetId) ||
            (article.id.isNotEmpty &&
                AppState.instance.isDisliked(article.id));
        final commentCount = AppState.instance
            .getDisplayCommentCount(article.id, article.comments);

        const activeColor = AppColors.primary;
        final inactiveColor =
            isDark ? AppColors.readingMetaDark : const Color(0xFF6B7280);

        String countOr(int count, String label) =>
            _formatCount(count).isNotEmpty ? _formatCount(count) : label;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkNavy : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.borderDark
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  _barAction(
                    icon: isLiked
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_alt_outlined,
                    label: countOr(article.likes, telugu ? 'లైక్' : 'Like'),
                    color: isLiked ? activeColor : inactiveColor,
                    onTap: () => _toggleReaction('like'),
                  ),
                  _barAction(
                    icon: isDisliked
                        ? Icons.thumb_down_rounded
                        : Icons.thumb_down_alt_outlined,
                    label: countOr(
                        article.dislikes, telugu ? 'డిస్‌లైక్' : 'Dislike'),
                    color: isDisliked ? Colors.redAccent : inactiveColor,
                    onTap: () => _toggleReaction('dislike'),
                  ),
                  _barAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: countOr(commentCount, telugu ? 'కామెంట్' : 'Comment'),
                    color: inactiveColor,
                    onTap: _openComments,
                  ),
                  _barAction(
                    icon: Icons.share_rounded,
                    label: telugu ? 'షేర్' : 'Share',
                    color: inactiveColor,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _share();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _barAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleBodyText(String text, Color bodyColor) {
    if (text.isEmpty) {
      return Text(
        tr('no_content'),
        style: GoogleFonts.notoSansTelugu(
          fontSize: AppState.instance.readingFontSize,
          color: bodyColor.withValues(alpha: 0.7),
        ),
      );
    }

    final rawParagraphs = text.split('\n');
    final paragraphs = <String>[];
    final buffer = StringBuffer();
    for (final line in rawParagraphs) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (buffer.isNotEmpty) {
          paragraphs.add(buffer.toString());
          buffer.clear();
        }
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(trimmed);
      }
    }
    if (buffer.isNotEmpty) {
      paragraphs.add(buffer.toString());
    }

    if (paragraphs.isEmpty) {
      paragraphs.add(text.trim());
    }

    final effectiveFontSize = AppState.instance.readingFontSize > 0
        ? (AppState.instance.readingFontSize * (18.5 / 19.0))
        : 18.5; // larger for easy reading (was 16)

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paragraphStyle = GoogleFonts.notoSansTelugu(
      fontSize: effectiveFontSize,
      height: 1.65,
      color: isDark ? AppColors.readingBodyDark : const Color(0xFF424242),
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < paragraphs.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              paragraphs[i],
              textAlign: TextAlign.start,
              style: paragraphStyle,
            ),
          ),
          // Mid-article banner ad injection after 2nd paragraph
          if (i == 1 && paragraphs.length > 2) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14.0),
              child:
                  BannerAdSlot(placementZone: 'article_detail', maxHeight: 80),
            ),
          ],
        ],
        // Bottom article banner ad
        const Padding(
          padding: EdgeInsets.only(top: 8.0, bottom: 20.0),
          child: BannerAdSlot(placementZone: 'article_bottom', maxHeight: 80),
        ),
      ],
    );
  }
}
