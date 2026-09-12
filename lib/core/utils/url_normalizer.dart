import '../config/app_config.dart';

/// Centralized URL normalization utility for the VARADHI data layer.
/// Safely handles absolute HTTP/HTTPS URLs, protocol-relative URLs,
/// backend-relative media paths, nulls, empty strings, and malformed inputs.
class UrlNormalizer {
  UrlNormalizer._();

  /// Normalizes any raw image or media URL received from the backend.
  /// - Returns fallback or empty string if input is null, empty, or unparseable.
  /// - Converts protocol-relative URLs (`//domain.com/...`) to `https://`.
  /// - Converts relative paths (`/media/...` or `media/...`) to absolute backend URLs.
  /// - Validates and returns clean absolute HTTPS/HTTP URLs.
  static String normalize(String? rawUrl, {String fallback = ''}) {
    if (rawUrl == null) return fallback;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return fallback;

    // Handle protocol-relative URLs (e.g. "//cdn.example.com/image.jpg")
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    // Handle relative backend URLs (e.g. "/media/articles/photo.jpg" or "media/...")
    if (trimmed.startsWith('/') || (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))) {
      // Check if it's actually an absolute URL without scheme or just a path
      if (!trimmed.contains('://')) {
        final base = AppConfig.baseUrl.endsWith('/')
            ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
            : AppConfig.baseUrl;
        final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
        return '$base$path';
      }
    }

    // Validate URI structure
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return trimmed;
    }

    // If parsing failed or scheme was invalid, return fallback
    return fallback;
  }

  /// Normalizes a nullable URL and returns null if invalid or empty.
  static String? normalizeNullable(String? rawUrl) {
    final result = normalize(rawUrl);
    return result.isEmpty ? null : result;
  }

  /// Extracts a high-quality YouTube thumbnail from video, watch, embed, or shorts URLs.
  /// Returns null if not a recognized YouTube URL.
  static String? extractYoutubeThumbnail(String? videoUrl) {
    if (videoUrl == null || videoUrl.trim().isEmpty) return null;
    final trimmed = videoUrl.trim();

    if (!trimmed.contains('youtube.com') && !trimmed.contains('youtu.be')) {
      return null;
    }

    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      final videoId = match.group(1);
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      }
    }
    return null;
  }
}
