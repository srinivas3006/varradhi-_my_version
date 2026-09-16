import '../core/utils/date_parser.dart';
import '../core/media/media_resolver.dart';
import '../core/utils/url_normalizer.dart';

int _toInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString().trim()) ?? fallback;
}

class NewsArticle {
  final String id;
  final String title;
  final String slug;
  final String summary;
  final String body;
  final String imageUrl;
  final String source;
  final String category;
  final DateTime publishedAt;
  int likes;

  /// Sent by the backend as `dislike_count`; previously dropped on the floor,
  /// which is why the dislike button had no number beside it.
  final int dislikes;
  final int comments;
  final int shares;
  final int readTimeMinutes;
  final int viewCount;
  final String? state;
  final String? district;
  final String? subdistrict;
  final String? village;
  final bool isBreaking;
  final bool isRegional;
  final List<String>? imageUrls;
  final String mediaType;
  final String videoUrl;
  final int videoDurationSeconds;
  final bool hasMore;
  final String coverageLevel;
  final String authorName;
  final String language;
  final bool isFeatured;
  final List<MediaItem> mediaItems;
  final String contentKind;
  bool isLiked;
  bool isBookmarked;

  NewsArticle({
    required this.id,
    required this.title,
    this.slug = '',
    required this.summary,
    required this.body,
    required this.imageUrl,
    required this.source,
    required this.category,
    required this.publishedAt,
    required this.likes,
    this.dislikes = 0,
    required this.comments,
    required this.shares,
    required this.readTimeMinutes,
    required this.viewCount,
    this.state,
    this.district,
    this.subdistrict,
    this.village,
    this.isBreaking = false,
    this.isRegional = false,
    this.imageUrls,
    this.mediaType = 'image',
    this.videoUrl = '',
    this.videoDurationSeconds = 0,
    this.hasMore = false,
    this.coverageLevel = 'global',
    this.authorName = '',
    this.language = 'te',
    this.isFeatured = false,
    this.mediaItems = const [],
    this.contentKind = 'article',
    this.isLiked = false,
    this.isBookmarked = false,
  });

  factory NewsArticle.placeholder({String slug = '', String title = ''}) {
    return NewsArticle(
      id: slug.isNotEmpty ? slug : 'placeholder',
      title: title.isNotEmpty ? title : 'News Update',
      slug: slug,
      summary: '',
      body: '',
      imageUrl: '',
      source: 'Vaaradhi',
      category: 'General',
      publishedAt: DateTime.now(),
      likes: 0,
      comments: 0,
      shares: 0,
      readTimeMinutes: 1,
      viewCount: 0,
    );
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    String extractString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }

      final nested = json['article'];
      if (nested is Map<String, dynamic>) {
        for (final key in keys) {
          final value = nested[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }
      }

      return '';
    }

    String rawImgUrl =
        (json['thumbnail_url'] ?? json['image_url'] ?? json['imageUrl'])
                ?.toString() ??
            '';
    final rawVid =
        extractString(['video_url', 'youtube_url', 'youtube_video_id']);

    if (rawImgUrl.isEmpty && rawVid.isNotEmpty) {
      final ytThumb = UrlNormalizer.extractYoutubeThumbnail(rawVid) ??
          _youtubeThumbnailFromId(rawVid);
      if (ytThumb != null) {
        rawImgUrl = ytThumb;
      }
    }

    final normalizedImgUrl = UrlNormalizer.normalize(rawImgUrl);

    final resolvedVideoUrl = _resolveVideoUrl(json);

    // Safe list of media items
    List<MediaItem> parsedMediaItems = [];
    if (json['media_items'] is List) {
      for (final item in (json['media_items'] as List)) {
        if (item is Map<String, dynamic>) {
          parsedMediaItems.add(MediaItem.fromJson(item));
        }
      }
    }

    // Media type resolution
    final rawMediaType =
        json['media_type']?.toString().trim().toLowerCase() ?? '';
    final isVid = (rawMediaType == 'video') ||
        rawMediaType.startsWith('video') ||
        rawMediaType.contains('video') ||
        resolvedVideoUrl.isNotEmpty ||
        json['is_video'] == true ||
        parsedMediaItems.any((m) => m.isVideo);

    final mediaType =
        isVid ? 'video' : (rawMediaType.isNotEmpty ? rawMediaType : 'image');

    // Safe Category parsing
    String parsedCategory = 'News';
    if (json['category'] is Map) {
      parsedCategory = json['category']['name']?.toString() ?? 'News';
    } else if (json['category_name'] != null) {
      parsedCategory = json['category_name'].toString();
    } else if (json['category'] != null) {
      parsedCategory = json['category'].toString();
    }

    return NewsArticle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      summary: extractString(['summary', 'description', 'excerpt']),
      body: extractString(['content', 'body', 'content_html', 'body_html']),
      imageUrl: normalizedImgUrl,
      source: json['source_name']?.toString() ??
          json['source']?.toString() ??
          'Vaaradhi',
      category: parsedCategory,
      publishedAt: DateParser.tryParse(json['published_at']) ?? DateTime.now(),
      likes: _toInt(json['likes_count'] ?? json['likes']),
      dislikes: _toInt(json['dislike_count'] ?? json['dislikes_count'] ?? json['dislikes']),
      comments: _toInt(json['comments_count'] ?? json['comments']),
      shares: _toInt(json['shares_count'] ?? json['shares']),
      readTimeMinutes: _toInt(json['read_time_minutes'], 2),
      viewCount: _toInt(json['view_count'] ?? json['views_count']),
      state: json['state']?.toString(),
      district: json['district']?.toString(),
      subdistrict: json['subdistrict']?.toString(),
      village: json['village']?.toString(),
      isBreaking: json['is_breaking'] == true,
      isRegional: json['is_regional'] == true,
      imageUrls: (json['image_urls'] as List?)
          ?.map((e) => UrlNormalizer.normalize(e?.toString()))
          .where((e) => e.isNotEmpty)
          .toList(),
      mediaType: mediaType,
      videoUrl: resolvedVideoUrl,
      videoDurationSeconds: _toInt(json['video_duration_seconds']),
      isLiked: json['is_liked_by_user'] == true ||
          json['is_liked'] == true ||
          json['my_reaction'] == 'like' ||
          json['reaction_type'] == 'like',
      isBookmarked: json['is_bookmarked_by_user'] == true ||
          json['is_bookmarked'] == true,
      hasMore: json['has_more'] == true ||
          json['hasMore'] == true ||
          (json['article'] is Map &&
              (json['article']['has_more'] == true ||
                  json['article']['hasMore'] == true)),
      coverageLevel:
          json['coverage_level']?.toString().toLowerCase() ?? 'global',
      authorName: _sanitizeAuthor(
        json['author_name']?.toString() ??
            (json['author'] is Map ? json['author']['name']?.toString() : null) ??
            json['source_name']?.toString() ??
            json['source']?.toString(),
      ),
      language:
          json['language']?.toString() ?? json['lang']?.toString() ?? 'te',
      isFeatured: json['is_featured'] == true,
      mediaItems: parsedMediaItems,
      contentKind: _parseContentKind(json),
    );
  }

  static String _parseContentKind(Map<String, dynamic> json) {
    final value = (json['feed_item_type'] ?? json['type'])
        ?.toString()
        .trim()
        .toLowerCase();
    return const {'article', 'ugc', 'live'}.contains(value)
        ? value!
        : 'article';
  }

  static String _sanitizeAuthor(String? raw) {
    if (raw == null) return 'VARADHI Desk';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    if (lower.isEmpty || lower.contains('john') || lower == 'null') {
      return 'VARADHI Desk';
    }
    return trimmed;
  }

  /// Resolves the effective video URL whether at top-level or within media items.
  String get effectiveVideoUrl {
    if (videoUrl.isNotEmpty) return videoUrl;
    for (final item in mediaItems) {
      if (item.isVideo && item.url.isNotEmpty) return item.url;
    }
    return '';
  }

  /// One parent record owns this ordered media list; it is never a feed list.
  List<MediaItem> get orderedMedia {
    final effectiveVid = effectiveVideoUrl;
    if (mediaItems.isNotEmpty) {
      if (effectiveVid.isNotEmpty &&
          !mediaItems.any((m) => m.isVideo || m.url == effectiveVid)) {
        return [
          MediaItem(
            mediaType: 'video',
            url: effectiveVid,
            thumbnailUrl: imageUrl,
            isPrimary: true,
          ),
          ...mediaItems,
        ];
      }
      return mediaItems;
    }
    final result = <MediaItem>[];
    if (effectiveVid.isNotEmpty) {
      result.add(MediaItem(
        mediaType: 'video',
        url: effectiveVid,
        thumbnailUrl: imageUrl,
        isPrimary: true,
      ));
    }
    for (final url in imageUrls ?? <String>[]) {
      if (url.isNotEmpty && !result.any((item) => item.url == url)) {
        result.add(MediaItem(mediaType: 'image', url: url, thumbnailUrl: url));
      }
    }
    if (result.isEmpty && imageUrl.isNotEmpty) {
      result.add(
          MediaItem(mediaType: 'image', url: imageUrl, thumbnailUrl: imageUrl));
    }
    return result;
  }

  bool get isUgc => contentKind == 'ugc';

  bool get isVideo =>
      (mediaType == 'video' ||
          mediaType.startsWith('video') ||
          mediaType.contains('video') ||
          videoUrl.isNotEmpty ||
          mediaItems.any((m) => m.isVideo)) &&
      effectiveVideoUrl.isNotEmpty;

  String get formattedVideoDuration {
    if (videoDurationSeconds <= 0) return '';
    final minutes = videoDurationSeconds ~/ 60;
    final seconds = videoDurationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 1) return 'ఇప్పుడే';
    if (diff.inMinutes < 60) return '${diff.inMinutes} నిమిషాల క్రితం';
    if (diff.inHours < 24) return '${diff.inHours} గంటల క్రితం';
    return '${diff.inDays} రోజుల క్రితం';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': body,
      'thumbnail_url': imageUrl,
      'source_name': source,
      'category': {'name': category},
      'published_at': publishedAt.toIso8601String(),
      'likes_count': likes,
      'dislike_count': dislikes,
      'comments_count': comments,
      'shares_count': shares,
      'read_time_minutes': readTimeMinutes,
      'view_count': viewCount,
      'state': state,
      'district': district,
      'subdistrict': subdistrict,
      'village': village,
      'is_breaking': isBreaking,
      'is_regional': isRegional,
      'image_urls': imageUrls,
      'media_type': mediaType,
      'video_url': videoUrl,
      'has_more': hasMore,
      'is_liked_by_user': isLiked,
      'is_bookmarked_by_user': isBookmarked,
      'feed_item_type': contentKind,
      'media_items': mediaItems.map((item) => item.toJson()).toList(),
    };
  }
}

String _resolveVideoUrl(Map<dynamic, dynamic> json) {
  String fromMap(Map<dynamic, dynamic> source) {
    final directVideoUrl = source['video_url']?.toString().trim() ?? '';
    if (directVideoUrl.isNotEmpty) return directVideoUrl;

    final youtubeUrl = source['youtube_url']?.toString().trim() ?? '';
    if (youtubeUrl.isNotEmpty) return youtubeUrl;

    final youtubeVideoId = MediaResolver.extractYoutubeVideoId(
        source['youtube_video_id']?.toString());
    if (youtubeVideoId != null) {
      return 'https://www.youtube.com/watch?v=$youtubeVideoId';
    }

    return '';
  }

  final topLevel = fromMap(json);
  if (topLevel.isNotEmpty) return topLevel;

  for (final key in ['metadata', 'article']) {
    final nested = json[key];
    if (nested is Map) {
      final value = fromMap(nested);
      if (value.isNotEmpty) return value;
    }
  }
  final media = json['media_items'];
  if (media is List) {
    for (final raw in media.whereType<Map>()) {
      final item = MediaItem.fromJson(Map<String, dynamic>.from(raw));
      if (item.isVideo && item.url.isNotEmpty) return item.url;
    }
  }
  final mediaUrl = json['media_url']?.toString() ?? '';
  final candidate = MediaItem(
      mediaType: json['media_type']?.toString().toLowerCase() ?? '',
      url: mediaUrl,
      thumbnailUrl: '');
  if (mediaUrl.isNotEmpty && (candidate.isVideo || json['type'] == 'live'))
    return mediaUrl;
  return '';
}

String? _youtubeThumbnailFromId(String rawValue) {
  final youtubeVideoId = MediaResolver.extractYoutubeVideoId(rawValue);
  if (youtubeVideoId == null) return null;
  return 'https://i.ytimg.com/vi/$youtubeVideoId/hqdefault.jpg';
}

class Comment {
  final String id;
  final String? articleId;
  final String? authorId;
  final String? parentId;
  final String username;
  final String avatarUrl;
  final String text;
  final DateTime postedAt;
  final String status;
  final String visibility;
  final DateTime? editedAt;
  int likes;
  bool isLikedByUser;
  bool isReported;
  final List<Comment> replies;

  Comment({
    required this.id,
    this.articleId,
    this.authorId,
    this.parentId,
    required this.username,
    required this.avatarUrl,
    required this.text,
    required this.postedAt,
    this.status = 'published',
    this.visibility = 'published',
    this.editedAt,
    this.likes = 0,
    this.isLikedByUser = false,
    this.isReported = false,
    List<Comment>? replies,
  }) : replies = replies ?? [];

  factory Comment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    var authorName =
        author?['display_name'] ?? json['username'] ?? 'Anonymous';
    if (authorName.toString().toLowerCase().contains('john')) {
      authorName = 'Reader';
    }
    final authorId = author?['id']?.toString();
    final repliesList = (json['replies'] as List<dynamic>?)
            ?.map((r) => Comment.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    final createdAtStr = json['created_at'] ?? json['postedAt'];
    final createdAt = DateParser.tryParse(createdAtStr) ?? DateTime.now();
    final editedAt = DateParser.tryParse(json['edited_at']);

    return Comment(
      id: json['id']?.toString() ?? '',
      articleId: json['article_id']?.toString(),
      authorId: authorId,
      parentId: json['parent_id']?.toString(),
      username: authorName.toString(),
      avatarUrl: UrlNormalizer.normalize(
        (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
        fallback: '',
      ),
      text: json['content']?.toString() ?? json['text']?.toString() ?? '',
      postedAt: createdAt,
      status: json['status']?.toString() ?? 'published',
      visibility: json['visibility']?.toString() ?? 'published',
      editedAt: editedAt,
      likes: _toInt(json['likes_count'] ?? json['likes']),
      isLikedByUser: json['is_liked'] == true || json['isLikedByUser'] == true,
      isReported: json['is_reported'] == true || json['isReported'] == true,
      replies: repliesList,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(postedAt);
    if (diff.inMinutes < 1) return 'ఇప్పుడే';
    if (diff.inMinutes < 60) return '${diff.inMinutes} నిమిషాల క్రితం';
    if (diff.inHours < 24) return '${diff.inHours} గంటల క్రితం';
    return '${diff.inDays} రోజుల క్రితం';
  }
}

class MediaItem {
  final String mediaType; // 'image' or 'video'
  final String url;
  final String thumbnailUrl;
  final int sortOrder;
  final bool isPrimary;

  const MediaItem({
    required this.mediaType,
    required this.url,
    required this.thumbnailUrl,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final rawType =
        (json['media_type'] ?? json['type'])?.toString().toLowerCase().trim() ??
            '';
    final mType = (rawType == 'video' ||
            rawType.startsWith('video') ||
            rawType.contains('video'))
        ? 'video'
        : (rawType.isNotEmpty ? rawType : 'image');
    final youtubeVideoId = MediaResolver.extractYoutubeVideoId(
      json['youtube_video_id']?.toString() ?? json['youtube_url']?.toString(),
    );
    final youtubeUrl = youtubeVideoId == null
        ? ''
        : 'https://www.youtube.com/watch?v=$youtubeVideoId';
    final rawUrl = (json['url'] ??
            json['media_url'] ??
            json['file_url'] ??
            json['video_url'] ??
            json['image_url'])
        ?.toString();
    final urlStr = rawUrl == null || rawUrl.trim().isEmpty
        ? youtubeUrl
        : UrlNormalizer.normalize(rawUrl);
    final youtubeThumb = youtubeVideoId == null
        ? ''
        : 'https://i.ytimg.com/vi/$youtubeVideoId/hqdefault.jpg';
    final thumbStr = UrlNormalizer.normalize(
      json['thumbnail_url']?.toString(),
      fallback: youtubeThumb.isNotEmpty
          ? youtubeThumb
          : (mType == 'video' ? '' : urlStr),
    );
    final order = _toInt(json['sort_order'], 0);
    return MediaItem(
      mediaType: mType,
      url: urlStr,
      thumbnailUrl: thumbStr,
      sortOrder: order,
      isPrimary: json['is_primary'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'media_type': mediaType,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'sort_order': sortOrder,
        'is_primary': isPrimary,
      };

  bool get isVideo {
    final m = mediaType.toLowerCase().trim();
    if (m == 'video' || m.startsWith('video') || m.contains('video')) return true;
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return const ['.mp4', '.m3u8', '.mov', '.webm', '.mkv', '.m4v']
            .any(path.endsWith) ||
        url.toLowerCase().contains('.mp4') ||
        MediaResolver.extractYoutubeVideoId(url) != null;
  }
}
