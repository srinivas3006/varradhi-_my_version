import 'package:flutter/material.dart';
import '../models/reporter_post.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'admin_post_preview_screen.dart';

/// In-app moderation screen: approve/reject pending reporter posts only.
/// Everything else admin-related (redeem/payout processing, reporter
/// management, analytics) lives on the separate admin website, not here.
/// Gated behind AdminLoginScreen's hardcoded credentials — see that file
/// for why that's an acceptable soft gate for this narrow use.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = true;
  List<ReporterPost> _pending = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchQueue();
  }

  Future<void> _fetchQueue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final queue = await ApiService.instance.getModerationQueue();
      setState(() {
        _pending = queue;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load moderation queue.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Posts')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchQueue, child: const Text('Retry')),
          ],
        ),
      );
    }
    
    if (_pending.isEmpty) {
      return const Center(
        child: Text('No posts waiting for review.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchQueue,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = _pending[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminPostPreviewScreen(post: post)),
              ).then((_) => _fetchQueue()); // Refresh when coming back
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
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
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(post.mediaUrl,
                                width: 56, height: 56, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.reporterName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                                Text(
                                    '${post.type == PostType.image ? "Image" : "Video"} · ${post.category}',
                                    style: const TextStyle(
                                        fontSize: 11.5, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(post.caption, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
