import 'package:flutter/material.dart';
import '../models/reporter_post.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  Color _statusColor(PostStatus status) {
    switch (status) {
      case PostStatus.approved:
        return const Color(0xFF10B981);
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
      case PostStatus.rejected:
        return 'Rejected';
      case PostStatus.pending:
        return 'Pending review';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final posts = AppState.instance.reporterPosts;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('My Posts')),
          body: posts.isEmpty
              ? const Center(
                  child: Text('You haven\'t posted anything yet.',
                      style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Image.network(post.mediaUrl,
                                    width: 72, height: 72, fit: BoxFit.cover),
                                if (post.type == PostType.video)
                                  Container(
                                    width: 72,
                                    height: 72,
                                    color: Colors.black26,
                                    child: const Icon(Icons.play_arrow_rounded,
                                        color: Colors.white),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                                const SizedBox(height: 4),
                                Text('${post.category} · ${_timeAgo(post.submittedAt)}',
                                    style: const TextStyle(
                                        fontSize: 11.5, color: AppColors.textMuted)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
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
                                if (post.status == PostStatus.rejected &&
                                    post.rejectionReason != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Reason: ${post.rejectionReason}',
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
