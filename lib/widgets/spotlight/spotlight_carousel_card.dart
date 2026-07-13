import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/spotlight_item.dart';
import '../../theme/app_theme.dart';
import '../../screens/comments_screen.dart';
import '../../state/app_state.dart';

class SpotlightCarouselCard extends StatefulWidget {
  final SpotlightItem item;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onClose;

  const SpotlightCarouselCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onShare,
    required this.onClose,
  });

  @override
  State<SpotlightCarouselCard> createState() => _SpotlightCarouselCardState();
}

class _SpotlightCarouselCardState extends State<SpotlightCarouselCard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: AppColors.textDark),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconPill({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.item.article!;
    final images = widget.item.imageUrls!;

    return GestureDetector(
      onTap: widget.onTap,
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
            // Image Carousel
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: images[index],
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
                  ),
                  
                  // Top Gradient & Actions
                  Positioned(
                    top: 0, left: 0, right: 0,
                    height: 120,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8 + MediaQuery.of(context).padding.top, right: 8,
                    child: _iconPill(
                      icon: Icons.close_rounded,
                      onTap: widget.onClose,
                    ),
                  ),

                  // Carousel Dots Indicator
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentIndex == index ? 8 : 6,
                          height: _currentIndex == index ? 8 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentIndex == index ? AppColors.primary : Colors.white.withValues(alpha: 0.5),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title ?? article.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    
                    // Bottom Info & Actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.chipBg,
                                    child: Text(
                                      article.source.isNotEmpty ? article.source[0] : '?',
                                      style: const TextStyle(color: AppColors.textDark, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      article.source,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textDark),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                article.timeAgo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action Buttons
                        Row(
                          children: [
                            _actionButton(
                              icon: Icons.report_outlined,
                              label: 'Report',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Reported for review.')),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            AnimatedBuilder(
                              animation: AppState.instance,
                              builder: (context, _) {
                                final count = AppState.instance.getCommentCount(article.id);
                                return _actionButton(
                                  icon: Icons.mode_comment_outlined,
                                  label: _formatCount(count),
                                  onTap: () {
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
                            const SizedBox(width: 16),
                            _actionButton(
                              icon: Icons.share_outlined,
                              label: _formatCount(article.shares),
                              onTap: widget.onShare,
                            ),
                          ],
                        ),
                      ],
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
}
