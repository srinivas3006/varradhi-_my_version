import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/banner_ad_slot.dart';

class CricketMatchItem {
  final String title;
  final String series;
  final String status;
  final String team1;
  final String score1;
  final String team2;
  final String score2;

  CricketMatchItem({
    required this.title,
    required this.series,
    required this.status,
    required this.team1,
    required this.score1,
    required this.team2,
    required this.score2,
  });
}

class LiveCricketScreen extends StatefulWidget {
  const LiveCricketScreen({super.key});

  @override
  State<LiveCricketScreen> createState() => _LiveCricketScreenState();
}

class _LiveCricketScreenState extends State<LiveCricketScreen> {
  final List<CricketMatchItem> _matches = [];
  final bool _isLoading = false;

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
      appBar: AppBar(title: const Text('ప్రత్యక్ష క్రికెట్ (Live Cricket)')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _matches.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sports_cricket_rounded, size: 48, color: AppColors.textMuted),
                              SizedBox(height: 12),
                              Text(
                                'ప్రస్తుతానికి ప్రత్యక్ష మ్యాచ్‌లు లేవు',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'మ్యాచ్‌లు ప్రారంభమైనప్పుడు లైవ్ స్కోర్‌లు మరియు తాజా వివరాలు ఇక్కడ కనిపిస్తాయి.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _matches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final match = _matches[index];
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
  final CricketMatchItem match;
  final Color statusColor;

  const _MatchCard({required this.match, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                match.series,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  match.status.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(match.team1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(match.score1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(match.team2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(match.score2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}
