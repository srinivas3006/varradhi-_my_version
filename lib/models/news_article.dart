class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String body;
  final String imageUrl;
  final String source;
  final String category;
  final DateTime publishedAt;
  final int likes;
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
  bool isLiked;
  bool isBookmarked;

  NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.imageUrl,
    required this.source,
    required this.category,
    required this.publishedAt,
    required this.likes,
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
    this.isLiked = false,
    this.isBookmarked = false,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      body: json['content'] ?? json['body'] ?? '',
      imageUrl: json['thumbnail_url'] ?? json['image_url'] ?? json['imageUrl'] ?? '',
      source: json['source_name'] ?? json['source'] ?? 'VARADHI Desk',
      category: json['category'] is Map 
          ? (json['category']['name'] ?? 'News') 
          : (json['category_name'] ?? json['category']?.toString() ?? 'News'),
      publishedAt: json['published_at'] != null 
          ? DateTime.parse(json['published_at']) 
          : DateTime.now(),
      likes: json['likes_count'] ?? json['likes'] ?? 0,
      comments: json['comments_count'] ?? json['comments'] ?? 0,
      shares: json['shares_count'] ?? json['shares'] ?? 0,
      readTimeMinutes: json['read_time_minutes'] ?? 2,
      viewCount: json['view_count'] ?? json['views_count'] ?? 0,
      state: json['state'],
      district: json['district'],
      subdistrict: json['subdistrict'],
      village: json['village'],
      isBreaking: json['is_breaking'] ?? false,
      isRegional: json['is_regional'] ?? false,
      imageUrls: (json['image_urls'] as List?)?.map((e) => e.toString()).toList(),
      isLiked: json['is_liked_by_user'] ?? false,
      isBookmarked: json['is_bookmarked_by_user'] ?? false,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
      'is_liked_by_user': isLiked,
      'is_bookmarked_by_user': isBookmarked,
    };
  }
}

class Comment {
  final String id;
  final String username;
  final String avatarUrl;
  final String text;
  final DateTime postedAt;
  int likes;
  bool isLikedByUser;
  bool isReported;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.text,
    required this.postedAt,
    this.likes = 0,
    this.isLikedByUser = false,
    this.isReported = false,
    List<Comment>? replies,
  }) : replies = replies ?? [];

  String get timeAgo {
    final diff = DateTime.now().difference(postedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
