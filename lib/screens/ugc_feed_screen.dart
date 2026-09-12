import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/news_article.dart';
import '../repositories/ugc_repository.dart';
import '../theme/app_theme.dart';
import 'news_detail_screen.dart';

class UgcFeedScreen extends StatefulWidget {
  const UgcFeedScreen({super.key});

  @override
  State<UgcFeedScreen> createState() => _UgcFeedScreenState();
}

class _UgcFeedScreenState extends State<UgcFeedScreen> {
  final List<NewsArticle> _reports = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _cursor;
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await UgcRepository.instance.getUgcFeed(cursor: _cursor, pageSize: 20);

      if (!mounted) return;
      setState(() {
        _reports.addAll(response.data ?? []);
        _isLoading = false;
        _cursor = response.nextCursor;
        _hasMore = response.nextCursor != null && response.nextCursor!.isNotEmpty;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_reports.isEmpty) {
            _errorMessage = 'రిపోర్ట్‌లను లోడ్ చేయడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.';
          }
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _reports.clear();
      _cursor = null;
      _hasMore = true;
    });
    await _loadMore();
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: _reports.isEmpty && _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _errorMessage != null ? Icons.error_outline_rounded : Icons.dynamic_feed_rounded,
                              size: 56,
                              color: _errorMessage != null ? AppColors.error : AppColors.textMuted.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage != null ? 'కథనాలు లోడ్ చేయడం విఫలమైంది' : 'No citizen reports yet',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage ?? 'Pull down to check for new updates.',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _refresh,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('మళ్ళీ ప్రయత్నించండి'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}

class _UgcReportCard extends StatelessWidget {
  final NewsArticle report;

  const _UgcReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final mutedColor = isDark ? Colors.white60 : AppColors.textMuted;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailScreen(article: report, slug: report.slug),
          ),
        );
      },
      child: Container(
        color: cardColor,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.source,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Local Reporter • ${report.timeAgo}',
                        style: TextStyle(
                          fontSize: 12,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.3,
              ),
            ),
            if (report.body.isNotEmpty && report.body != report.title) ...[
              const SizedBox(height: 8),
              Text(
                report.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppColors.textDark,
                  height: 1.4,
                ),
              ),
            ],
            if (report.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: report.imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 140,
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    child: Center(
                      child: Icon(Icons.broken_image_rounded, size: 36, color: mutedColor),
                    ),
                  ),
                ),
              ),
            ],
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
