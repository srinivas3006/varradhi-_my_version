import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// One-time "Choose News Language" prompt.
///
/// Asks only about the news, never the interface — a reader can want a Telugu
/// app showing English articles. Picking "All" stores null, which makes the
/// feed request omit `lang` and return every language.
class NewsLanguageSheet extends StatelessWidget {
  const NewsLanguageSheet({super.key});

  /// Shows the sheet once, the first time the reader reaches the feed.
  static Future<void> showIfNeeded(BuildContext context) async {
    final state = AppState.instance;
    if (state.contentLanguagePrompted) return;
    await state.markContentLanguagePrompted();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewsLanguageSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget option(String label, String sub, String? code) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(sub,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
        onTap: () {
          AppState.instance.setContentLanguage(code);
          Navigator.of(context).pop();
        },
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'వార్తల భాషను ఎంచుకోండి',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose News Language',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            option('All', 'అన్ని భాషల వార్తలు', null),
            const Divider(height: 1),
            option('తెలుగు', 'Telugu news only', 'te'),
            const Divider(height: 1),
            option('English', 'English news only', 'en'),
            const SizedBox(height: 8),
            Text(
              'ఇది యాప్ భాషను మార్చదు. సెట్టింగ్‌లలో ఎప్పుడైనా మార్చవచ్చు.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
