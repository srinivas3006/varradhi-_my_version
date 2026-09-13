// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:typed_data';
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

      // If valid image exists, generate the branded watermark card image
      if (hasValidImage) {
        try {
          final Uint8List imageBytes =
              await _screenshotController.captureFromWidget(
            _WatermarkShareCard(
              article: article,
              resolvedImageUrl: normalizedUrl,
            ),
            delay: const Duration(milliseconds: 150),
          );

          if (imageBytes.isNotEmpty) {
            final tempDir = await getTemporaryDirectory();
            final safeId = article.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final file = await File('${tempDir.path}/vaaradhi_share_$safeId.png').create();
            await file.writeAsBytes(imageBytes);

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

/// The off-screen widget representing the exact image with bottom logo watermark banner.
/// Uses 16:9 news standard aspect ratio with a sleek gradient bottom watermark.
class _WatermarkShareCard extends StatelessWidget {
  final NewsArticle article;
  final String resolvedImageUrl;

  const _WatermarkShareCard({
    required this.article,
    required this.resolvedImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 1080,
        height: 1080, // High-definition 1080x1080 social card
        color: const Color(0xFF0F172A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full Image Background (Main visual)
            Image.network(
              resolvedImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: const Color(0xFF1E293B),
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white54,
                    size: 120,
                  ),
                ),
              ),
            ),

            // 2. Dark Vignette Gradient on bottom for high-contrast watermark readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 240,
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

            // 3. Bottom Logo Watermark Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 28),
                color: const Color(0xE6111827), // Sleek semi-translucent dark slate
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Official Vaaradhi Logo Asset
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Brand Name & Tagline
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Vaaradhi',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontFamily: 'Roboto',
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 14),
                              Text(
                                '• వారధి',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFED915), // Brand Accent Yellow
                                  fontFamily: 'NotoSansTelugu',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'నిజమైన వార్తలకు నిలువెత్తు వారధి',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFCBD5E1),
                              fontFamily: 'NotoSansTelugu',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // App Store Download Badge CTA
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2300), // AppColors.primary
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66FF2300),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Get App',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: 'Roboto',
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
