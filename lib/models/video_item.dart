class VideoItem {
  final String id;
  final String title;
  final String channel;
  final String thumbnailUrl;
  final String? videoUrl;
  final String views;
  final String duration;
  final int likes;
  bool isLiked;

  VideoItem({
    required this.id,
    required this.title,
    required this.channel,
    required this.thumbnailUrl,
    this.videoUrl,
    required this.views,
    required this.duration,
    required this.likes,
    this.isLiked = false,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      channel: json['source_name'] ?? json['channel'] ?? 'VARADHI Video',
      thumbnailUrl: json['thumbnail_url'] ?? json['image_url'] ?? '',
      videoUrl: json['video_url'],
      views: json['views_count']?.toString() ?? json['views']?.toString() ?? '0',
      duration: json['duration'] ?? '0:00',
      likes: json['likes_count'] ?? json['likes'] ?? 0,
      isLiked: json['is_liked_by_user'] ?? false,
    );
  }
}
