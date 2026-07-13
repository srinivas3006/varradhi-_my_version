import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../theme/app_theme.dart';

class PollCard extends StatefulWidget {
  final Poll poll;

  const PollCard({super.key, required this.poll});

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  void _vote(int index) {
    if (widget.poll.selectedOption != null) return;
    setState(() {
      widget.poll.votes[index]++;
      widget.poll.selectedOption = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final hasVoted = poll.selectedOption != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'POLL',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${poll.totalVotes} votes',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            poll.question,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(poll.options.length, (index) {
            final percent = poll.percentFor(index);
            final isSelected = poll.selectedOption == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _vote(index),
                child: Stack(
                  children: [
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.chipBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    if (hasVoted)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 42,
                        width: MediaQuery.of(context).size.width * percent * 0.78,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                poll.options[index],
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight:
                                      isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            if (hasVoted)
                              Text(
                                '${(percent * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
