import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/poll.dart';
import '../services/api_service.dart';
import '../services/poll_exposure.dart';
import '../services/sharing/share_content_builder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/article_typography.dart';
import 'sharing/share_sheet.dart';

/// A community poll: question, options, live results after voting.
///
/// Before the vote every option is a tappable row with an empty radio; one
/// tap votes. After the vote the rows turn into result bars, the reader's
/// pick is ticked and the leading option is marked.
class PollCard extends StatefulWidget {
  final Poll poll;
  final ValueChanged<int>? onVoted;

  /// Counts this card toward the reader's view limit for the poll
  /// ([PollExposure]). Off for the poll's own screen, opened on purpose.
  final bool trackExposure;

  const PollCard({
    super.key,
    required this.poll,
    this.onVoted,
    this.trackExposure = true,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  bool _isVoting = false;
  bool _justVoted = false;

  bool get _telugu => AppState.instance.language == 'Telugu';

  @override
  void initState() {
    super.initState();
    if (widget.trackExposure) {
      PollExposure.instance.markShown(widget.poll.id);
    }
  }

  Future<void> _vote(int index) async {
    final poll = widget.poll;
    if (poll.selectedOption != null || _isVoting) return;
    HapticFeedback.selectionClick();

    // Optimistic: results show at once; undone if the vote is not saved.
    final previousTotal = poll.totalVotes;
    setState(() {
      _isVoting = true;
      if (index < poll.votes.length) poll.votes[index]++;
      poll.totalVotes++;
      poll.selectedOption = index;
      if (poll.optionItems.isNotEmpty && index < poll.optionItems.length) {
        poll.selectedOptionId = poll.optionItems[index].id;
      }
    });

    final optionId =
        (poll.optionItems.isNotEmpty && index < poll.optionItems.length)
            ? poll.optionItems[index].id
            : null;

    final success = await ApiService.instance.submitPollVote(
      poll.id,
      optionId: optionId,
      optionIndex: index,
    );
    if (!mounted) return;

    if (!success) {
      setState(() {
        _isVoting = false;
        if (index < poll.votes.length && poll.votes[index] > 0) {
          poll.votes[index]--;
        }
        poll.totalVotes = previousTotal;
        poll.selectedOption = null;
        poll.selectedOptionId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_telugu
            ? 'ఓటు నమోదు కాలేదు. ఇంటర్నెట్ చూసి మళ్లీ ప్రయత్నించండి.'
            : 'Could not register your vote. Check your connection.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isVoting = false;
      _justVoted = true;
    });
    await PollExposure.instance.markVoted(poll.id);
    widget.onVoted?.call(index);
  }

  String _votesLabel(int n) => _telugu
      ? '$n ${n == 1 ? 'ఓటు' : 'ఓట్లు'}'
      : '$n ${n == 1 ? 'vote' : 'votes'}';

  /// "2 రోజులు మిగిలి ఉన్నాయి" / "Ends in 3 h"; null when there is no end.
  String? _timeLeft(Poll poll) {
    final end = poll.endsAt;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    if (left.isNegative || poll.isExpired) {
      return _telugu ? 'పోల్ ముగిసింది' : 'Poll closed';
    }
    if (left.inDays >= 1) {
      return _telugu
          ? '${left.inDays} రోజులు మిగిలి ఉన్నాయి'
          : '${left.inDays} days left';
    }
    final h = left.inHours.clamp(1, 23);
    return _telugu ? '$h గంటలు మిగిలి ఉన్నాయి' : '$h h left';
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final hasVoted = poll.selectedOption != null;
    final closed = poll.isExpired ||
        (poll.endsAt != null && poll.endsAt!.isBefore(DateTime.now()));
    final showResults = hasVoted || closed;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDarkNavy : Colors.white;
    final ink = isDark ? AppColors.textLight : AppColors.textDark;
    final muted = isDark ? AppColors.textSecondaryDark : AppColors.textMuted;
    final timeLeft = _timeLeft(poll);

    // The option with the most votes, for the "leading" mark.
    var leader = -1;
    if (showResults && poll.totalVotes > 0) {
      var best = -1.0;
      for (var i = 0; i < poll.options.length; i++) {
        final p = poll.percentFor(i);
        if (p > best) {
          best = p;
          leader = i;
        }
      }
    }

    return Container(
      key: const Key('poll_card'),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFEDEDF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin brand band across the top.
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFFFF8A3D)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: icon tile, label, time left / share.
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, Color(0xFFC81B00)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.how_to_vote_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _telugu ? 'ప్రజాభిప్రాయ సేకరణ' : 'Community Poll',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (timeLeft != null)
                            Text(
                              timeLeft,
                              key: const Key('poll_time_left'),
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('poll_share'),
                      tooltip: _telugu ? 'పోల్ షేర్ చేయండి' : 'Share poll',
                      icon: Icon(Icons.share_rounded, size: 20, color: muted),
                      onPressed: () => ShareSheet.show(
                        context,
                        ShareContentBuilder.fromPoll(
                          id: poll.id,
                          question: poll.question,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  poll.question,
                  key: const Key('poll_question'),
                  style: ArticleTypography.heading(
                    fontSize: 19,
                    color: ink,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  showResults
                      ? (closed && !hasVoted
                          ? (_telugu ? 'తుది ఫలితాలు' : 'Final results')
                          : (_telugu ? 'ప్రస్తుత ఫలితాలు' : 'Current results'))
                      : (_telugu
                          ? 'ఓటు వేయడానికి ఒక ఎంపికను నొక్కండి'
                          : 'Tap an option to vote'),
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < poll.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionRow(
                      key: Key('poll_option_$i'),
                      label: poll.options[i],
                      percent: poll.percentFor(i).clamp(0.0, 1.0),
                      showResults: showResults,
                      selected: poll.selectedOption == i,
                      leading: leader == i,
                      enabled: !showResults && !_isVoting,
                      onTap: () => _vote(i),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 18, color: muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _votesLabel(poll.totalVotes),
                        key: const Key('poll_total'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isVoting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    else if (hasVoted)
                      Flexible(
                        child: Row(
                          key: const Key('poll_voted_note'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 16, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _justVoted
                                    ? (_telugu
                                        ? 'ధన్యవాదాలు! ఓటు నమోదైంది'
                                        : 'Thanks! Vote counted')
                                    : (_telugu
                                        ? 'మీరు ఓటు వేశారు'
                                        : 'You voted'),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.label,
    required this.percent,
    required this.showResults,
    required this.selected,
    required this.leading,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final double percent;
  final bool showResults;
  final bool selected;
  final bool leading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textLight : AppColors.textDark;
    final track =
        isDark ? AppColors.surfaceElevatedDark : const Color(0xFFF4F4F6);
    final idleBorder = isDark ? AppColors.borderDark : const Color(0xFFE4E4E8);
    final fill = selected
        ? AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.22)
        : (leading
            ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
            : (isDark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFE9E9EE)));

    return Semantics(
      button: enabled,
      label: showResults ? '$label ${(percent * 100).round()}%' : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : idleBorder,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Result bar, grows from the left.
                if (showResults)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: percent),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => FractionallySizedBox(
                          widthFactor: v,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: fill,
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      if (!showResults)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isDark ? Colors.white38 : Colors.black26,
                                width: 2),
                          ),
                        )
                      else if (selected)
                        const Icon(Icons.check_circle_rounded,
                            size: 20, color: AppColors.primary)
                      else if (leading)
                        const Icon(Icons.emoji_events_rounded,
                            size: 20, color: Color(0xFFE0A100))
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.35,
                            fontWeight: selected || leading
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? AppColors.primary : ink,
                          ),
                        ),
                      ),
                      if (showResults) ...[
                        const SizedBox(width: 10),
                        Text(
                          '${(percent * 100).round()}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: selected ? AppColors.primary : ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
