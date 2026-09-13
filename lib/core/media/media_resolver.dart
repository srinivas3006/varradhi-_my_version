import '../utils/url_normalizer.dart';
import 'media_source.dart';

/// Centralized media resolution engine for VARADHI.
/// Inspects backend media attributes, validates URLs and YouTube IDs,
/// extracts thumbnails, and produces a type-safe [MediaSource].
class MediaResolver {
  MediaResolver._();

  static final RegExp _ytRegex = RegExp(
    r'(?:youtu\.be\/|youtube(?:-nocookie)?\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/|live\/))([A-Za-z0-9_-]{11})',
    caseSensitive: false,
  );

  static final RegExp _ytIdRegex = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// Resolves any combination of video URL, YouTube ID, and thumbnail into a [MediaSource].
  static MediaSource resolve({
    String? videoUrl,
    String? youtubeUrl,
    String? youtubeVideoId,
    String? thumbnailUrl,
    bool? isShort,
    bool isVideoFlag = false,
  }) {
    // 1. Sanitize raw strings
    final rawYtId = extractYoutubeVideoId(youtubeVideoId);
    final rawYtUrl = youtubeUrl?.trim();
    final rawVideoUrl = videoUrl?.trim();
    final effectiveThumb = UrlNormalizer.normalize(thumbnailUrl);

    // 2. Check if a valid YouTube Video ID is provided directly
    if (rawYtId != null && rawYtId.isNotEmpty) {
      final thumb = effectiveThumb.isNotEmpty
          ? effectiveThumb
          : 'https://i.ytimg.com/vi/$rawYtId/hqdefault.jpg';

      return MediaSource.youtube(
        videoId: rawYtId,
        rawUrl: rawYtUrl ?? rawVideoUrl,
        thumbnailUrl: thumb,
        isShort: isShort == true || (rawVideoUrl?.contains('/shorts/') == true),
      );
    }

    // 3. Inspect YouTube URL if provided
    final urlToInspect = (rawYtUrl != null && rawYtUrl.isNotEmpty)
        ? rawYtUrl
        : (rawVideoUrl != null && rawVideoUrl.isNotEmpty ? rawVideoUrl : '');

    if (urlToInspect.isNotEmpty) {
      final match = _ytRegex.firstMatch(urlToInspect);
      if (match != null && match.groupCount >= 1) {
        final extractedId = match.group(1)!;
        final thumb = effectiveThumb.isNotEmpty
            ? effectiveThumb
            : 'https://i.ytimg.com/vi/$extractedId/hqdefault.jpg';

        final isShortUrl = isShort == true || urlToInspect.contains('/shorts/');

        return MediaSource.youtube(
          videoId: extractedId,
          rawUrl: urlToInspect,
          thumbnailUrl: thumb,
          isShort: isShortUrl,
        );
      }
    }

    // 4. Inspect Direct Network Video URL
    if (rawVideoUrl != null && rawVideoUrl.isNotEmpty) {
      final normalizedVideoUrl = UrlNormalizer.normalize(rawVideoUrl);

      if (normalizedVideoUrl.isNotEmpty && _isValidVideoUrl(normalizedVideoUrl, isVideoFlag)) {
        return MediaSource.networkVideo(
          videoUrl: normalizedVideoUrl,
          thumbnailUrl: effectiveThumb,
          isShort: isShort == true,
        );
      }
    }

    // 5. Fallback: If an image or thumbnail exists, treat as imageOnly
    if (effectiveThumb.isNotEmpty) {
      return MediaSource.imageOnly(imageUrl: effectiveThumb);
    }

    // 6. Completely unsupported / empty media
    return MediaSource.unsupported(
      thumbnailUrl: effectiveThumb,
      reason: 'No playable video or media found',
    );
  }

  /// Determines if a URL represents a playable native video.
  static bool _isValidVideoUrl(String url, bool isVideoExplicit) {
    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      return false;
    }

    final pathLower = uri.path.toLowerCase();
    if (pathLower.endsWith('.mp4') ||
        pathLower.endsWith('.mov') ||
        pathLower.endsWith('.webm') ||
        pathLower.endsWith('.m4v') ||
        pathLower.endsWith('.m3u8')) {
      return true;
    }

    // If the backend explicitly indicated that this payload is a video and the URL is valid HTTPS
    if (isVideoExplicit && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return true;
    }

    return false;
  }

  /// Extracts the YouTube Video ID from any URL string or returns null.
  static String? extractYoutubeVideoId(String? url) {
    if (url == null) return null;
    final cleaned = url.trim();
    if (cleaned.isEmpty) return null;
    if (_ytIdRegex.hasMatch(cleaned)) {
      return cleaned;
    }
    final uri = Uri.tryParse(cleaned);
    final idFromUri = _extractYoutubeVideoIdFromUri(uri);
    if (idFromUri != null) return idFromUri;

    final match = _ytRegex.firstMatch(cleaned);
    if (match != null && match.groupCount >= 1) {
      final matchId = match.group(1);
      return matchId != null && _ytIdRegex.hasMatch(matchId) ? matchId : null;
    }
    return null;
  }

  static String? _extractYoutubeVideoIdFromUri(Uri? uri) {
    if (uri == null) return null;
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final segments = uri.pathSegments;

    if (host == 'youtu.be' && segments.isNotEmpty) {
      final id = segments.first.trim();
      return _ytIdRegex.hasMatch(id) ? id : null;
    }

    final isYoutubeHost = host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtube-nocookie.com';
    if (!isYoutubeHost) return null;

    final watchId = uri.queryParameters['v']?.trim();
    if (watchId != null && _ytIdRegex.hasMatch(watchId)) return watchId;

    for (var i = 0; i < segments.length - 1; i++) {
      final marker = segments[i].toLowerCase();
      if (marker == 'shorts' ||
          marker == 'embed' ||
          marker == 'v' ||
          marker == 'live') {
        final id = segments[i + 1].trim();
        return _ytIdRegex.hasMatch(id) ? id : null;
      }
    }

    return null;
  }
}
