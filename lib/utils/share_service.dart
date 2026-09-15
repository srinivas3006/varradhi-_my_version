// ignore_for_file: deprecated_member_use
import 'dart:io';
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
          final Uint8List cardBytes =
              await _screenshotController.captureFromWidget(
            _WatermarkShareCard(
              article: article,
              imageBytes: imageBytes,
            ),
            targetSize: const Size(1200, 675),
            delay: const Duration(milliseconds: 100),
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

/// The off-screen widget representing the article image with a bottom logo watermark banner.
/// Standard 16:9 aspect ratio (1200x675) optimized for WhatsApp and social previews.
class _WatermarkShareCard extends StatelessWidget {
  final NewsArticle article;
  final Uint8List imageBytes;

  const _WatermarkShareCard({
    required this.article,
    required this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 1200,
        height: 675,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Article Image (Full Background)
            Image.memory(
              imageBytes,
              width: 1200,
              height: 675,
              fit: BoxFit.cover,
            ),

            // 2. Subtle Bottom Shadow Vignette
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 180,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x99000000),
                      Color(0xEE000000),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Bottom Watermark Bar with Logo, Branding, and Download CTA
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 110,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xF20B1120), // Dark translucent slate
                  border: Border(
                    top: BorderSide(
                      color: Color(0x33FFFFFF),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Official Vaaradhi Logo Asset
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Brand Title & Tagline
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Vaaradhi',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                '• వారధి',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF4726),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'నిజమైన వార్తలకు నిలువెత్తు వారధి',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // App Store Download Badge CTA
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2300),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66FF2300),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Get App',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
