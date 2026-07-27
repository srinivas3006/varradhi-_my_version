class VideoItem {
  final String id;
  final String title;
  final String channel;
  final String thumbnailUrl;
  final String? videoUrl;
  final String? youtubeVideoId;
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
    this.youtubeVideoId,
    required this.views,
    required this.duration,
    required this.likes,
    this.isLiked = false,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    // Convert duration seconds if present
    String durationStr = '0:00';
    if (json['duration_seconds'] != null) {
      final int seconds = json['duration_seconds'] as int;
      final int m = seconds ~/ 60;
      final int s = seconds % 60;
      durationStr = '$m:${s.toString().padLeft(2, '0')}';
    } else if (json['duration'] != null) {
      durationStr = json['duration'].toString();
    }

    return VideoItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      channel: json['channel_name'] ?? json['source_name'] ?? json['channel'] ?? 'VARADHI Video',
      thumbnailUrl: json['thumbnail_url'] ?? json['image_url'] ?? '',
      videoUrl: json['video_url'] ?? json['youtube_url'],
      youtubeVideoId: json['youtube_video_id'],
      views: json['views_count']?.toString() ?? json['views']?.toString() ?? '0',
      duration: durationStr,
      likes: json['likes_count'] ?? json['likes'] ?? 0,
      isLiked: json['is_liked_by_user'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'channel_name': channel,
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
      'youtube_video_id': youtubeVideoId,
      'views_count': views,
      'duration': duration,
      'likes_count': likes,
      'is_liked_by_user': isLiked,
    };
  }
}
