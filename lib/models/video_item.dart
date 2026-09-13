import '../core/media/media_resolver.dart';
import '../core/media/media_source.dart';
import '../core/utils/url_normalizer.dart';

int _toInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString().trim()) ?? fallback;
}

class VideoItem {
  final String id;
  final String title;
  final String channel;
  final String thumbnailUrl;
  final String? videoUrl;
  final String? youtubeUrl;
  final String? youtubeVideoId;
  final bool isShort;
  final int durationSeconds;
  final String duration;
  final int viewsCount;
  final String views;
  final int likesCount;
  final int likes;
  bool isLiked;

  VideoItem({
    required this.id,
    required this.title,
    required this.channel,
    required this.thumbnailUrl,
    this.videoUrl,
    this.youtubeUrl,
    this.youtubeVideoId,
    this.isShort = false,
    this.durationSeconds = 0,
    required this.duration,
    this.viewsCount = 0,
    required this.views,
    this.likesCount = 0,
    required this.likes,
    this.isLiked = false,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    // 1. Duration parsing
    int durationSecs = _toInt(json['duration_seconds']);
    String durationStr = '0:00';
    if (durationSecs > 0) {
      final int m = durationSecs ~/ 60;
      final int s = durationSecs % 60;
      durationStr = '$m:${s.toString().padLeft(2, '0')}';
    } else if (json['duration'] != null && json['duration'].toString().isNotEmpty) {
      durationStr = json['duration'].toString();
    }

    // 2. Video & YouTube URL resolution
    final rawYtUrl = json['youtube_url']?.toString();
    final rawVideoUrl = json['video_url']?.toString();
    String? resolvedYtId = MediaResolver.extractYoutubeVideoId(
      json['youtube_video_id']?.toString(),
    );

    if (resolvedYtId == null || resolvedYtId.isEmpty) {
      resolvedYtId = MediaResolver.extractYoutubeVideoId(rawYtUrl) ??
          MediaResolver.extractYoutubeVideoId(rawVideoUrl);
    }

    // 3. Normalize thumbnail
    String rawThumb = (json['thumbnail_url'] ?? json['image_url'] ?? '').toString();
    if (rawThumb.isEmpty && resolvedYtId != null && resolvedYtId.isNotEmpty) {
      rawThumb = 'https://i.ytimg.com/vi/$resolvedYtId/hqdefault.jpg';
    }
    final normalizedThumb = UrlNormalizer.normalize(rawThumb);

    // 4. Safe counts
    final viewsCnt = _toInt(json['views_count'] ?? json['views']);
    final likesCnt = _toInt(json['likes_count'] ?? json['likes']);
    final isShortVal = json['is_short'] == true ||
        (rawVideoUrl != null && rawVideoUrl.contains('/shorts/')) ||
        (rawYtUrl != null && rawYtUrl.contains('/shorts/'));

    return VideoItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      channel: json['channel_name']?.toString() ??
          json['source_name']?.toString() ??
          json['channel']?.toString() ??
          'VARADHI Video',
      thumbnailUrl: normalizedThumb,
      videoUrl: UrlNormalizer.normalizeNullable(rawVideoUrl),
      youtubeUrl: UrlNormalizer.normalizeNullable(rawYtUrl),
      youtubeVideoId: resolvedYtId,
      isShort: isShortVal,
      durationSeconds: durationSecs,
      duration: durationStr,
      viewsCount: viewsCnt,
      views: viewsCnt > 0 ? viewsCnt.toString() : (json['views']?.toString() ?? '0'),
      likesCount: likesCnt,
      likes: likesCnt,
      isLiked: json['is_liked_by_user'] == true || json['is_liked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'channel_name': channel,
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
      'youtube_url': youtubeUrl,
      'youtube_video_id': youtubeVideoId,
      'is_short': isShort,
      'duration_seconds': durationSeconds,
      'duration': duration,
      'views_count': viewsCount,
      'likes_count': likesCount,
      'is_liked_by_user': isLiked,
    };
  }

  MediaSource toMediaSource() {
    return MediaResolver.resolve(
      youtubeVideoId: youtubeVideoId,
      youtubeUrl: youtubeUrl,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      isShort: isShort,
    );
  }
}
