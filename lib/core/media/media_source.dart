/// Identified media types supported by the VARADHI video engine.
enum MediaSourceType {
  youtube,
  networkVideo,
  imageOnly,
  unsupported,
}

/// Represents the resolved media source for playback.
/// Provides all metadata necessary for a player to initialize without
/// guessing or re-parsing the URL in widgets.
class MediaSource {
  final MediaSourceType type;
  final String? url;
  final String? youtubeVideoId;
  final String thumbnailUrl;
  final bool isShort;
  final String? errorMessage;

  const MediaSource({
    required this.type,
    this.url,
    this.youtubeVideoId,
    required this.thumbnailUrl,
    this.isShort = false,
    this.errorMessage,
  });

  const MediaSource.youtube({
    required String videoId,
    String? rawUrl,
    required this.thumbnailUrl,
    this.isShort = false,
  })  : type = MediaSourceType.youtube,
        youtubeVideoId = videoId,
        url = rawUrl ?? 'https://www.youtube.com/watch?v=$videoId',
        errorMessage = null;

  const MediaSource.networkVideo({
    required String videoUrl,
    required this.thumbnailUrl,
    this.isShort = false,
  })  : type = MediaSourceType.networkVideo,
        url = videoUrl,
        youtubeVideoId = null,
        errorMessage = null;

  const MediaSource.imageOnly({
    required String imageUrl,
  })  : type = MediaSourceType.imageOnly,
        url = null,
        youtubeVideoId = null,
        thumbnailUrl = imageUrl,
        isShort = false,
        errorMessage = null;

  const MediaSource.unsupported({
    required this.thumbnailUrl,
    String reason = 'Unsupported media format',
  })  : type = MediaSourceType.unsupported,
        url = null,
        youtubeVideoId = null,
        isShort = false,
        errorMessage = reason;

  String? get videoId => youtubeVideoId;

  bool get isPlayable =>
      type == MediaSourceType.youtube || type == MediaSourceType.networkVideo;

  bool get isYouTube => type == MediaSourceType.youtube;
  bool get isNetworkVideo => type == MediaSourceType.networkVideo;

  @override
  String toString() =>
      'MediaSource(type: $type, id: $youtubeVideoId, url: $url, thumb: $thumbnailUrl, short: $isShort)';
}
