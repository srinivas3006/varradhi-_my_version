import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/news_article.dart';
import '../../core/navigation/auth_guard.dart';
import '../../services/content_engagement_service.dart';
import '../../state/app_state.dart';
import '../../utils/share_service.dart';

enum StoryOption { report, bookmark }

/// Newsroom inbox that receives reports on desk stories, which have no
/// report endpoint yet.
const String kNewsroomReportInbox = 'vaaradhinewsapp@gmail.com';

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
            const TextSpan(
                text: ' పాత్రికేయ కాపీరైట్ కాదు మరియు '),
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

/// Why the reader is reporting the story. Returns the backend reason code.
class StoryReportReasonSheet {
  static Future<String?> show(BuildContext context) {
    final telugu = AppState.instance.language == 'Telugu';
    final reasons = <(String, String)>[
      ('misinformation',
          telugu ? 'తప్పుడు లేదా తప్పుదారి పట్టించే సమాచారం' : 'False or misleading'),
      ('inappropriate', telugu ? 'అనుచిత కంటెంట్' : 'Inappropriate content'),
      ('spam', telugu ? 'స్పామ్ లేదా ప్రచారం' : 'Spam or promotion'),
      ('copyright', telugu ? 'కాపీరైట్ ఉల్లంఘన' : 'Copyright issue'),
      ('other', telugu ? 'ఇతర కారణం' : 'Something else'),
    ];
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                telugu ? 'ఎందుకు నివేదిస్తున్నారు?' : 'Why are you reporting this?',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final r in reasons)
                ListTile(
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(r.$2),
                  onTap: () => Navigator.pop(sheetContext, r.$1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Story actions shared by Spotlight and the detail screen, so every story —
/// desk article or citizen post — is handled the same way.
class StoryActions {
  StoryActions._();

  /// Report Story, identical for every story: sign in, pick a reason, sent
  /// in-app through [ContentEngagementService].
  ///
  /// Only if the backend has no report endpoint for desk articles yet does
  /// it fall back to a pre-filled email to the newsroom, so no story is ever
  /// without a working report path.
  static Future<void> report(BuildContext context, NewsArticle article) async {
    // Reports are tied to an account (abuse control; the UGC endpoint
    // requires auth).
    if (!await ensureAuth(context)) return;
    if (!context.mounted) return;

    final reason = await StoryReportReasonSheet.show(context);
    if (!context.mounted || reason == null) return;
    final telugu = AppState.instance.language == 'Telugu';
    final messenger = ScaffoldMessenger.maybeOf(context);

    void toast(String te, String en) => messenger?.showSnackBar(SnackBar(
          content: Text(telugu ? te : en),
          behavior: SnackBarBehavior.floating,
        ));

    final outcome = await ContentEngagementService.instance
        .report(article, reason: reason);
    switch (outcome) {
      case ReportOutcome.sent:
        toast('నివేదిక సమీక్షకు పంపబడింది. ధన్యవాదాలు.',
            'Thanks — your report was sent for review.');
        return;
      case ReportOutcome.alreadyReported:
        toast('మీరు ఇప్పటికే ఈ స్టోరీని నివేదించారు.',
            'You have already reported this story.');
        return;
      case ReportOutcome.failed:
        toast('నివేదిక పంపలేకపోయాము. మళ్లీ ప్రయత్నించండి.',
            'Could not send the report. Please try again.');
        return;
      case ReportOutcome.unsupported:
        final ok = await _emailReport(article, reason);
        if (!ok) {
          toast('నివేదిక పంపలేకపోయాము. మళ్లీ ప్రయత్నించండి.',
              'Could not send the report. Please try again.');
        }
        return;
    }
  }

  static Future<bool> _emailReport(NewsArticle article, String reason) async {
    final link = ShareService.buildWebArticleUrl(article);
    final uri = Uri(
      scheme: 'mailto',
      path: kNewsroomReportInbox,
      query: _encodeQuery({
        'subject': 'Report Story: ${article.title}',
        'body': 'Reason: $reason\n'
            'Story: $link\n'
            'ID: ${article.id.isNotEmpty ? article.id : article.slug}\n\n'
            'Details (optional):\n',
      }),
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('StoryActions: report email failed: $e');
      return false;
    }
  }

  /// mailto needs %20 rather than '+' for spaces, which Uri's
  /// queryParameters would produce.
  static String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}
