import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/news_article.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../screens/comments_screen.dart';
import '../../services/api_service.dart';
import '../../repositories/news_article_repository.dart';

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
  bool _isAudioPlaying = false;
  bool _isDisliked = false;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isLoadingDetail = false;
  String? _detailError;
  NewsArticle? _detailArticle;

  @override
  void initState() {
    super.initState();
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isAudioPlaying = false);
      }
    });
    // Fetch full article detail (content) using slug or id from feed item.
    final slugToFetch = widget.article.slug.isNotEmpty ? widget.article.slug : widget.article.id;
    if (slugToFetch.isNotEmpty) {
      _fetchArticleDetail(slugToFetch);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _fetchArticleDetail(String slug) async {
    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      debugPrint('Spotlight: fetching detail for slug: $slug');
      final full = await NewsArticleRepository.instance.getDetail(slug);
      debugPrint('Spotlight: detail fetched for $slug. content length: ${full.body.length}');
      if (mounted) {
        setState(() {
          _detailArticle = full;
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      debugPrint('Spotlight: failed to fetch detail for $slug: $e');
      if (mounted) {
        setState(() {
          _detailError = e.toString();
          _isLoadingDetail = false;
        });
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isAudioPlaying) {
      await _flutterTts.stop();
      if (mounted) {
        setState(() => _isAudioPlaying = false);
      }
    } else {
      if (mounted) {
        setState(() => _isAudioPlaying = true);
      }
      
      final lang = AppState.instance.language;
      String code = "en-IN";
      if (lang == 'Telugu') {
        code = "te-IN";
      } else if (lang == 'Tamil') {
        code = "ta-IN";
      }
      await _flutterTts.setLanguage(code);

      await _flutterTts.speak("${widget.article.title}. ${widget.article.summary}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaHeight = MediaQuery.of(context).size.height * 0.38;
    
    // Parallax Animation Values
    final textOpacity = widget.isCurrent ? (1.0 - widget.dragProgress) : widget.dragProgress;
    final imageOpacity = widget.isCurrent ? (1.0 - widget.matchCutProgress) : widget.matchCutProgress;
    final imageScale = widget.isCurrent ? 1.0 : (0.95 + 0.05 * widget.matchCutProgress);

    final headlineOffset = widget.dragDelta * 1.0;
    final bodyOffset = widget.dragDelta * 0.85;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          // 1. IMAGE ZONE (Top 38% with Parallax)
          Positioned(
            top: 0, left: 0, right: 0, height: mediaHeight,
            child: Transform.translate(
              offset: Offset(0, widget.dragDelta * 0.5), // Subtle image parallax
              child: Opacity(
                opacity: imageOpacity,
                child: Transform.scale(
                  scale: imageScale,
                  child: GestureDetector(
                    onDoubleTap: () {
                      HapticFeedback.mediumImpact();
                      if (!AppState.instance.likedItemIds.contains(article.id)) {
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
                          imageUrl: article.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: AppColors.chipBg),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.chipBg,
                            child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
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
                                Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                                Theme.of(context).scaffoldBackgroundColor,
                              ],
                              stops: const [0.6, 0.9, 1.0],
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
                          // Audio Chip
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _toggleAudio();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isAudioPlaying
                                      ? AppColors.primary
                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isAudioPlaying
                                        ? AppColors.primary
                                        : (isDark ? Colors.white24 : Colors.black12),
                                  ),
                                ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isAudioPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                                    size: 16,
                                    color: _isAudioPlaying ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isAudioPlaying ? 'Playing' : 'Listen',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _isAudioPlaying ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Right: Breaking + Location + Time
                          Row(
                            children: [
                              if (article.isBreaking) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('BREAKING', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                article.timeAgo,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
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
                    
                    const SizedBox(height: 12),
                    
                    // Body Text (load full content from detail API)
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(0, bodyOffset),
                        child: Builder(builder: (context) {
                          final content = _detailArticle?.body ?? '';

                          if (_isLoadingDetail && content.isEmpty) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (_detailError != null && content.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Failed to load full article content.', style: TextStyle(color: Colors.redAccent)),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _fetchArticleDetail(widget.article.slug),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry'),
                                ),
                                const SizedBox(height: 12),
                                // Fallback to summary if available
                                if (article.summary.isNotEmpty)
                                  Text(
                                    _truncateBody(article.summary, 350),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark ? Colors.white70 : AppColors.textDark.withValues(alpha: 0.85),
                                      height: 1.55,
                                    ),
                                  ),
                              ],
                            );
                          }

                          final toShow = content.isNotEmpty ? content : article.summary;
                          return Text(
                            _truncateBody(toShow, 350),
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : AppColors.textDark.withValues(alpha: 0.85),
                              height: 1.55,
                            ),
                          );
                        }),
                      ),
                    ),
                    
                    // Action Bar (Bottom)
                    Transform.translate(
                      offset: Offset(0, bodyOffset),
                      child: Padding(
                                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24, top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Like
                            AnimatedBuilder(
                              animation: AppState.instance,
                              builder: (context, _) {
                                final isLiked = AppState.instance.likedItemIds.contains(article.id);
                                return _buildActionIcon(
                                  icon: isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                  color: isLiked ? AppColors.primary : AppColors.textMuted,
                                  label: _formatCount(article.likes + (isLiked ? 1 : 0)),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    AppState.instance.toggleLike(article.id);
                                  },
                                );
                              }
                            ),
                            // Dislike
                            _buildActionIcon(
                              icon: Icons.thumb_down_alt_outlined,
                              color: _isDisliked ? Colors.red : AppColors.textMuted,
                              label: '',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _isDisliked = !_isDisliked);
                                if (_isDisliked) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text('Feedback received'),
                                    duration: Duration(seconds: 1),
                                  ));
                                }
                              },
                            ),
                            // Share (Center, Prominent)
                            GestureDetector(
                              onTap: widget.onShare,
                                child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 24),
                              ),
                            ),
                            // Comment
                            AnimatedBuilder(
                              animation: AppState.instance,
                              builder: (context, _) {
                                final count = AppState.instance.getDisplayCommentCount(article.id, article.comments);
                                return _buildActionIcon(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  color: AppColors.textMuted,
                                  label: _formatCount(count),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => CommentsScreen(article: article)),
                                    );
                                  },
                                );
                              }
                            ),
                            // Save
                            AnimatedBuilder(
                              animation: AppState.instance,
                              builder: (context, _) {
                                final isSaved = AppState.instance.isBookmarked(widget.article.id);
                                return _buildActionIcon(
                                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
                                  color: isSaved ? AppColors.primary : AppColors.textMuted,
                                  label: '',
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    AppState.instance.toggleBookmark(widget.article.id);
                                    await ApiService.instance.toggleBookmark(widget.article.id);
                                  },
                                );
                              }
                            ),
                          ],
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
    );
  }

  Widget _buildActionIcon({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count == 0) return '';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
  
  String _truncateBody(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
