import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// share_plus ships its own ShareResult; ours is the app-level outcome.
import 'package:share_plus/share_plus.dart' hide ShareResult;

import '../../models/news_article.dart';
import '../../utils/share_service.dart';
import 'share_models.dart';
import 'share_text_builder.dart';

/// The one entry point for sharing anything.
///
/// Wraps the existing [ShareService], which already owns image generation
/// and the watermark, rather than standing up a parallel implementation.
/// Screens call [share] and never touch share_plus, URLs or asset building.
class ContentShareService {
  const ContentShareService._();

  /// Guards against a second share starting while one is in flight, which is
  /// what produced duplicate downloads of the same video.
  static bool _inFlight = false;

  static Future<ShareResult> share(
    ShareContent content, {
    ShareFormat format = ShareFormat.link,
  }) async {
    // Privacy is the backend's call; this refuses rather than leaking.
    // An absent canonical URL means the item had no slug or id, so there is
    // nothing that would resolve — refuse rather than share a broken link.
    if (!content.isShareable) {
      debugPrint('[Share] refused: ${content.contentType.route} '
          '${content.isPublic ? "has no canonical url" : "is not public"}');
      return ShareResult.unavailable;
    }

    if (_inFlight) return ShareResult.cancelled;
    _inFlight = true;

    try {
      switch (format) {
        case ShareFormat.link:
          await Share.share(ShareTextBuilder.forContent(content));
          return ShareResult.shared;

        case ShareFormat.image:
          return await _shareImage(content);

        case ShareFormat.video:
          // No video file is downloaded: the canonical link plays it, and
          // pulling a full video down to hand to the share sheet costs the
          // reader bandwidth for no gain.
          await Share.share(
              ShareTextBuilder.forMedia(content, ShareFormat.video));
          return ShareResult.shared;
      }
    } catch (e) {
      debugPrint('[Share] failed: $e');
      return ShareResult.failed;
    } finally {
      _inFlight = false;
    }
  }

  /// Copies the canonical public URL — never an API host or signed URL.
  static Future<ShareResult> copyLink(ShareContent content) async {
    if (!content.isShareable) return ShareResult.unavailable;
    await Clipboard.setData(ClipboardData(text: content.canonicalUrl!));
    return ShareResult.shared;
  }

  static Future<ShareResult> _shareImage(ShareContent content) async {
    if (!content.hasImage) return ShareResult.unavailable;

    // Reuses the existing generator: a purpose-built branded card with the
    // mandatory watermark, not a screen capture.
    final article = _asArticle(content);
    final file = await ShareService.buildPosterFile(article);
    if (file == null || !await File(file.path).exists()) {
      return ShareResult.failed;
    }

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: ShareTextBuilder.forMedia(content, ShareFormat.image),
    );
    return ShareResult.shared;
  }

  /// Adapts [ShareContent] to what the existing image generator expects.
  static NewsArticle _asArticle(ShareContent content) => NewsArticle.fromJson({
        'id': content.contentId,
        'title': content.title,
        'summary': content.description,
        'image_url': content.imageUrl ?? '',
      });
}
