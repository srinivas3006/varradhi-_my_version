import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// "Choose News Language" bottom sheet.
///
/// Asks only about the news, never the interface — a reader can want a Telugu
/// app showing English articles. Picking "All" stores null, which makes the
/// feed request omit `lang` and return every language.
///
/// Used twice with one design: once automatically on first launch
/// ([showIfNeeded]), and from Settings → Content Language ([show]), where the
/// current choice is marked.
class NewsLanguageSheet extends StatelessWidget {
  const NewsLanguageSheet({super.key, this.markCurrent = false});

  /// Settings: show a check on the language already in use. The first-run
  /// prompt leaves every row neutral — nothing has been chosen yet.
  final bool markCurrent;

  /// Shows the sheet once, the first time the reader reaches the feed.
  static Future<void> showIfNeeded(BuildContext context) async {
    final state = AppState.instance;
    if (state.contentLanguagePrompted) return;
    await state.markContentLanguagePrompted();
    if (!context.mounted) return;
    await _present(context, markCurrent: false);
  }

  /// Opens the sheet on demand (Settings), with the current choice marked.
  static Future<void> show(BuildContext context) =>
      _present(context, markCurrent: true);

  static Future<void> _present(BuildContext context,
      {required bool markCurrent}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => NewsLanguageSheet(markCurrent: markCurrent),
    );
  }

  static const _options = <_LanguageOption>[
    _LanguageOption(code: null, title: 'All', subtitle: 'అన్ని భాషల వార్తలు'),
    _LanguageOption(code: 'te', title: 'తెలుగు', subtitle: 'Telugu news only'),
    _LanguageOption(
        code: 'en', title: 'English', subtitle: 'English news only'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFEEEEEE);
    final current = AppState.instance.contentLanguage;

    return SafeArea(
      top: false,
      // Material, not a decorated Container: the rows paint their ink
      // splashes onto the nearest Material ancestor.
      child: Material(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Dual-language heading
              Text(
                'వార్తల భాషను ఎంచుకోండి',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose News Language',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 14),

              for (var i = 0; i < _options.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: dividerColor),
                _LanguageRow(
                  option: _options[i],
                  selected: markCurrent && current == _options[i].code,
                  titleColor: titleColor,
                  mutedColor: mutedColor,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    AppState.instance.setContentLanguage(_options[i].code);
                    Navigator.of(context).pop();
                  },
                ),
              ],

              const SizedBox(height: 14),
              Text(
                'ఇది యాప్ భాషను మార్చదు. సెట్టింగ్‌లలో ఎప్పుడైనా మార్చవచ్చు.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: isDark ? Colors.white38 : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.title,
    required this.subtitle,
  });

  /// null = All languages.
  final String? code;
  final String title;
  final String subtitle;
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.option,
    required this.selected,
    required this.titleColor,
    required this.mutedColor,
    required this.onTap,
  });

  final _LanguageOption option;
  final bool selected;
  final Color titleColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('news_lang_${option.code ?? 'all'}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.title,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                selected
                    ? const Icon(Icons.check_circle_rounded,
                        size: 22, color: AppColors.primary)
                    : Icon(Icons.chevron_right_rounded,
                        size: 24, color: mutedColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
