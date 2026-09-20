import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/sharing/share_content_builder.dart';
import 'sharing/share_sheet.dart';

class PollCard extends StatefulWidget {
  final Poll poll;
  final ValueChanged<int>? onVoted;

  const PollCard({super.key, required this.poll, this.onVoted});

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  bool _isVoting = false;

  Future<void> _vote(int index) async {
    if (widget.poll.selectedOption != null || _isVoting) return;

    setState(() {
      _isVoting = true;
      if (index < widget.poll.votes.length) {
        widget.poll.votes[index]++;
      }
      widget.poll.totalVotes++;
      widget.poll.selectedOption = index;
      if (widget.poll.optionItems.isNotEmpty && index < widget.poll.optionItems.length) {
        widget.poll.selectedOptionId = widget.poll.optionItems[index].id;
      }
    });

    final optionId = (widget.poll.optionItems.isNotEmpty && index < widget.poll.optionItems.length)
        ? widget.poll.optionItems[index].id
        : null;

    final success = await ApiService.instance.submitPollVote(
      widget.poll.id,
      optionId: optionId,
      optionIndex: index,
    );

    if (!mounted) return;

    setState(() {
      _isVoting = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not register vote. Please check your connection.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      widget.onVoted?.call(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final hasVoted = poll.selectedOption != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.chipBg;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.poll_rounded, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'COMMUNITY POLL',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_isVoting)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                Text(
                  '${poll.totalVotes} votes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  poll.question,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.3,
                  ),
                ),
              ),
              // Shares the question and how to vote. Only public poll data
              // travels — never voter identity or tallies beyond what the
              // card already shows.
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.share_rounded,
                    size: 18, color: textColor.withValues(alpha: 0.6)),
                tooltip: 'Share poll',
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
          const SizedBox(height: 16),
          ...List.generate(poll.options.length, (index) {
            final percent = poll.percentFor(index);
            final isSelected = poll.selectedOption == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: hasVoted || _isVoting ? null : () => _vote(index),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    return Stack(
                      children: [
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppColors.primary, width: 1.5)
                                : null,
                          ),
                        ),
                        if (hasVoted)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            height: 44,
                            width: maxWidth * (percent.clamp(0.0, 1.0)),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.28)
                                  : AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                if (isSelected) ...[
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    poll.options[index],
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : textColor,
                                    ),
                                  ),
                                ),
                                if (hasVoted)
                                  Text(
                                    '${(percent * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.white70 : AppColors.textDark),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
