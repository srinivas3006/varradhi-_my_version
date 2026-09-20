/// What kind of thing is being shared. Drives the canonical route, the
/// share text, and which formats the sheet offers.
enum ShareContentType { article, poster, poll, ugc, video, short }

extension ShareContentTypeX on ShareContentType {
  /// Path segment of the canonical URL: /article/{id}, /poll/{id}, …
  String get route => switch (this) {
        ShareContentType.article => 'article',
        ShareContentType.poster => 'poster',
        ShareContentType.poll => 'poll',
        ShareContentType.ugc => 'ugc',
        ShareContentType.video => 'video',
        ShareContentType.short => 'short',
      };

  /// Template identifier recorded with the generated asset, so a regenerated
  /// image can be told from an older one. Not hard-coded at call sites.
  String get templateVersion => '${route}_v1';
}

/// How the reader chose to share.
enum ShareFormat { link, image, video }

/// Outcome of a share attempt.
///
/// [cancelled] is not a failure: closing the native sheet is a normal thing
/// to do and must never surface as an error.
enum ShareResult { shared, cancelled, unavailable, failed }

/// One shape every shareable thing collapses into, so screens never build
/// their own URL, text or asset.
class ShareContent {
  const ShareContent({
    required this.contentType,
    required this.contentId,
    required this.title,
    this.canonicalUrl,
    this.description = '',
    this.imageUrl,
    this.videoUrl,
    this.creator,
    this.category,
    this.isPublic = true,
  });

  final ShareContentType contentType;
  final String contentId;
  final String title;
  /// Null when the item has no usable identifier — the sheet refuses to
  /// share rather than emitting a URL that cannot resolve.
  final String? canonicalUrl;

  bool get isShareable =>
      isPublic && canonicalUrl != null && canonicalUrl!.isNotEmpty;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final String? creator;
  final String? category;

  /// False for private, deleted, blocked or moderation-restricted items.
  /// Sharing is refused rather than leaking them.
  final bool isPublic;

  String get templateVersion => contentType.templateVersion;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  /// Formats the sheet should offer for this item.
  List<ShareFormat> get availableFormats => [
        ShareFormat.link,
        if (hasImage) ShareFormat.image,
        if (hasVideo) ShareFormat.video,
      ];
}
