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
