import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/news_article.dart';
import '../theme/app_theme.dart';
import 'news_article_video_player.dart';

/// The detail screen's horizontal media pager, shared with Spotlight and UGC.
/// The parent owns geometry; this widget owns only its internal media index.
class ArticleMediaCarousel extends StatefulWidget {
  final NewsArticle article;
  final bool active;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final BoxFit fit;
  const ArticleMediaCarousel(
      {super.key,
      required this.article,
      this.active = true,
      this.onPageChanged,
      this.onTap,
      this.onDoubleTap,
      this.fit = BoxFit.cover});
  @override
  State<ArticleMediaCarousel> createState() => _ArticleMediaCarouselState();
}

class _ArticleMediaCarouselState extends State<ArticleMediaCarousel> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _visible = false;
  final Key _visibilityKey = UniqueKey();

  @override
  void didUpdateWidget(covariant ArticleMediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _media(MediaItem item, int index) {
    if (item.isVideo) {
      return NewsArticleVideoPlayer(
        key: ValueKey(
            '${widget.article.contentKind}:${widget.article.id}:$index:${item.url}'),
        article: widget.article,
        media: item,
        isCurrent: widget.active && _visible && _index == index,
        onDoubleTap: widget.onDoubleTap,
        fit: BoxFit.contain,
      );
    }
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      child: CachedNetworkImage(
        imageUrl: item.url,
        fit: widget.fit,
        placeholder: (_, __) => Container(color: AppColors.chipBg),
        errorWidget: (_, __, ___) => Container(
            color: AppColors.chipBg,
            child: const Center(
                child: Icon(Icons.image_not_supported_outlined,
                    color: AppColors.textMuted, size: 40))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.article.orderedMedia;
    if (media.isEmpty)
      return const Center(child: Icon(Icons.image_not_supported_outlined));
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction >= 0.5;
        if (mounted && visible != _visible) setState(() => _visible = visible);
      },
      child: media.length == 1
          ? _media(media.first, 0)
          : PageView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                widget.onPageChanged?.call(index);
              },
              itemBuilder: (_, index) => _media(media[index], index),
            ),
    );
  }
}
