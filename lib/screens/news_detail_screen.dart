import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import '../models/news_article.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_service.dart';
import '../services/api_service.dart';
import '../repositories/news_article_repository.dart';
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
  final FlutterTts flutterTts = FlutterTts();
  bool isPlaying = false;
  int _currentImageIndex = 0;
  bool _isLoadingDetail = false;
  String? _detailError;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;


  Future<void> _fetchFullArticleDetail() async {
    final slugToFetch = (widget.slug?.isNotEmpty ?? false)
        ? widget.slug!
        : (widget.article.slug.isNotEmpty
            ? widget.article.slug
            : (widget.article.id.isNotEmpty ? widget.article.id : article.slug));
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
      final fullArticle = await NewsArticleRepository.instance.getDetail(slugToFetch);
      debugPrint('Detail API success for slug "$slugToFetch". Body length: ${fullArticle.body.length}');
      debugPrint('Detail API content preview for slug "$slugToFetch": ${fullArticle.body.isNotEmpty ? fullArticle.body.substring(0, fullArticle.body.length > 140 ? 140 : fullArticle.body.length) : '(empty)'}');

      if (mounted) {
        setState(() {
          article = fullArticle;
          _isLoadingDetail = false;
        });
        if (article.isVideo && article.videoUrl.isNotEmpty) {
          unawaited(_initializeVideoIfNeeded());
        }
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

  void _initTts() async {
    String lang = AppState.instance.language.toLowerCase();
    String languageCode = 'en-US';
    if (lang == 'telugu') {
      languageCode = 'te-IN';
    } else if (lang == 'tamil') {
      languageCode = 'ta-IN';
    } else if (lang == 'kannada') {
      languageCode = 'kn-IN';
    } else if (lang == 'malayalam') {
      languageCode = 'ml-IN';
    } else if (lang == 'marathi') {
      languageCode = 'mr-IN';
    } else if (lang == 'bengali') {
      languageCode = 'bn-IN';
    } else if (lang == 'gujarati') {
      languageCode = 'gu-IN';
    }

    await flutterTts.setLanguage(languageCode);
    await flutterTts.setPitch(1.1); // Slightly higher pitch for smoother female voice
    await flutterTts.setSpeechRate(0.5); // Comfortable reading speed

    flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    _videoController?.dispose();
    super.dispose();
  }

  void _share() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    await ShareService.shareArticle(article);
    if (mounted) Navigator.pop(context); // dismiss loading
  }

  void _toggleAudio() async {
    if (isPlaying) {
      await flutterTts.stop();
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isPlaying = true;
        });
      }
      
      // Re-enforce language right before speaking
      String lang = AppState.instance.language.toLowerCase();
      String languageCode = 'en-US';
      if (lang == 'telugu') {
        languageCode = 'te-IN';
      } else if (lang == 'tamil') {
        languageCode = 'ta-IN';
      } else if (lang == 'kannada') {
        languageCode = 'kn-IN';
      } else if (lang == 'malayalam') {
        languageCode = 'ml-IN';
      } else if (lang == 'marathi') {
        languageCode = 'mr-IN';
      } else if (lang == 'bengali') {
        languageCode = 'bn-IN';
      } else if (lang == 'gujarati') {
        languageCode = 'gu-IN';
      }
      await flutterTts.setLanguage(languageCode);
      
      await flutterTts.speak(article.body);
    }
  }

  Future<void> _initializeVideoIfNeeded() async {
    if (!article.isVideo || article.videoUrl.isEmpty || _videoController != null) return;

    _videoController = VideoPlayerController.networkUrl(Uri.parse(article.videoUrl));
    await _videoController!.initialize();
    if (mounted) {
      setState(() {
        _isVideoInitialized = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    article = widget.article;
    _initTts();
    _fetchFullArticleDetail();
    if (article.isVideo && article.videoUrl.isNotEmpty) {
      _initializeVideoIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final mutedTextColor = isDark ? Colors.white60 : AppColors.textMuted;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF4F6F8),
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
                // Media Content
                if (article.isVideo && _videoController != null && _isVideoInitialized)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                      Positioned(
                        bottom: 40,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            article.formattedVideoDuration.isNotEmpty
                                ? article.formattedVideoDuration
                                : 'Video',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (article.imageUrls != null && article.imageUrls!.length > 1)
                  PageView.builder(
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemCount: article.imageUrls!.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: article.imageUrls![index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: AppColors.chipBg),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.chipBg,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 40),
                          ),
                        ),
                      );
                    },
                  )
                else
                  CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: AppColors.chipBg),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.chipBg,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 40),
                      ),
                    ),
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

                // Vaaradhi Logo Watermark (Bottom Right of Image)
                Positioned(
                  bottom: 44,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Vaaradhi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Image Carousel Counter (If multiple images)
                if (article.imageUrls != null && article.imageUrls!.length > 1)
                  Positioned(
                    bottom: 44,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1} / ${article.imageUrls!.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Frosted Header Action Bar (Top Floating Controls)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button (Frosted Circle)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),

                // Center Page Context Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Text(
                    article.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

                // Actions (Bookmark & Options)
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: AppState.instance,
                      builder: (context, _) {
                        final isBookmarked = AppState.instance.isBookmarked(article.id);
                        return GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            AppState.instance.toggleBookmark(article.id);
                            await ApiService.instance.toggleBookmark(article.id);
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isBookmarked ? AppColors.primary : Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                            ),
                            child: Icon(
                              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _toggleAudio();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isPlaying ? AppColors.primary : AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: isPlaying ? 1.0 : 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                    size: 20,
                                    color: isPlaying ? Colors.white : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isPlaying ? 'Stop Audio' : 'Listen Article',
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
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                              ),
                              child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 20),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Main Article Title (Headline)
                      Text(
                        article.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Author & Timestamp Row
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: mutedTextColor),
                          const SizedBox(width: 4),
                          Text(
                            article.timeAgo,
                            style: TextStyle(fontSize: 13, color: mutedTextColor, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 12),
                          Text('•', style: TextStyle(color: mutedTextColor)),
                          const SizedBox(width: 12),
                          Icon(Icons.menu_book_rounded, size: 14, color: mutedTextColor),
                          const SizedBox(width: 4),
                          Text(
                            '${article.readTimeMinutes} min read',
                            style: TextStyle(fontSize: 13, color: mutedTextColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Metric Pill Bar (Likes, Comments, Views & Share Option)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Likes Metric Pill
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => article.isLiked = !article.isLiked);
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    article.isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                    color: article.isLiked ? AppColors.primary : mutedTextColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${article.likes + (article.isLiked ? 1 : 0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: article.isLiked ? AppColors.primary : textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(width: 1, height: 16, color: isDark ? Colors.white12 : Colors.black12),

                            // Comments Metric Pill
                            AnimatedBuilder(
                              animation: AppState.instance,
                              builder: (context, _) {
                                final count = AppState.instance.getDisplayCommentCount(article.id, article.comments);
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => CommentsScreen(article: article)),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline_rounded, color: mutedTextColor, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$count',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            Container(width: 1, height: 16, color: isDark ? Colors.white12 : Colors.black12),

                            // Views Metric Pill
                            Row(
                              children: [
                                Icon(Icons.remove_red_eye_outlined, color: mutedTextColor, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '${article.viewCount}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ],
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
                              const Text(
                                'Failed to load full article content.',
                                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _fetchFullArticleDetail,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                              ),
                              const SizedBox(height: 12),
                              if (article.summary.isNotEmpty)
                                Text(
                                  article.summary,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.7,
                                    color: textColor.withValues(alpha: 0.85),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        Text(
                          article.body.isNotEmpty ? article.body : (article.summary.isNotEmpty ? article.summary : 'No content available.'),
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.75,
                            letterSpacing: 0.2,
                            color: textColor.withValues(alpha: 0.9),
                          ),
                        ),
                        
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
}
