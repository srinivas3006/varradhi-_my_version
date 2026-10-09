import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/content_engagement_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_ui.dart' show AuthPrimaryButton, AuthErrorBox;

/// What the reader can report a story for.
///
/// [code] is the reason the backend accepts for article reports
/// (`misinformation`, `inappropriate`, `copyright`, `other`). Two kinds share
/// a code, so the notes always begin with the [label] the reader picked and
/// the moderation queue can tell them apart.
enum ReportKind {
  mistakes('mistakes', 'other', 'Mistakes observed', 'తప్పులు గమనించాను',
      Icons.spellcheck_rounded),
  wrongContent('wrong_content', 'misinformation', 'Wrong content',
      'తప్పుడు సమాచారం', Icons.report_gmailerrorred_rounded),
  hateful('hateful', 'inappropriate', 'Hateful statements',
      'ద్వేషపూరిత వ్యాఖ్యలు', Icons.sentiment_very_dissatisfied_rounded),
  biased(
      'biased', 'other', 'Biased story', 'పక్షపాత కథనం', Icons.balance_rounded),
  copyright('copyright', 'copyright', 'Copyright violation', 'కాపీరైట్ ఉల్లంఘన',
      Icons.copyright_rounded);

  const ReportKind(
      this.key, this.code, this.label, this.teluguLabel, this.icon);

  final String key;

  /// Sent as `reason`.
  final String code;

  /// English label; also the prefix of the notes sent to the backend.
  final String label;
  final String teluguLabel;
  final IconData icon;

  /// `notes` for the API: "Wrong content — <what the reader typed>".
  String notesWith(String details) {
    final text = details.trim();
    final notes = text.isEmpty ? label : '$label — $text';
    return notes.length > ContentEngagementService.maxReportNotes
        ? notes.substring(0, ContentEngagementService.maxReportNotes)
        : notes;
  }
}

/// What the sheet hands back once it closes.
class ReportSheetResult {
  const ReportSheetResult(this.outcome, this.kind, this.details);
  final ReportOutcome outcome;
  final ReportKind kind;
  final String details;
}

/// "Report Mistake" bottom sheet: pick a kind, optionally explain, Report.
///
/// The report is sent from inside the sheet so the button can show progress
/// and a failure can be retried without retyping. The sheet closes on any
/// final answer (sent, already reported, story gone, login needed).
class ReportStorySheet extends StatefulWidget {
  const ReportStorySheet({super.key, required this.onSubmit});

  final Future<ReportOutcome> Function(ReportKind kind, String details)
      onSubmit;

  static Future<ReportSheetResult?> show(
    BuildContext context, {
    required Future<ReportOutcome> Function(ReportKind kind, String details)
        onSubmit,
  }) {
    return showModalBottomSheet<ReportSheetResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => ReportStorySheet(onSubmit: onSubmit),
    );
  }

  /// Longest detail text the reader can type (leaves room for the label
  /// prefix inside the backend's 1000-character notes).
  static const int maxDetails = 900;

  @override
  State<ReportStorySheet> createState() => _ReportStorySheetState();
}

class _ReportStorySheetState extends State<ReportStorySheet> {
  final _details = TextEditingController();
  ReportKind? _kind;
  bool _sending = false;
  String? _error;

  bool get _telugu => AppState.instance.language == 'Telugu';

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final kind = _kind;
    if (kind == null || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final details = _details.text.trim();
    final outcome = await widget.onSubmit(kind, details);
    if (!mounted) return;

    switch (outcome) {
      case ReportOutcome.sent:
      case ReportOutcome.alreadyReported:
      case ReportOutcome.notFound:
      case ReportOutcome.loginRequired:
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(ReportSheetResult(outcome, kind, details));
        return;
      case ReportOutcome.throttled:
        _showError('చాలా నివేదికలు పంపారు. కొద్దిసేపు ఆగి మళ్లీ ప్రయత్నించండి.',
            'Too many reports. Please wait a moment and try again.');
      case ReportOutcome.invalid:
        _showError('నివేదిక వివరాలు సరిగా లేవు. తనిఖీ చేసి మళ్లీ పంపండి.',
            'Something in the report is not valid. Please check and retry.');
      case ReportOutcome.failed:
        _showError('నివేదిక పంపలేకపోయాము. ఇంటర్నెట్ చూసి మళ్లీ ప్రయత్నించండి.',
            'Could not send the report. Check your connection and retry.');
    }
  }

  void _showError(String te, String en) => setState(() {
        _sending = false;
        _error = _telugu ? te : en;
      });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheet = isDark ? AppColors.cardDarkNavy : Colors.white;
    final title = isDark ? AppColors.textLight : AppColors.textDark;
    final line = isDark ? AppColors.borderDark : const Color(0xFFEDEDF0);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        key: const Key('report_sheet'),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.flag_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _telugu ? 'తప్పును నివేదించండి' : 'Report Mistake',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: title,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('report_close'),
                      tooltip: _telugu ? 'మూసివేయి' : 'Close',
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white60 : Colors.black45),
                      onPressed:
                          _sending ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: line),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final k in ReportKind.values) ...[
                        _KindTile(
                          kind: k,
                          telugu: _telugu,
                          selected: _kind == k,
                          enabled: !_sending,
                          onTap: () => setState(() {
                            _kind = k;
                            _error = null;
                          }),
                        ),
                        if (k != ReportKind.values.last)
                          Divider(height: 1, indent: 52, color: line),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('report_details'),
                        controller: _details,
                        enabled: !_sending,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: ReportStorySheet.maxDetails,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: _telugu
                              ? 'ఇక్కడ వివరాలు టైప్ చేయండి (ఐచ్ఛికం)'
                              : 'Type here (optional)',
                          filled: true,
                          fillColor: isDark
                              ? AppColors.surfaceElevatedDark
                              : const Color(0xFFF2F2F4),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_error != null)
                        AuthErrorBox(_error!, key: const Key('report_error')),
                      AuthPrimaryButton(
                        key: const Key('report_submit'),
                        label: _telugu ? 'నివేదించండి' : 'Report',
                        icon: Icons.send_rounded,
                        busy: _sending,
                        // Off until a kind is picked.
                        onPressed: _kind == null ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.telugu,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ReportKind kind;
  final bool telugu;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.textLight : AppColors.textDark;
    return InkWell(
      key: Key('report_kind_${kind.key}'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Radio look, in the brand red.
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : (isDark ? Colors.white38 : Colors.black38),
                  width: selected ? 6.5 : 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Icon(kind.icon,
                size: 20,
                color: selected
                    ? AppColors.primary
                    : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                telugu ? kind.teluguLabel : kind.label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
