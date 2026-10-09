import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/news_article.dart';
import '../../core/navigation/auth_guard.dart';
import '../../services/content_engagement_service.dart';
import '../../state/app_state.dart';
import 'report_story_sheet.dart';

enum StoryOption { report, bookmark }

/// "More" (⋮) sheet for a Spotlight story: close button, disclaimer, and the
/// Report Story / Bookmark actions.
class StoryOptionsSheet extends StatelessWidget {
  const StoryOptionsSheet({super.key, required this.isBookmarked});

  final bool isBookmarked;

  /// Same sheet for every story — desk articles and citizen posts alike.
  static Future<StoryOption?> show(
    BuildContext context, {
    required bool isBookmarked,
  }) {
    return showModalBottomSheet<StoryOption>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54, // dims the article behind
      builder: (_) => StoryOptionsSheet(isBookmarked: isBookmarked),
    );
  }

  static bool get _telugu => AppState.instance.language == 'Telugu';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black;
    const subtitleColor = Color(0xFF8A8A8E);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Close: grey circle, white X, top-right.
            Align(
              alignment: Alignment.topRight,
              child: Semantics(
                button: true,
                label: _telugu ? 'మూసివేయి' : 'Close',
                child: GestureDetector(
                  key: const Key('story_options_close'),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9E9E9E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _Disclaimer(color: subtitleColor),
            ),
            const SizedBox(height: 18),

            _OptionTile(
              key: const Key('story_option_report'),
              icon: Icons.warning_amber_rounded,
              title: _telugu ? 'స్టోరీని నివేదించండి' : 'Report Story',
              subtitle: _telugu
                  ? 'మెరుగుపడటానికి మాకు సహాయం చేయండి'
                  : 'Help us improve better',
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              onTap: () => Navigator.of(context).pop(StoryOption.report),
            ),
            _OptionTile(
              key: const Key('story_option_bookmark'),
              icon: isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              title: _telugu
                  ? (isBookmarked ? 'బుక్‌మార్క్ చేయబడింది' : 'బుక్‌మార్క్')
                  : (isBookmarked ? 'Bookmarked' : 'Bookmark'),
              subtitle: _telugu
                  ? (isBookmarked
                      ? 'తీసివేయడానికి నొక్కండి'
                      : 'తర్వాత చదవడానికి సేవ్ చేయండి')
                  : (isBookmarked ? 'Tap to remove' : 'Save to read later'),
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              onTap: () => Navigator.of(context).pop(StoryOption.bookmark),
            ),
          ],
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: 12.5, height: 1.45, color: color);
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final telugu = AppState.instance.language == 'Telugu';
    final spans = telugu
        ? [
            const TextSpan(text: 'ఈ కథనం '),
            TextSpan(text: 'వారధి న్యూస్ నెట్‌వర్క్', style: bold),
            const TextSpan(text: ' పాత్రికేయ కాపీరైట్ కాదు మరియు '),
            TextSpan(text: 'వారధి', style: bold),
            const TextSpan(text: ' అభిప్రాయాలను ప్రతిబింబించదు'),
          ]
        : [
            const TextSpan(
                text: 'The story is not journalistic copyrighted by the '),
            TextSpan(text: 'Vaaradhi News Network', style: bold),
            const TextSpan(text: ' and does not reflect the views of '),
            TextSpan(text: 'Vaaradhi', style: bold),
          ];
    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: TextAlign.center,
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 26, color: titleColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: titleColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: subtitleColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Story actions shared by Spotlight and the detail screen, so every story —
/// desk article or citizen post — is handled the same way.
class StoryActions {
  StoryActions._();

  @visibleForTesting
  static const String reportedKey = 'reported_story_ids';

  /// Report Story, identical for every story and open to everyone — no
  /// login first. The reader picks what is wrong, optionally explains, and
  /// the report goes straight to the backend moderation queue
  /// (POST /articles/{id}/report/ or /ugc/report/).
  ///
  /// Should the server still require an account for this (401), the reader
  /// is asked to log in once and the same report is then sent automatically —
  /// nothing has to be picked or typed again.
  static Future<void> report(BuildContext context, NewsArticle article,
      {ContentEngagementService? service}) async {
    final engagement = service ?? ContentEngagementService.instance;
    final telugu = AppState.instance.language == 'Telugu';
    final messenger = ScaffoldMessenger.maybeOf(context);
    final storyId = article.id.isNotEmpty ? article.id : article.slug;

    void toast(String te, String en) => messenger?.showSnackBar(SnackBar(
          content: Text(telugu ? te : en),
          behavior: SnackBarBehavior.floating,
        ));

    // This device already reported it: say so instead of a second report.
    if (await _wasReported(storyId)) {
      toast('మీరు ఇప్పటికే ఈ స్టోరీని నివేదించారు.',
          'You have already reported this story.');
      return;
    }
    if (!context.mounted) return;

    Future<ReportOutcome> send(ReportKind kind, String details) => engagement
        .report(article, reason: kind.code, notes: kind.notesWith(details));

    final result = await ReportStorySheet.show(context, onSubmit: send);
    if (result == null) return;

    var outcome = result.outcome;
    if (outcome == ReportOutcome.loginRequired) {
      if (!context.mounted) return;
      toast('నివేదిక పంపడానికి ఒకసారి లాగిన్ అవ్వండి.',
          'Please log in once to send your report.');
      if (!await ensureAuth(context)) return;
      outcome = await send(result.kind, result.details);
    }

    switch (outcome) {
      case ReportOutcome.sent:
        await _markReported(storyId);
        toast('ధన్యవాదాలు! మీ నివేదిక సమీక్షకు పంపబడింది.',
            'Thanks — your report was sent for review.');
      case ReportOutcome.alreadyReported:
        await _markReported(storyId);
        toast('మీరు ఇప్పటికే ఈ స్టోరీని నివేదించారు.',
            'You have already reported this story.');
      case ReportOutcome.notFound:
        toast('ఈ స్టోరీ ఇప్పుడు అందుబాటులో లేదు.',
            'This story is no longer available.');
      case ReportOutcome.throttled:
        toast('చాలా నివేదికలు పంపారు. కొద్దిసేపు ఆగి మళ్లీ ప్రయత్నించండి.',
            'Too many reports. Please try again in a moment.');
      case ReportOutcome.loginRequired:
      case ReportOutcome.invalid:
      case ReportOutcome.failed:
        toast('నివేదిక పంపలేకపోయాము. మళ్లీ ప్రయత్నించండి.',
            'Could not send the report. Please try again.');
    }
  }

  static Future<bool> _wasReported(String id) async {
    if (id.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(reportedKey) ?? const []).contains(id);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _markReported(String id) async {
    if (id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(reportedKey) ?? <String>[];
      if (ids.contains(id)) return;
      ids.add(id);
      // Bounded: the newest 500 are plenty to stop accidental repeats.
      await prefs.setStringList(
          reportedKey, ids.length > 500 ? ids.sublist(ids.length - 500) : ids);
    } catch (_) {}
  }
}
