// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../models/news_article.dart';
import '../widgets/watermark/watermark_banner.dart';
import '../core/utils/url_normalizer.dart';

class ShareService {
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  static bool _isSharing = false;

  /// Official Google Play Store link for app download
  static const String appDownloadUrl =
      'https://play.google.com/store/apps/details?id=com.varadhi';

  /// Official Vaaradhi web article domain
  static const String webBaseUrl = 'https://vaaradhinews.com';

  static String buildArticleDeepLink(NewsArticle article) {
    final route = article.isUgc ? 'ugc' : 'article';
    final identifier = article.isUgc
        ? article.id
        : (article.slug.isNotEmpty ? article.slug : article.id);
    return 'varadhi://$route/${Uri.encodeComponent(identifier)}';
  }

  static String buildWebArticleUrl(NewsArticle article) {
    final route = article.isUgc ? 'ugc' : 'article';
    final identifier = article.isUgc
        ? article.id
        : (article.slug.isNotEmpty ? article.slug : article.id);
    return '$webBaseUrl/$route/${Uri.encodeComponent(identifier)}';
  }

  /// Builds clean, professional share text with title, web article link, and app download link.
  static String buildShareText(NewsArticle article) {
    final webUrl = buildWebArticleUrl(article);
    return '${article.title.trim()}\n\n'
        '📲 పూర్తి వార్తలు & తాజా అప్‌డేట్స్ కోసం వారధి యాప్ డౌన్‌లోడ్ చేసుకోండి:\n'
        '$appDownloadUrl\n\n'
        '🌐 కథనం లింక్:\n'
        '$webUrl';
  }

  /// Pre-fetches the image bytes into memory so `Image.memory` paints synchronously
  /// during off-screen screenshot capture.
  static Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        return await consolidateHttpClientResponseBytes(response);
      }
    } catch (e) {
      debugPrint('[ShareService] Failed to pre-fetch image bytes: $e');
    }
    return null;
  }

  /// Captures an off-screen branded widget and shares it via the native share sheet.
  /// One-tap guarded: ignores rapid duplicate taps while processing.
  static Future<void> shareArticle(NewsArticle article) async {
    if (_isSharing) {
      debugPrint('ShareService: share already in progress, ignoring duplicate tap');
      return;
    }
    _isSharing = true;

    try {
      final normalizedUrl = UrlNormalizer.normalize(
        (article.mediaItems.isNotEmpty && article.mediaItems.first.url.isNotEmpty)
            ? article.mediaItems.first.url
            : article.imageUrl,
      );

      final hasValidImage = normalizedUrl.isNotEmpty &&
          (normalizedUrl.startsWith('http://') || normalizedUrl.startsWith('https://'));

      Uint8List? imageBytes;
      if (hasValidImage) {
        imageBytes = await _fetchImageBytes(normalizedUrl);
      }

      // If valid image exists and bytes downloaded, generate the branded watermark card image
      if (imageBytes != null && imageBytes.isNotEmpty) {
        try {
          int naturalWidth = 1200;
          int naturalHeight = 675;
          try {
            final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
            final ui.FrameInfo frameInfo = await codec.getNextFrame();
            naturalWidth = frameInfo.image.width;
            naturalHeight = frameInfo.image.height;
          } catch (decodeErr) {
            debugPrint('[ShareService] Error decoding image dimensions: $decodeErr');
          }

          // Exact natural aspect ratio preserved — zero distortion or unwanted cropping
          double targetWidth = naturalWidth.toDouble();
          double targetHeight = naturalHeight.toDouble();
          if (targetWidth > 1200) {
            targetHeight = (targetHeight * 1200 / targetWidth).roundToDouble();
            targetWidth = 1200;
          } else if (targetWidth < 600 && targetWidth > 0) {
            targetHeight = (targetHeight * 600 / targetWidth).roundToDouble();
            targetWidth = 600;
          }
          if (targetHeight <= 0) targetHeight = 675;
          if (targetWidth <= 0) targetWidth = 1200;

          final Uint8List cardBytes =
              await _screenshotController.captureFromWidget(
            _WatermarkShareCard(
              article: article,
              imageBytes: imageBytes,
              width: targetWidth,
              height: targetHeight,
            ),
            targetSize: Size(targetWidth, targetHeight),
            delay: const Duration(milliseconds: 80),
          );

          if (cardBytes.isNotEmpty) {
            final tempDir = await getTemporaryDirectory();
            final safeId = article.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final file = await File('${tempDir.path}/vaaradhi_share_$safeId.png').create();
            await file.writeAsBytes(cardBytes);

            final shareText = buildShareText(article);
            await Share.shareXFiles(
              [XFile(file.path)],
              text: shareText,
            );
            return;
          }
        } catch (imgError) {
          debugPrint('ShareService: capture widget failed, falling back to text share: $imgError');
        }
      }

      // Fallback: share clean text + link directly
      final shareText = buildShareText(article);
      await Share.share(shareText);
    } catch (e) {
      debugPrint('Error sharing article: $e');
    } finally {
      _isSharing = false;
    }
  }

  /// Whether a shareable/downloadable poster can be built for [article].
  ///
  /// Gates the Download action: a poster is an image with text on it, so
  /// without a usable image there is nothing to generate and the control
  /// should not be offered.
  static bool canGeneratePoster(NewsArticle article) {
    // A video story has no still to download, but it still has something to
    // hand over: a black card carrying the masthead. So the control stays
    // offered rather than disappearing on exactly the items people most
    // want to pass on.
    if (article.isVideo) return true;

    final url = UrlNormalizer.normalize(
      (article.mediaItems.isNotEmpty && article.mediaItems.first.url.isNotEmpty)
          ? article.mediaItems.first.url
          : article.imageUrl,
    );
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Builds the branded PNG poster: image, headline, body excerpt, and the
  /// mandatory watermark.
  ///
  /// Returns the written file, or null when no poster could be produced.
  /// Works for articles and UGC alike — UGC is a NewsArticle with
  /// contentKind 'ugc', so the only difference is which fields carry text.
  /// Builds the PNG that travels with a share or download.
  ///
  /// [includeText] adds the headline and summary beneath the banner, which
  /// is what a share preview needs. A download stays picture-and-banner
  /// only, so the saved image is the artwork rather than a screenshot of
  /// the story.
  static Future<File?> buildPosterFile(
    NewsArticle article, {
    bool includeText = false,
  }) async {
    if (!canGeneratePoster(article)) return null;

    final url = UrlNormalizer.normalize(
      (article.mediaItems.isNotEmpty && article.mediaItems.first.url.isNotEmpty)
          ? article.mediaItems.first.url
          : article.imageUrl,
    );
    final imageBytes = await _fetchImageBytes(url);

    // No still available — a video, or an image that would not load. Fall
    // back to the branded black card instead of returning nothing.
    if (imageBytes == null || imageBytes.isEmpty) {
      return _buildWatermarkOnlyFile(article);
    }

    // Image + watermark only. No headline, no body: the download is the
    // picture, and the text travels beside it in the share sheet instead of
    // being burned into the pixels.
    //
    // Natural aspect ratio preserved, capped so a huge original does not
    // produce a huge PNG.
    double width = 1200;
    double height = 675;
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      width = frame.image.width.toDouble();
      height = frame.image.height.toDouble();
    } catch (e) {
      debugPrint('[ShareService] could not decode poster dimensions: $e');
    }
    if (width > 1200) {
      height = (height * 1200 / width).roundToDouble();
      width = 1200;
    }
    if (width <= 0 || height <= 0) {
      width = 1200;
      height = 675;
    }

    final bytes = await _screenshotController.captureFromWidget(
      includeText
          ? _SharePreviewCard(
              article: article,
              imageBytes: imageBytes,
              width: width,
            )
          : _WatermarkShareCard(
              article: article,
              imageBytes: imageBytes,
              width: width,
              height: height,
            ),
      // A preview stacks banner and text under the picture, so it needs the
      // taller canvas; a plain download is exactly the image.
      targetSize: includeText
          ? Size(width, height + _SharePreviewCard.chromeHeight(width))
          : Size(width, height),
      delay: const Duration(milliseconds: 120),
    );
    if (bytes.isEmpty) return null;

    final dir = await getTemporaryDirectory();
    final safeId = article.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file =
        await File('${dir.path}/vaaradhi_poster_$safeId.png').create();
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Outcome of a download, so the UI can say what actually happened rather
  /// than guessing.
  static const int downloadSaved = 0;
  static const int downloadPermissionDenied = 1;
  static const int downloadFailed = 2;

  /// A plain black card carrying only the masthead.
  ///
  /// Used when there is no still to build a poster from — a video story, or
  /// artwork that failed to load. Keeps the download meaningful and branded
  /// rather than failing silently.
  static Future<File?> _buildWatermarkOnlyFile(NewsArticle article) async {
    const double width = 1080;
    const double height = 1350;

    try {
      final bytes = await _screenshotController.captureFromWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: width,
            height: height,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 64),
                  child: WatermarkBanner(padding: EdgeInsets.zero),
                ),
              ),
            ),
          ),
        ),
        targetSize: const Size(width, height),
        delay: const Duration(milliseconds: 120),
      );
      if (bytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final safeId = article.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file =
          await File('${dir.path}/vaaradhi_card_$safeId.png').create();
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('[ShareService] watermark-only card failed: $e');
      return null;
    }
  }

  /// Writes the watermarked PNG into the device gallery.
  ///
  /// Android 29+ goes through MediaStore and needs no permission; 28 and
  /// below use WRITE_EXTERNAL_STORAGE, declared with maxSdkVersion="28". iOS
  /// needs add-only Photos access. gal.hasAccess/requestAccess handles the
  /// difference, so this asks only when the platform actually requires it.
  static Future<int> downloadPoster(NewsArticle article) async {
    if (_isSharing) return downloadFailed;
    _isSharing = true;
    try {
      final file = await buildPosterFile(article);
      if (file == null) return downloadFailed;

      // toAlbum makes the saved file land somewhere the reader can find it,
      // rather than loose in the camera roll.
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) {
          return downloadPermissionDenied;
        }
      }

      await Gal.putImage(file.path, album: 'Vaaradhi');
      return downloadSaved;
    } on GalException catch (e) {
      debugPrint('ShareService: gallery save failed: ${e.type}');
      return e.type == GalExceptionType.accessDenied
          ? downloadPermissionDenied
          : downloadFailed;
    } catch (e) {
      debugPrint('ShareService: poster download failed: $e');
      return downloadFailed;
    } finally {
      _isSharing = false;
    }
  }

  /// Share: the same watermarked image, with the text sent beside it through
  /// the native sheet so every social target receives both.
  static Future<bool> sharePoster(NewsArticle article) async {
    if (_isSharing) return false;
    _isSharing = true;
    try {
      // Share preview: picture, banner, then the story.
      final file = await buildPosterFile(article, includeText: true);
      if (file == null) return false;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: buildShareText(article),
      );
      return true;
    } catch (e) {
      debugPrint('ShareService: poster share failed: $e');
      return false;
    } finally {
      _isSharing = false;
    }
  }

  /// Shares plain text or deep links via native share sheet.
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await Share.share(text, subject: subject);
    } catch (e) {
      debugPrint('Error sharing text: $e');
    }
  }
}

/// The off-screen widget representing the article image with ONLY the official logo watermark.
/// Matches the exact natural size and aspect ratio of the news article image with no footer bar or extra text.
class _WatermarkShareCard extends StatelessWidget {
  final NewsArticle article;
  final Uint8List imageBytes;
  final double width;
  final double height;

  const _WatermarkShareCard({
    required this.article,
    required this.imageBytes,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              imageBytes,
              width: width,
              height: height,
              fit: BoxFit.cover,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    width * 0.04, width * 0.05, width * 0.04, width * 0.025),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: WatermarkBanner(
                  height: width * 0.06,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card a share preview is rendered from: the picture, the masthead
/// banner beneath it, then the story — the same order the reader sees on the
/// spotlight card and the article screen.
///
/// A download uses [_WatermarkShareCard] instead, which is the picture and
/// the banner without the copy.
class _SharePreviewCard extends StatelessWidget {
  const _SharePreviewCard({
    required this.article,
    required this.imageBytes,
    required this.width,
  });

  final NewsArticle article;
  final Uint8List imageBytes;
  final double width;

  /// Height the banner and text add below the picture, so the capture can be
  /// sized before the widget is laid out.
  static double chromeHeight(double width) => width * 0.52;

  @override
  Widget build(BuildContext context) {
    final pad = width * 0.045;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: width,
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. The original image, uncropped.
            Image.memory(imageBytes, width: width, fit: BoxFit.contain),

            // 2. The masthead band, on the seam — the same place it sits in
            // the app, so a shared image reads like the screen it came from.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.5),
              child: WatermarkBanner(
                height: width * 0.075,
                padding: EdgeInsets.zero,
              ),
            ),

            // 3. The story.
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    article.title.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: width * 0.042,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF141414),
                    ),
                  ),
                  if (article.summary.trim().isNotEmpty) ...[
                    SizedBox(height: pad * 0.4),
                    Text(
                      article.summary.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: width * 0.028,
                        height: 1.6,
                        color: const Color(0xFF4A4A4A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
