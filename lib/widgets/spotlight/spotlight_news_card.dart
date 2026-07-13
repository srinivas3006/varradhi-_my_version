import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/news_article.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../screens/comments_screen.dart';

class SpotlightNewsCard extends StatefulWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onClose;

  const SpotlightNewsCard({
    super.key,
    required this.article,
    required this.onTap,
    required this.onShare,
    required this.onClose,
  });

  @override
  State<SpotlightNewsCard> createState() => _SpotlightNewsCardState();
}

class _SpotlightNewsCardState extends State<SpotlightNewsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  
  int _currentImageIndex = 0;

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
    ]).animate(CurvedAnimation(parent: _heartController, curve: Curves.easeInOut));

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    _heartController.forward(from: 0.0);
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final hasMultipleImages = article.imageUrls != null && article.imageUrls!.length > 1;
    final images = hasMultipleImages ? article.imageUrls! : [article.imageUrl];

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                        : _buildImage(images[0]),
                  ),
                  Positioned(
                    top: 12 + MediaQuery.of(context).padding.top,
                    left: 12,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8 + MediaQuery.of(context).padding.top,
                    right: 8,
                    child: Row(
                      children: [
                        _iconPill(
                          icon: Icons.close_rounded,
                          onTap: widget.onClose,
                        ),
                      ],
                    ),
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
                  // Double tap heart animation
                  Center(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _heartController,
                        builder: (context, child) {
                          if (_heartOpacity.value == 0.0) return const SizedBox.shrink();
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
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.chipBg,
                          child: Text(
                            article.source.isNotEmpty
                                ? article.source[0]
                                : '?',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textDark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          article.source,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('·',
                            style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(width: 6),
                        Text(
                          article.timeAgo,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                        const Spacer(),
                        Text(
                          '${article.readTimeMinutes} min read',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        article.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _actionButton(
                          icon: Icons.report_outlined,
                          label: 'Report',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reported for review.')),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: AppState.instance,
                          builder: (context, _) {
                            final stateComments = AppState.instance.articleComments[article.id];
                            final count = stateComments != null 
                                ? AppState.instance.getCommentCount(article.id)
                                : article.comments;
                            return _actionButton(
                              icon: Icons.mode_comment_outlined,
                              label: _formatCount(count),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommentsScreen(article: article),
                                  ),
                                );
                              },
                            );
                          }
                        ),
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
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: AppColors.chipBg),
      errorWidget: (context, url, error) => Container(
        color: AppColors.chipBg,
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppColors.textMuted, size: 40),
      ),
    );
  }

  Widget _iconPill(
      {required IconData icon, required VoidCallback onTap, bool active = false}) {
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon,
              size: 19,
              color: active ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: active ? AppColors.primary : AppColors.textMuted,
              fontWeight: FontWeight.w500,
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
