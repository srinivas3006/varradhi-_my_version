import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/news_article.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_service.dart';
import 'comments_screen.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;

  const NewsDetailScreen({super.key, required this.article});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late NewsArticle article;
  final FlutterTts flutterTts = FlutterTts();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    article = widget.article;
    _initTts();
  }

  void _initTts() async {
    String lang = AppState.instance.language.toLowerCase();
    String languageCode = 'en-US';
    if (lang == 'telugu') {
      languageCode = 'te-IN';
    } else if (lang == 'hindi') {
      languageCode = 'hi-IN';
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
      } else if (lang == 'hindi') {
        languageCode = 'hi-IN';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: isDark ? Colors.white : AppColors.textDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  article.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: () =>
                    setState(() => article.isBookmarked = !article.isBookmarked),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: _share,
              ),
              const SizedBox(width: 6),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _toggleAudio,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded, 
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(isPlaying ? 'Stop' : 'Listen', 
                                  style: TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w700, 
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isDark ? AppColors.chipBgDark : AppColors.chipBg,
                        child: Text(
                          article.source.isNotEmpty ? article.source[0] : '?',
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        article.source,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      const SizedBox(width: 8),
                      const Text('·', style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      Text(
                        article.timeAgo,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const Spacer(),
                      Text(
                        '${article.readTimeMinutes} min read',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    article.body,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.65,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statButton(
                        icon: article.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: 'Like',
                        active: article.isLiked,
                        onTap: () =>
                            setState(() => article.isLiked = !article.isLiked),
                      ),
                      _statButton(
                        icon: Icons.mode_comment_outlined,
                        label: 'Comment',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommentsScreen(article: article),
                            ),
                          );
                        },
                      ),
                      _statButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: _share,
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

  Widget _statButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon,
                color: active ? AppColors.primary : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
