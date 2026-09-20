import '../../models/news_article.dart';
import '../../models/video_item.dart';
import 'share_brand_config.dart';
import 'share_models.dart';

/// Turns the app's models into the one [ShareContent] shape.
///
/// Every screen goes through here, so a poster shared from the feed and the
/// same poster shared from its detail page produce identical text and URL.
class ShareContentBuilder {
  const ShareContentBuilder._();

  /// Canonical public HTTPS URL — the page the backend renders with Open
  /// Graph metadata, never the API host.
  ///
  /// Trailing slash is part of the contract: the backend routes
  /// /article/{slug}/ and /poster/{id}/.
  ///
  /// Returns null when the identifier is missing, so a caller shares nothing
  /// rather than a URL that cannot resolve.
  static String? canonicalUrl(ShareContentType type, String identifier) {
    final id = identifier.trim();
    if (id.isEmpty) return null;
    return '${ShareBrandConfig.website}/${type.route}/'
        '${Uri.encodeComponent(id)}/';
  }

  static ShareContent fromArticle(NewsArticle article) {
    final type =
        article.isUgc ? ShareContentType.ugc : ShareContentType.article;

    // The public article page is keyed on the slug, not the UUID — a UUID
    // there is a guaranteed 404. UGC is the opposite: it is keyed on the
    // submission id.
    final identifier =
        type == ShareContentType.ugc ? article.id : article.slug;

    return ShareContent(
      contentType: type,
      contentId: article.id,
      title: article.title.trim(),
      description: article.summary.trim(),
      imageUrl: _firstImage(article),
      videoUrl: article.effectiveVideoUrl.isEmpty
          ? null
          : article.effectiveVideoUrl,
      canonicalUrl: canonicalUrl(type, identifier),
      creator: article.authorName.isEmpty ? null : article.authorName,
      category: article.category,
      // NewsArticle carries no privacy flag: the feed only returns published
      // content, so anything reaching this builder is already shareable.
      // Moderation and visibility stay the backend's decision — the app does
      // not re-derive them.
      isPublic: true,
    );
  }

  static ShareContent fromUgc(NewsArticle post) => fromArticle(post);

  static ShareContent fromPoster(Map<String, dynamic> poster) {
    final id = (poster['id'] ?? poster['slug'] ?? '').toString();
    final images = poster['image_url'] ?? poster['media_url'];
    return ShareContent(
      contentType: ShareContentType.poster,
      contentId: id,
      title: (poster['title'] ?? 'Poster').toString().trim(),
      description: (poster['description'] ?? '').toString().trim(),
      imageUrl: images?.toString(),
      canonicalUrl: canonicalUrl(ShareContentType.poster, id),
      category: poster['category']?.toString(),
    );
  }

  static ShareContent fromPoll({
    required String id,
    required String question,
    String? imageUrl,
  }) {
    return ShareContent(
      contentType: ShareContentType.poll,
      contentId: id,
      title: question.trim(),
      imageUrl: imageUrl,
      canonicalUrl: canonicalUrl(ShareContentType.poll, id),
    );
  }

  static ShareContent fromVideo(VideoItem video) {
    final type =
        video.isShort ? ShareContentType.short : ShareContentType.video;
    return ShareContent(
      contentType: type,
      contentId: video.id,
      title: video.title.trim(),
      imageUrl: video.thumbnailUrl.isEmpty ? null : video.thumbnailUrl,
      videoUrl: video.youtubeUrl ?? video.videoUrl,
      canonicalUrl: canonicalUrl(type, video.id),
      category: video.channel.isEmpty ? null : video.channel,
    );
  }

  static ShareContent fromShort(VideoItem short) => fromVideo(short);

  static String? _firstImage(NewsArticle article) {
    if (article.mediaItems.isNotEmpty &&
        article.mediaItems.first.url.isNotEmpty) {
      return article.mediaItems.first.url;
    }
    return article.imageUrl.isEmpty ? null : article.imageUrl;
  }
}
