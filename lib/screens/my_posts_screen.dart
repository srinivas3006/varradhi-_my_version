import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/reporter_post.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'approved', 'published', 'rejected'
  bool _isLoading = true;
  List<ReporterPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    setState(() => _isLoading = true);
    try {
      final remotePosts = await ApiService.instance.getReporterSubmissions(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      if (mounted) {
        setState(() {
          _posts = remotePosts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts = [];
          _isLoading = false;
        });
      }
    }
  }

  Color _statusColor(PostStatus status) {
    switch (status) {
      case PostStatus.approved:
        return const Color(0xFF10B981);
      case PostStatus.published:
        return const Color(0xFF3B82F6);
      case PostStatus.rejected:
        return const Color(0xFFE8412B);
      case PostStatus.pending:
        return const Color(0xFFE8A312);
    }
  }

  String _statusLabel(PostStatus status) {
    switch (status) {
      case PostStatus.approved:
        return 'Approved · +1 token';
      case PostStatus.published:
        return 'Published';
      case PostStatus.rejected:
        return 'Rejected';
      case PostStatus.pending:
        return 'Pending review';
    }
  }

  String _emptyMessage(String filter) {
    switch (filter) {
      case 'pending':
        return 'No submissions currently pending review.';
      case 'approved':
        return 'No approved submissions awaiting publication.';
      case 'published':
        return 'No published submissions yet.';
      case 'rejected':
        return 'No rejected submissions.';
      default:
        return 'You haven\'t posted anything yet.';
    }
  }

  Widget _buildFilterBar(bool isDark, int Function(String) countFor) {
    final filters = [
      {'key': 'all', 'label': 'All', 'color': AppColors.primary},
      {'key': 'pending', 'label': 'Pending', 'color': const Color(0xFFE8A312)},
      {'key': 'approved', 'label': 'Approved', 'color': const Color(0xFF10B981)},
      {'key': 'published', 'label': 'Published', 'color': const Color(0xFF3B82F6)},
      {'key': 'rejected', 'label': 'Rejected', 'color': const Color(0xFFE8412B)},
    ];

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final key = f['key'] as String;
          final label = f['label'] as String;
          final color = f['color'] as Color;
          final isSelected = _selectedFilter == key;
          final count = countFor(key);

          return GestureDetector(
            onTap: () {
              if (_selectedFilter != key) {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = key);
                _fetchSubmissions();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: isDark ? 0.25 : 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? color
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? color : (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final sourcePosts = _posts.isNotEmpty ? _posts : AppState.instance.reporterPosts;
        final displayPosts = _selectedFilter == 'all'
            ? sourcePosts
            : sourcePosts.where((p) => p.status.name == _selectedFilter).toList();

        int countFor(String filter) {
          if (filter == 'all') return sourcePosts.length;
          return sourcePosts.where((p) => p.status.name == filter).length;
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
          appBar: AppBar(
            title: const Text('My Posts'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchSubmissions,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildFilterBar(isDark, countFor),
              Expanded(
                child: _isLoading && sourcePosts.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : displayPosts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedFilter == 'rejected' ? Icons.check_circle_outline : Icons.inbox_outlined,
                                    size: 48,
                                    color: AppColors.textMuted.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _emptyMessage(_selectedFilter),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchSubmissions,
                            color: AppColors.primary,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: displayPosts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final post = displayPosts[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    children: [
                                      post.mediaUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: post.mediaUrl,
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Container(
                                                width: 72,
                                                height: 72,
                                                color: Colors.grey.shade300,
                                                child: const Icon(Icons.image_not_supported, size: 24),
                                              ),
                                            )
                                          : Container(
                                              width: 72,
                                              height: 72,
                                              color: Colors.grey.shade300,
                                              child: const Icon(Icons.article, size: 24),
                                            ),
                                      if (post.type == PostType.video)
                                        Container(
                                          width: 72,
                                          height: 72,
                                          color: Colors.black26,
                                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.caption,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${post.category} · ${_timeAgo(post.submittedAt)}',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _statusColor(post.status).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _statusLabel(post.status),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: _statusColor(post.status),
                                          ),
                                        ),
                                      ),
                                      if (post.status == PostStatus.rejected && post.rejectionReason != null && post.rejectionReason!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline, color: Colors.redAccent, size: 14),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Reason: ${post.rejectionReason}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
