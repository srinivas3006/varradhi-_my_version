// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../models/news_article.dart';
import '../core/utils/url_normalizer.dart';

class ShareService {
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  static bool _isSharing = false;

  /// Official Google Play Store link for app download
  static const String appDownloadUrl =
      'https://play.google.com/store/apps/details?id=com.vaaradhi.vaaradhi';

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
    // Proportional logo watermark size based on image dimensions
    final double logoSize = (width * 0.12).clamp(48.0, 96.0);
    final double margin = (width * 0.035).clamp(12.0, 24.0);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Article Image (Full Natural Size, No Distortion, No Crop)
            Image.memory(
              imageBytes,
              width: width,
              height: height,
              fit: BoxFit.cover,
            ),

            // 2. Subtle Corner Gradient for watermark contrast
            Positioned(
              right: 0,
              bottom: 0,
              width: logoSize * 2.2,
              height: logoSize * 2.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomRight,
                    radius: 1.1,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 3. Official Vaaradhi Logo Watermark ONLY (Bottom-Right)
            Positioned(
              right: margin,
              bottom: margin,
              child: Opacity(
                opacity: 0.92,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
