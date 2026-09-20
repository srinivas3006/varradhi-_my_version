import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/navigation/auth_guard.dart';
import '../models/news_article.dart';
import '../localization/app_translations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_service.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../repositories/news_article_repository.dart';
import '../services/ad_manager.dart';
import '../widgets/ads/banner_ad_slot.dart';
import '../widgets/ads/interstitial_ad_overlay.dart';
import '../widgets/article_media_carousel.dart';
import '../widgets/watermark/article_watermark_overlay.dart';
import 'comments_screen.dart';

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
      if (mounted) {
        setState(() {
          _isLoadingDetail = false;
          _detailError = null;
        });
      }
      return;
    }

    final slugToFetch = (widget.slug?.isNotEmpty ?? false)
        ? widget.slug!
        : (widget.article.slug.isNotEmpty
            ? widget.article.slug
            : (widget.article.id.isNotEmpty
                ? widget.article.id
                : article.slug));
    if (slugToFetch.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingDetail = false;
          _detailError = 'Article slug is missing.';
        });
      }
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

  Future<void> _toggleLike() => _toggleReaction('like');
  Future<void> _toggleDislike() => _toggleReaction('dislike');

  String _formatCount(int count) {
    if (count <= 0) return '';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Future<void> _toggleBookmark() async {
    if (!AppState.instance.isLoggedIn) {
      requireAuth(context, () => _toggleBookmark());
      return;
    }
    final targetId = article.id.isNotEmpty ? article.id : article.slug;
    if (targetId.isEmpty) return;

    HapticFeedback.lightImpact();
    final wasBookmarked =
        article.isBookmarked || AppState.instance.isBookmarked(targetId);
    AppState.instance.toggleBookmark(targetId);
    if (mounted) setState(() => article.isBookmarked = !wasBookmarked);

    try {
      await ApiService.instance.toggleBookmark(targetId);
    } catch (e) {
      if (AppState.instance.isBookmarked(targetId) != wasBookmarked) {
        AppState.instance.toggleBookmark(targetId);
      }
      if (mounted) setState(() => article.isBookmarked = wasBookmarked);
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
              AppState.instance.isBookmarked(targetId)
                  ? tr('saved_to_bookmarks')
                  : tr('removed_from_bookmarks'),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _showUgcReportSheet() async {
    final reasons = <(String, String)>[
      ('spam', tr('reason_spam_short')),
      ('misinformation', tr('reason_misinformation_short')),
      ('inappropriate', tr('reason_inappropriate')),
      ('other', tr('reason_other')),
    ];

    final selected = await showModalBottomSheet<(String, String)>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('report_citizen_news'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...reasons.map(
                (reason) => ListTile(
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(reason.$2),
                  onTap: () => Navigator.pop(sheetContext, reason),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    try {
      final reported = await ApiService.instance.reportUgcSubmission(
        submissionId: article.id,
        reason: selected.$1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reported ? tr('report_submitted') : tr('report_submit_failed'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error reporting UGC submission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('report_submit_failed')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _share() {
    ShareService.shareArticle(article);
  }

  @override
  void initState() {
    super.initState();
    article = widget.article;
    final targetId = article.id.isNotEmpty ? article.id : article.slug;
    if (!article.isUgc) {
      if (AppState.instance.isLiked(targetId)) {
        article.isLiked = true;
      }
      _fetchFullArticleDetail();
    } else {
      _fetchFullArticleDetail();
    }
  }

  @override
  void dispose() {
    AppTtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppColors.cardDarkNavy : Colors.white;
    final titleColor =
        isDark ? AppColors.readingTitleDark : AppColors.readingTitleLight;
    final bodyColor =
        isDark ? AppColors.readingBodyDark : AppColors.readingBodyLight;
    final mutedTextColor =
        isDark ? AppColors.readingMetaDark : AppColors.readingMetaLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Full Hero Media Background (Top Section)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 360,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArticleMediaCarousel(
                  article: article,
                  showWatermark: false,
                  onPageChanged: (index) =>
                      setState(() => _currentImageIndex = index),
                ),

                // Top Gradient Overlay for readability of status bar & top buttons
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Non-intrusive Article Watermark Overlay (Vertical VAARADHI on left + bottom-right logo)
                // Constrained to visible hero area (height 310) so it's not cut off by the curved sheet.
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 310,
                  child: ArticleWatermarkOverlay(),
                ),

                // Multi-Image Index Indicator Pill (Positioned to the left of the Logo watermark so no overlap occurs)
                if (article.imageUrls != null && article.imageUrls!.length > 1)
                  Positioned(
                    top: 272,
                    right: 56,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${article.imageUrls!.length}',
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
          ),

          // 2. Frosted Header Action Bar (Top Floating Controls with Way2News Category & Desk)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            right: 14,
            child: Row(
              children: [
                // Back Button with Interstitial eligibility check
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    if (AdManager.instance.canShowInterstitial()) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (context.mounted) showInterstitialAd(context);
                      });
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),

                // Category & Desk Title (Way2News style)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        article.category.isNotEmpty
                            ? article.category
                            : 'General',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        article.authorName.isNotEmpty &&
                                !article.authorName
                                    .toLowerCase()
                                    .contains('john')
                            ? article.authorName
                            : (article.source.isNotEmpty
                                ? article.source
                                : 'VARADHI Desk'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions (Bookmark & Share)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isUgc)
                      AnimatedBuilder(
                        animation: AppState.instance,
                        builder: (context, _) {
                          final targetId =
                              article.id.isNotEmpty ? article.id : article.slug;
                          // Backend saved-state first, local set as the
                          // optimistic overlay — matching how isLiked is
                          // read. Reading only the set meant a bookmark from
                          // an earlier session never showed here.
                          final isBookmarked = article.isBookmarked ||
                              AppState.instance.isBookmarked(targetId);
                          return GestureDetector(
                            onTap: _toggleBookmark,
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isBookmarked
                                    ? AppColors.primary
                                    : Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1),
                              ),
                              child: Icon(
                                isBookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          );
                        },
                      ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _share();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1),
                        ),
                        child: const Icon(Icons.share_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Overlapping Curved Sheet Article Body (Bottom Section)
          Positioned.fill(
            top: 310, // Overlaps top hero image
            child: Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Centered Top Handle Indicator
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Row: AUDIO LISTEN BUTTON (Replacing Channel Name) + Share Quick Icon
                      Row(
                        children: [
                          // Audio Listen Pill Button (Orange Accent)
                          AnimatedBuilder(
                            animation: AppTtsService.instance,
                            builder: (context, _) {
                              final targetId = article.id.isNotEmpty
                                  ? article.id
                                  : article.slug;
                              final isPlaying = AppTtsService.instance
                                  .isArticlePlaying(targetId);
                              final isLoading = AppTtsService.instance
                                  .isArticleLoading(targetId);

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      AppTtsService.instance
                                          .toggleArticleTts(article);
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isPlaying
                                            ? AppColors.primary
                                            : AppColors.primary
                                                .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                              alpha: isPlaying ? 1.0 : 0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isLoading)
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.primary),
                                            )
                                          else
                                            Icon(
                                              isPlaying
                                                  ? Icons.stop_circle_rounded
                                                  : Icons.volume_up_rounded,
                                              size: 20,
                                              color: isPlaying
                                                  ? Colors.white
                                                  : AppColors.primary,
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
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        AppTtsService.instance.cycleSpeed();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          AppTtsService
                                              .instance.playbackSpeedText,
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
                          ),

                          const Spacer(),

                          // Orange Highlighted Share Button (Right Header)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _share();
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3),
                                    width: 1),
                              ),
                              child: const Icon(Icons.share_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Main Article Title (Headline)
                      Text(
                        article.title,
                        style: GoogleFonts.notoSansTelugu(
                          fontSize: 22.0,
                          fontWeight: FontWeight.w700,
                          height: 1.30,
                          color: titleColor,
                          letterSpacing: 0.0,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Author & Timestamp Row
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 15, color: mutedTextColor),
                          const SizedBox(width: 5),
                          Text(
                            article.timeAgo,
                            style: TextStyle(
                                fontSize: 13.5,
                                color: mutedTextColor,
                                fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(width: 10),
                          Text('•',
                              style: TextStyle(
                                  color: mutedTextColor, fontSize: 14)),
                          const SizedBox(width: 10),
                          Icon(Icons.menu_book_rounded,
                              size: 15, color: mutedTextColor),
                          const SizedBox(width: 5),
                          Text(
                            '${article.readTimeMinutes} నిమిషాల పఠనం',
                            style: TextStyle(
                                fontSize: 13.5,
                                color: mutedTextColor,
                                fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Article engagement or UGC moderation actions.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceElevatedDark
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : const Color(0xFFE5E7EB),
                              width: 0.8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _isUgc
                              ? [
                                  Row(
                                    children: [
                                      const Icon(Icons.campaign_outlined,
                                          color: AppColors.primary, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        tr('citizen_report'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _showUgcReportSheet,
                                    icon: const Icon(Icons.flag_outlined,
                                        size: 18),
                                    label: Text(tr('report')),
                                  ),
                                ]
                              : [
                                  // Likes Metric Pill
                                  AnimatedBuilder(
                                    animation: AppState.instance,
                                    builder: (context, _) {
                                      final targetId = article.id.isNotEmpty
                                          ? article.id
                                          : article.slug;
                                      final isLiked =
                                          AppState.instance.isLiked(targetId) ||
                                              article.isLiked;

                                      return InkWell(
                                        onTap: _toggleLike,
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedSwitcher(
                                                duration: const Duration(
                                                    milliseconds: 250),
                                                transitionBuilder:
                                                    (child, anim) =>
                                                        ScaleTransition(
                                                            scale: anim,
                                                            child: child),
                                                child: Icon(
                                                  isLiked
                                                      ? Icons.favorite_rounded
                                                      : Icons
                                                          .favorite_outline_rounded,
                                                  key: ValueKey(isLiked),
                                                  color: isLiked
                                                      ? AppColors.heartRed
                                                      : (isDark
                                                          ? AppColors.iconMutedDark
                                                          : const Color(0xFF9CA3AF)),
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${article.likes}',
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isLiked
                                                      ? AppColors.heartRed
                                                      : (isDark
                                                          ? AppColors.textLight
                                                          : AppColors.readingTitleLight),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  Container(
                                      width: 1,
                                      height: 22,
                                      color: isDark
                                          ? AppColors.borderDark
                                          : const Color(0xFFE5E7EB)),

                                  // Dislikes Metric Pill
                                  AnimatedBuilder(
                                    animation: AppState.instance,
                                    builder: (context, _) {
                                      final targetId = article.id.isNotEmpty
                                          ? article.id
                                          : article.slug;
                                      final isDisliked =
                                          AppState.instance.isDisliked(targetId) ||
                                              article.isDisliked;

                                      return InkWell(
                                        onTap: _toggleDislike,
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedSwitcher(
                                                duration: const Duration(
                                                    milliseconds: 250),
                                                transitionBuilder:
                                                    (child, anim) =>
                                                        ScaleTransition(
                                                            scale: anim,
                                                            child: child),
                                                child: Icon(
                                                  isDisliked
                                                      ? Icons.thumb_down_rounded
                                                      : Icons.thumb_down_outlined,
                                                  key: ValueKey(isDisliked),
                                                  color: isDisliked
                                                      ? Colors.redAccent
                                                      : (isDark
                                                          ? AppColors.iconMutedDark
                                                          : const Color(0xFF9CA3AF)),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${article.dislikes}',
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDisliked
                                                      ? Colors.redAccent
                                                      : (isDark
                                                          ? AppColors.textLight
                                                          : AppColors.readingTitleLight),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  Container(
                                      width: 1,
                                      height: 22,
                                      color: isDark
                                          ? AppColors.borderDark
                                          : const Color(0xFFE5E7EB)),

                                  // Comments Metric Pill
                                  AnimatedBuilder(
                                    animation: AppState.instance,
                                    builder: (context, _) {
                                      final count = AppState.instance
                                          .getDisplayCommentCount(
                                              article.id, article.comments);
                                      return InkWell(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CommentsScreen(
                                                  article: article),
                                            ),
                                          ).then((_) {
                                            if (mounted) setState(() {});
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                  Icons
                                                      .chat_bubble_outline_rounded,
                                                  color: isDark
                                                      ? AppColors.iconMutedDark
                                                      : const Color(0xFF9CA3AF),
                                                  size: 24),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$count',
                                                style: TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? AppColors.textLight
                                                        : AppColors.readingTitleLight),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Article Content Body
                      if (_isLoadingDetail && article.body.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
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
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold),
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
                                      fontSize:
                                          AppState.instance.readingFontSize,
                                      height: 1.62,
                                      letterSpacing: 0.2,
                                      color: bodyColor,
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
                          builder: (context, _) => _buildWay2NewsBodyText(
                            article.body.isNotEmpty
                                ? article.body
                                : (article.summary.isNotEmpty
                                    ? article.summary
                                    : ''),
                            bodyColor,
                          ),
                        ),

                      if (!_isUgc) ...[
                        _buildReactionSection(isDark),
                        const SizedBox(height: 16),
                        const BannerAdSlot(placementZone: 'article'),
                        const SizedBox(height: 32),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionSection(bool isDark) {
    final targetId = article.id.isNotEmpty ? article.id : article.slug;
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final isLiked = article.isLiked ||
            AppState.instance.isLiked(targetId) ||
            (article.id.isNotEmpty && AppState.instance.isLiked(article.id));
        final isDisliked = article.isDisliked ||
            AppState.instance.isDisliked(targetId) ||
            (article.id.isNotEmpty &&
                AppState.instance.isDisliked(article.id));

        final cardBg = isDark ? AppColors.surfaceElevatedDark : const Color(0xFFF3F4F6);
        final activeColor = AppColors.primary;
        final inactiveColor =
            isDark ? AppColors.readingMetaDark : const Color(0xFF6B7280);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.borderDark
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Like Button
              InkWell(
                onTap: () => _toggleReaction('like'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiked
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_alt_outlined,
                        color: isLiked ? activeColor : inactiveColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCount(article.likes).isNotEmpty
                            ? _formatCount(article.likes)
                            : (AppState.instance.language == 'Telugu'
                                ? 'లైక్'
                                : 'Like'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLiked ? activeColor : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider
              Container(
                height: 24,
                width: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),

              // Dislike Button
              InkWell(
                onTap: () => _toggleReaction('dislike'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDisliked
                            ? Icons.thumb_down_rounded
                            : Icons.thumb_down_alt_outlined,
                        color: isDisliked ? Colors.redAccent : inactiveColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCount(article.dislikes).isNotEmpty
                            ? _formatCount(article.dislikes)
                            : (AppState.instance.language == 'Telugu'
                                ? 'డిస్‌లైక్'
                                : 'Dislike'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDisliked ? Colors.redAccent : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider
              Container(
                height: 24,
                width: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),

              // Share Button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _share();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        color: inactiveColor,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppState.instance.language == 'Telugu' ? 'షేర్' : 'Share',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWay2NewsBodyText(String text, Color bodyColor) {
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

    final paragraphStyle = GoogleFonts.notoSansTelugu(
      fontSize: AppState.instance.readingFontSize,
      height: 1.62,
      color: bodyColor,
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
