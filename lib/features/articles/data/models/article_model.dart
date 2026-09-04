class ArticleModel {
  final String id;
  final String title;
  final String slug;
  final String summary;
  final String content;
  final String thumbnailUrl;
  final String categoryName;
  final String sourceName;
  final DateTime publishedAt;
  final bool isBreaking;
  final bool isFeatured;
  final bool isBookmarked;
  final String mediaType;
  final String videoUrl;
  final int videoDurationSeconds;

  ArticleModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.summary,
    required this.content,
    required this.thumbnailUrl,
    required this.categoryName,
    required this.sourceName,
    required this.publishedAt,
    required this.isBreaking,
    required this.isFeatured,
    required this.isBookmarked,
    this.mediaType = 'image',
    this.videoUrl = '',
    this.videoDurationSeconds = 0,
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    return ArticleModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      slug: json['slug']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      categoryName: json['category'] is Map
          ? (json['category']['display_name'] ?? json['category']['name'] ?? 'General')
          : (json['category_name']?.toString() ?? 'General'),
      sourceName: json['source_name']?.toString() ?? 'VARADHI Desk',
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? '') ?? DateTime.now(),
      isBreaking: json['is_breaking'] == true,
      isFeatured: json['is_featured'] == true,
      isBookmarked: json['is_bookmarked'] == true,
      mediaType: json['media_type']?.toString() ?? 'image',
      videoUrl: json['video_url']?.toString() ?? '',
      videoDurationSeconds: json['video_duration_seconds'] is int
          ? json['video_duration_seconds']
          : int.tryParse(json['video_duration_seconds']?.toString() ?? '0') ?? 0,
    );
  }

  bool get isVideo => mediaType == 'video' && videoUrl.isNotEmpty;

  String get formattedVideoDuration {
    if (videoDurationSeconds <= 0) return '';
    final minutes = videoDurationSeconds ~/ 60;
    final seconds = videoDurationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'summary': summary,
      'content': content,
      'thumbnail_url': thumbnailUrl,
      'category_name': categoryName,
      'source_name': sourceName,
      'published_at': publishedAt.toIso8601String(),
      'is_breaking': isBreaking,
      'is_featured': isFeatured,
      'is_bookmarked': isBookmarked,
      'media_type': mediaType,
      'video_url': videoUrl,
      'video_duration_seconds': videoDurationSeconds,
    };
  }
}
