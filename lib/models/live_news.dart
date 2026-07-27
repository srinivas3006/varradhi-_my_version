class LiveNews {
  final String id;
  final String title;
  final String youtubeUrl;
  final String youtubeVideoId;
  final String thumbnailUrl;
  final String description;
  final String channelName;
  final bool isActive;
  final bool autoplay;
  final int sortOrder;

  LiveNews({
    required this.id,
    required this.title,
    required this.youtubeUrl,
    required this.youtubeVideoId,
    required this.thumbnailUrl,
    required this.description,
    required this.channelName,
    required this.isActive,
    required this.autoplay,
    required this.sortOrder,
  });

  factory LiveNews.fromJson(Map<String, dynamic> json) {
    return LiveNews(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      youtubeUrl: json['youtube_url'] ?? '',
      youtubeVideoId: json['youtube_video_id'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      description: json['description'] ?? '',
      channelName: json['channel_name'] ?? 'VARADHI TV',
      isActive: json['is_active'] ?? false,
      autoplay: json['autoplay'] ?? false,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
