import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/poll.dart';
import '../services/api_service.dart';
import '../services/poll_exposure.dart';
import '../services/poll_context.dart';
import '../services/sharing/share_content_builder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/article_typography.dart';
import 'sharing/share_sheet.dart';

/// A community poll with server-confirmed voting and results.
class PollCard extends StatefulWidget {
  final Poll? poll;
  final String pollId;
  final ValueChanged<int>? onVoted;
  final ValueChanged<String>? onUnavailable;
  final bool trackExposure;

  PollCard({
    super.key,
    required Poll this.poll,
    this.onVoted,
    this.onUnavailable,
    this.trackExposure = true,
  }) : pollId = poll.id;

  const PollCard.detail({super.key, required this.pollId})
      : poll = null,
        onVoted = null,
        onUnavailable = null,
        trackExposure = false;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  late PollReader _reader;
  Poll? _poll;
  String? _choice;
  String? _message;
  bool _isVoting = false;
  bool _loading = false;
  bool _requiresDetail = false;
  bool _unavailable = false;
  bool _forceClosed = false;
  bool _justVoted = false;
  Timer? _cooldown;
  Timer? _expiry;
  int _generation = 0;

  bool get _telugu => AppState.instance.language == 'Telugu';

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_readerChanged);
    _reader = currentPollReader;
    _start();
  }

  @override
  void didUpdateWidget(covariant PollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pollId != oldWidget.pollId || widget.poll != oldWidget.poll) {
      _reset();
      _reader = currentPollReader;
      _start();
    }
  }

  void _reset() {
    ++_generation;
    _cooldown?.cancel();
    _cooldown = null;
    _expiry?.cancel();
    _poll = null;
    _choice = null;
    _message = null;
    _isVoting = false;
    _loading = false;
    _requiresDetail = false;
    _unavailable = false;
    _forceClosed = false;
    _justVoted = false;
  }

  void _start() {
    final initial = widget.poll;
    final owner =
        initial == null ? null : ApiService.instance.pollReaderOf(initial);
    if (initial != null && (owner == null || owner == _reader)) {
      _showPoll(initial);
    } else {
      unawaited(_reload());
    }
  }

  void _readerChanged() {
    final reader = currentPollReader;
    if (_reader == reader) return;
    setState(() {
      _reset();
      _reader = reader;
    });
    unawaited(_reload());
  }

  void _showPoll(Poll poll) {
    _poll = poll;
    _expiry?.cancel();
    final end = poll.endsAt;
    if (!poll.closed && end != null) {
      _expiry = Timer(end.difference(DateTime.now()), () {
        if (mounted) setState(() => _forceClosed = true);
      });
    }
    if (widget.trackExposure) {
      unawaited(PollExposure.instance.markShown(poll.id));
    }
  }

  bool _current(int generation) =>
      mounted && generation == _generation && _reader == currentPollReader;

  Future<void> _reload(
      {bool preserveMessage = false, bool refreshResults = false}) async {
    if (_loading || _cooldown != null) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _requiresDetail = true;
      if (!preserveMessage) _message = null;
    });
    try {
      final poll = await ApiService.instance.fetchPollDetail(widget.pollId);
      if (!_current(generation)) return;
      if (!poll.isActive) {
        _showUnavailable();
        return;
      }
      setState(() {
        _showPoll(poll);
        _requiresDetail = false;
        _unavailable = false;
        if (refreshResults) _forceClosed = false;
        if (poll.hasVoted || poll.closed) _message = null;
        if ((_justVoted && !poll.hasVoted) ||
            !poll.optionItems
                .any((option) => option.canVote && option.id == _choice)) {
          _choice = null;
        }
        if (!poll.hasVoted) _justVoted = false;
      });
    } on PollFailure catch (failure) {
      if (_current(generation)) _showFailure(failure);
    } finally {
      if (_current(generation)) setState(() => _loading = false);
    }
  }

  void _showUnavailable() {
    setState(() {
      _poll = null;
      _unavailable = true;
      _requiresDetail = false;
    });
    widget.onUnavailable?.call(widget.pollId);
  }

  void _showFailure(PollFailure failure) {
    if (failure.problem == PollProblem.readerChanged) return;
    if (failure.problem == PollProblem.unavailable ||
        failure.problem == PollProblem.eligibility) {
      _showUnavailable();
      return;
    }
    setState(() {
      _message = failure.message ??
          (_telugu
              ? 'పోల్ అభ్యర్థనను పూర్తి చేయలేకపోయాం. మళ్లీ ప్రయత్నించండి.'
              : 'Could not complete the poll request. Please try again.');
      if (failure.retryAfter case final delay? when delay > Duration.zero) {
        _cooldown?.cancel();
        _cooldown = Timer(delay, () {
          if (mounted) setState(() => _cooldown = null);
        });
      }
    });
  }

  Future<void> _vote() async {
    final poll = _poll;
    final choice = _choice;
    if (poll == null ||
        choice == null ||
        poll.hasVoted ||
        poll.closed ||
        _forceClosed ||
        _requiresDetail ||
        _loading ||
        _isVoting ||
        _cooldown != null ||
        !poll.optionItems.any((o) => o.canVote && o.id == choice)) {
      return;
    }
    final generation = _generation;
    HapticFeedback.selectionClick();
    setState(() {
      _isVoting = true;
      _message = null;
    });
    try {
      final result =
          await ApiService.instance.submitPollVote(poll.id, optionId: choice);
      if (!_current(generation)) return;
      setState(() {
        _showPoll(result);
        _justVoted = true;
      });
      if (result.selectedOption case final index?) widget.onVoted?.call(index);
    } on PollFailure catch (failure) {
      if (!_current(generation)) return;
      _showFailure(failure);
      switch (failure.problem) {
        case PollProblem.expired:
          setState(() => _forceClosed = true);
          await _reload(preserveMessage: true);
        case PollProblem.duplicate:
        case PollProblem.uncertain:
          await _reload(preserveMessage: true);
        case PollProblem.invalidOption:
          setState(() => _choice = null);
          await _reload(preserveMessage: true);
        case PollProblem.invalid:
          setState(() => _choice = null);
        case PollProblem.credential:
        case PollProblem.unauthorized:
          setState(() => _requiresDetail = true);
        default:
          break;
      }
    } finally {
      if (_current(generation)) setState(() => _isVoting = false);
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_readerChanged);
    _cooldown?.cancel();
    _expiry?.cancel();
    super.dispose();
  }

  String _votesLabel(int n) => _telugu
      ? '$n ${n == 1 ? 'ఓటు' : 'ఓట్లు'}'
      : '$n ${n == 1 ? 'vote' : 'votes'}';

  String? _coverageLabel(Poll poll) => switch (poll.coverage) {
        PollCoverage.global => _telugu ? 'అందరికీ' : 'Global',
        PollCoverage.state => _telugu ? 'రాష్ట్రం' : 'State',
        PollCoverage.district => _telugu ? 'జిల్లా' : 'District',
        PollCoverage.mandal => _telugu ? 'మండలం' : 'Mandal',
        PollCoverage.village => _telugu ? 'గ్రామం' : 'Village',
        PollCoverage.municipality => _telugu ? 'పట్టణం' : 'Municipality/Town',
        PollCoverage.assembly =>
          _telugu ? 'అసెంబ్లీ నియోజకవర్గం' : 'Assembly Constituency',
        null => null,
      };

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
    final poll = _poll;
    if (poll == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              const CircularProgressIndicator()
            else if (_unavailable)
              Text(_telugu ? 'పోల్ అందుబాటులో లేదు' : 'Poll unavailable',
                  key: const Key('poll_unavailable'))
            else ...[
              Text(_message ?? (_telugu ? 'పోల్‌ను తెరవండి' : 'Load poll')),
              TextButton(
                onPressed: _cooldown == null ? () => _reload() : null,
                child: Text(_telugu ? 'మళ్లీ ప్రయత్నించండి' : 'Retry'),
              ),
            ],
          ],
        ),
      );
    }
    final hasVoted = poll.hasVoted;
    final coverage = _coverageLabel(poll);
    final closed = poll.closed || _forceClosed;
    final showResults = hasVoted || closed;
    final enabled = !showResults &&
        !_isVoting &&
        !_loading &&
        !_requiresDetail &&
        _cooldown == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDarkNavy : Colors.white;
    final ink = isDark ? AppColors.textLight : AppColors.textDark;
    final muted = isDark ? AppColors.textSecondaryDark : AppColors.textMuted;
    final timeLeft = _timeLeft(poll);

    // The option with the most votes, for the "leading" mark.
    var leader = -1;
    if (showResults && poll.totalVotes > 0) {
      var best = 0;
      for (var i = 0; i < poll.votes.length; i++) {
        final count = poll.votes[i];
        if (count > best) {
          best = count;
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
                          if (coverage != null)
                            Text(
                              coverage,
                              key: const Key('poll_coverage'),
                              style: TextStyle(fontSize: 12, color: muted),
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
                          : 'Select an option to vote'),
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
                      selected: showResults
                          ? poll.selectedOption == i
                          : i < poll.optionItems.length &&
                              _choice == poll.optionItems[i].id,
                      leading: leader == i,
                      enabled: enabled &&
                          i < poll.optionItems.length &&
                          poll.optionItems[i].canVote,
                      onTap: () =>
                          setState(() => _choice = poll.optionItems[i].id),
                    ),
                  ),
                if (_message != null)
                  Text(_message!, key: const Key('poll_message')),
                if (_requiresDetail && !_loading)
                  TextButton(
                    onPressed: _cooldown == null ? () => _reload() : null,
                    child: Text(_telugu ? 'మళ్లీ ప్రయత్నించండి' : 'Retry'),
                  )
                else if (!showResults)
                  FilledButton(
                    key: const Key('poll_vote'),
                    onPressed: enabled && _choice != null ? _vote : null,
                    child: Text(_telugu ? 'ఓటు వేయండి' : 'Vote'),
                  ),
                if (showResults && !_requiresDetail)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const Key('poll_refresh'),
                      onPressed: _loading || _isVoting || _cooldown != null
                          ? null
                          : () => _reload(refreshResults: true),
                      child: Text(
                          _telugu ? 'ఫలితాలను నవీకరించండి' : 'Refresh results'),
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
      selected: selected,
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
                            color: selected ? AppColors.primary : null,
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
