import '../core/utils/date_parser.dart';
import 'news_article.dart';

/// One row of `GET /api/v1/bookmarks/` — the combined saved list, articles
/// and citizen posts together (bookmark handover §5).
///
/// [id] is the bookmark's own id, used only for
/// `DELETE /api/v1/bookmarks/{id}/`. [contentId] is the article or citizen
/// post, used for navigation and for the bookmark state every screen reads.
class SavedItem {
  const SavedItem({
    required this.id,
    required this.contentId,
    required this.feedItemType,
    required this.story,
    this.createdAt,
    this.onDevice = false,
  });

  /// A guest's bookmark kept on this phone (no server bookmark id yet).
  factory SavedItem.onDevice(NewsArticle story) {
    final contentId = story.id.isNotEmpty ? story.id : story.slug;
    return SavedItem(
      id: 'device:$contentId',
      contentId: contentId,
      feedItemType: story.isUgc ? 'ugc' : 'article',
      story: story..isBookmarked = true,
      onDevice: true,
    );
  }

  /// True for a guest bookmark kept on the phone rather than on the server.
  final bool onDevice;

  final String id;
  final String contentId;

  /// `article` or `ugc`: which of the row's `article` / `ugc` objects is set.
  final String feedItemType;

  /// The saved article or citizen post, parsed into the app's story model.
  final NewsArticle story;

  final DateTime? createdAt;

  bool get isUgc => feedItemType == 'ugc';

  factory SavedItem.fromJson(Map<String, dynamic> json) {
    final type = (json['feed_item_type']?.toString().toLowerCase() ??
        (json['ugc'] is Map ? 'ugc' : 'article'));
    final nested = type == 'ugc' ? json['ugc'] : json['article'];
    final content = nested is Map
        ? Map<String, dynamic>.from(nested)
        // Older article-only rows carried the article fields flat.
        : Map<String, dynamic>.from(json);

    final contentId = json['content_id']?.toString() ??
        (nested is Map ? content['id']?.toString() : null) ??
        json['article_id']?.toString() ??
        '';
    if (contentId.isNotEmpty) content['id'] = contentId;
    content['feed_item_type'] = type;
    content['is_bookmarked'] = true;

    return SavedItem(
      id: json['id']?.toString() ?? '',
      contentId: contentId,
      feedItemType: type,
      story: NewsArticle.fromJson(content),
      createdAt: DateParser.tryParse(json['created_at']),
    );
  }
}
