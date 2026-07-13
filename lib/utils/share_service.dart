// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../models/news_article.dart';
import '../theme/app_theme.dart';

class ShareService {
  static final ScreenshotController _screenshotController = ScreenshotController();

  /// Captures an off-screen branded widget and shares it via the native share sheet.
  static Future<void> shareArticle(NewsArticle article) async {
    try {
      // 1. Capture the widget as an image
      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        _WatermarkShareCard(article: article),
        delay: const Duration(milliseconds: 100),
      );

      // 2. Save image to temp directory
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/share_${article.id}.png').create();
      await file.writeAsBytes(imageBytes);

      // 3. Prepare share text
      final String shareText = '${article.title}\n\nRead more at: https://vaaradhi.app/news/${article.id}\n\nShared via Vaaradhi';

      // 4. Share using share_plus
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
      );
    } catch (e) {
      debugPrint('Error sharing article: $e');
    }
  }
}

/// The off-screen widget that represents exactly how the image should look when shared.
class _WatermarkShareCard extends StatelessWidget {
  final NewsArticle article;

  const _WatermarkShareCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 1080, // High res for sharing
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main Article Image
            AspectRatio(
              aspectRatio: 1.0, // Square image
              child: Image.network(
                article.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: AppColors.chipBg,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 100),
                  ),
                ),
              ),
            ),
            
            // Footer with Stats and Branding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              color: Colors.white,
              child: Row(
                children: [
                  // App Branding
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 20),
                  const Text(
                    'Vaaradhi',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      fontFamily: 'Roboto', // ensuring a safe font off-screen
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Stats (Likes and Shares)
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: AppColors.primary, size: 40),
                      const SizedBox(width: 10),
                      Text(
                        '${article.likes}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.textDark, fontFamily: 'Roboto'),
                      ),
                      const SizedBox(width: 30),
                      const Icon(Icons.share, color: AppColors.textMuted, size: 40),
                      const SizedBox(width: 10),
                      Text(
                        '${article.shares}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.textDark, fontFamily: 'Roboto'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
