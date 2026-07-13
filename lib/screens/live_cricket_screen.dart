import 'package:flutter/material.dart';
import '../data/mock_cricket.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/banner_ad_slot.dart';

class LiveCricketScreen extends StatelessWidget {
  const LiveCricketScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'Live':
        return const Color(0xFFE8412B);
      case 'Upcoming':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Live Cricket')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: mockMatches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final match = mockMatches[index];
                return _MatchCard(
                  match: match,
                  statusColor: _statusColor(match.status),
                );
              },
            ),
          ),
          const BannerAdSlot(),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final CricketMatch match;
  final Color statusColor;

  const _MatchCard({required this.match, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (match.status == 'Live')
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                    Text(
                      match.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(match.matchTime,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          _teamRow(match.team1, match.team1Score),
          const SizedBox(height: 8),
          _teamRow(match.team2, match.team2Score),
          const Divider(height: 24),
          Text(match.note,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(match.venue,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _teamRow(String team, String score) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.chipBg,
          child: Text(team.isNotEmpty ? team[0] : '?',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(team,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        ),
        Text(score,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      ],
    );
  }
}
