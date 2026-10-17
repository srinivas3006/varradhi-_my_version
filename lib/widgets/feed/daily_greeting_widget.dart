// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';

/// The daily quote card. Shows the whole quote the admin uploaded — it is
/// short-form content, and cutting it at two lines hid most of it.
class DailyGreetingWidget extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String quote;

  const DailyGreetingWidget({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.quote,
  });

  /// The card's heading: the author when the admin named one; "Unknown",
  /// "Anonymous" or nothing show the generic heading instead.
  static String headingFor(String author) {
    final a = author.trim();
    const placeholders = {'', 'unknown', 'anonymous', 'null', 'none', 'n/a'};
    return placeholders.contains(a.toLowerCase()) ? 'నేటి సూక్తి' : a;
  }

  /// The quote as typed, without doubling quotation marks the admin already
  /// put around it.
  static String quoteText(String quote) {
    final q = quote.trim();
    const marks = '"“”\'‘’';
    final wrapped =
        q.length > 1 && marks.contains(q[0]) && marks.contains(q[q.length - 1]);
    final hasOwnMarks = marks.split('').any(q.contains);
    if (wrapped || hasOwnMarks) return q;
    return '“$q”';
  }

  @override
  State<DailyGreetingWidget> createState() => _DailyGreetingWidgetState();
}

class _DailyGreetingWidgetState extends State<DailyGreetingWidget> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  String get _heading => DailyGreetingWidget.headingFor(widget.title);
  String get _quote => DailyGreetingWidget.quoteText(widget.quote);

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final imageBytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 100));
      if (imageBytes == null) throw Exception('Failed to capture image');

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/daily_greeting.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles([XFile(file.path)],
          text: '$_heading\n$_quote\n\nShared via Vaaradhi App');
    } catch (e) {
      debugPrint("Error sharing image: $e");
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Screenshot(
          controller: _screenshotController,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 118),
            decoration: BoxDecoration(
              gradient: widget.imageUrl.isEmpty
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    )
                  : null,
              image: widget.imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(widget.imageUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.45),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon, heading and Share on one row, so the quote below
                // gets the card's full width.
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.format_quote_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _heading,
                        key: const Key('daily_quote_heading'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: _isSharing ? null : _shareImage,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSharing)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.share_rounded,
                                  color: AppColors.primary,
                                  size: 15,
                                ),
                              const SizedBox(width: 5),
                              const Text(
                                'Share',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // The whole quote — no line limit.
                Text(
                  _quote,
                  key: const Key('daily_quote_text'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Daily Inspiration',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
