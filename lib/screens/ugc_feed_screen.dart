import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class UgcFeedScreen extends StatefulWidget {
  const UgcFeedScreen({super.key});

  @override
  State<UgcFeedScreen> createState() => _UgcFeedScreenState();
}

class _UgcFeedScreenState extends State<UgcFeedScreen> {
  final List<NewsArticle> _reports = [];
  bool _isLoading = false;
  String? _nextCursor;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final response = await ApiService.instance.getUgcFeed(cursor: _nextCursor);

    if (!mounted) return;
    setState(() {
      final newArticles = response.data ?? [];
      _reports.addAll(newArticles);
      _nextCursor = response.nextCursor;
      _hasMore = _nextCursor != null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Citizen Reports'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
      ),
      body: _reports.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _reports.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _reports.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final report = _reports[index];
                return _UgcReportCard(report: report);
              },
            ),
    );
  }
}

class _UgcReportCard extends StatelessWidget {
  final NewsArticle report;

  const _UgcReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.source,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Text(
                      'Local Reporter • Just now',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
                color: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          if (report.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                report.imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionItem(icon: Icons.thumb_up_alt_outlined, count: report.likes.toString()),
              _ActionItem(icon: Icons.comment_outlined, count: report.comments.toString()),
              _ActionItem(icon: Icons.share_outlined, count: report.shares.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String count;

  const _ActionItem({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(count, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    );
  }
}
