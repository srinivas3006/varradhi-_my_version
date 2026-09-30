import '../../models/video_item.dart';

/// How a reel is played, in priority order (Reels handover, Media Selection).
enum ReelMediaType { native, youtube, unavailable }

/// One item of `GET /api/v1/articles/shorts-feed/`.
class Reel {
  const Reel({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.youtubeVideoId,
    required this.youtubeUrl,
    required this.videoUrl,
    required this.shareUrl,
    required this.channelName,
    required this.isLive,
    required this.isBreaking,
    required this.durationSeconds,
  });

  final String id;
  final String title;
  final String thumbnailUrl;
  final String youtubeVideoId;
  final String youtubeUrl;
  final String videoUrl;
  final String shareUrl;
  final String channelName;
  final bool isLive;
  final bool isBreaking;
  final int durationSeconds;

  factory Reel.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString().trim();
    return Reel(
      id: s('id'),
      title: s('title'),
      thumbnailUrl: s('thumbnail_url'),
      youtubeVideoId: s('youtube_video_id'),
      youtubeUrl: s('youtube_url'),
      videoUrl: s('video_url'),
      shareUrl: s('share_url'),
      channelName: s('channel_name'),
      isLive: j['is_live'] == true,
      isBreaking: j['is_breaking'] == true,
      durationSeconds: (j['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  /// A video from another feed (e.g. a notification's /video/{id}/ link)
  /// shown as a reel.
  factory Reel.fromVideo(VideoItem v) => Reel(
        id: v.id,
        title: v.title,
        thumbnailUrl: v.thumbnailUrl,
        youtubeVideoId: v.youtubeVideoId ?? '',
        youtubeUrl: v.youtubeUrl ?? '',
        videoUrl: v.videoUrl ?? '',
        shareUrl: v.shareUrl,
        channelName: v.channel,
        isLive: false,
        isBreaking: false,
        durationSeconds: v.durationSeconds,
      );

  static final _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static final _urlPattern =
      RegExp(r'(?:v=|shorts/|youtu\.be/|embed/)([A-Za-z0-9_-]{11})');

  /// A real YouTube id, or null. Ids starting `local-` are uploaded videos,
  /// never YouTube.
  String? get youtubeId {
    final raw = youtubeVideoId;
    if (raw.startsWith('local-')) return null;
    if (_idPattern.hasMatch(raw)) return raw;
    return _urlPattern.firstMatch(youtubeUrl)?.group(1);
  }

  /// video_url first, then YouTube, else unavailable.
  ReelMediaType get mediaType {
    if (videoUrl.isNotEmpty) return ReelMediaType.native;
    if (youtubeId != null) return ReelMediaType.youtube;
    return ReelMediaType.unavailable;
  }

  /// The backend's share_url, else the public page — never the API domain.
  String get safeShareUrl => shareUrl.isNotEmpty
      ? shareUrl
      : 'https://vaaradhinews.com/video/$id/';
}
