import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/live_news.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LiveNewsScreen extends StatefulWidget {
  const LiveNewsScreen({super.key});

  @override
  State<LiveNewsScreen> createState() => _LiveNewsScreenState();
}

class _LiveNewsScreenState extends State<LiveNewsScreen> {
  bool _isLoading = true;
  List<LiveNews> _liveStreams = [];

  @override
  void initState() {
    super.initState();
    _fetchLiveNews();
  }

  Future<void> _fetchLiveNews() async {
    setState(() => _isLoading = true);
    try {
      final remote = await ApiService.instance.getLiveNews();
      if (mounted) {
        setState(() {
          // Strictly use API response. Never use random YouTube channels fallback.
          _liveStreams = remote;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveStreams = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeStreams = _liveStreams.where((s) => s.isLiveActive).toList();
    final upcomingStreams = _liveStreams.where((s) => s.isUpcoming).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Live Broadcasts',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchLiveNews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _fetchLiveNews,
              color: AppColors.primary,
              child: activeStreams.isEmpty && upcomingStreams.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        // 1. LIVE ACTIVE SECTION
                        if (activeStreams.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'HAPPENING NOW',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...activeStreams.map((stream) {
                            final vId = stream.youtubeVideoId.isNotEmpty
                                ? stream.youtubeVideoId
                                : (YoutubePlayerController.convertUrlToId(stream.youtubeUrl) ?? '');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _LiveVideoCard(
                                videoId: vId,
                                title: stream.title,
                                channelName: stream.channelName,
                                description: stream.description,
                              ),
                            );
                          }),
                        ],

                        // 2. UPCOMING LIVE SECTION (Optional)
                        if (upcomingStreams.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFF59E0B)),
                                SizedBox(width: 6),
                                Text(
                                  'SCHEDULED BROADCASTS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...upcomingStreams.map((stream) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: _UpcomingLiveBanner(stream: stream),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.live_tv_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Live Broadcasts Right Now',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'There are no active or scheduled live streams at the moment. Please check back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _fetchLiveNews,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveVideoCard extends StatefulWidget {
  final String videoId;
  final String title;
  final String channelName;
  final String description;

  const _LiveVideoCard({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.description,
  });

  @override
  State<_LiveVideoCard> createState() => _LiveVideoCardState();
}

class _LiveVideoCardState extends State<_LiveVideoCard> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.videoId.isNotEmpty) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          mute: false,
          showFullscreenButton: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_controller != null)
            YoutubePlayer(controller: _controller!)
          else
            Container(
              height: 200,
              color: Colors.black12,
              child: const Center(child: Icon(Icons.videocam_off_rounded, size: 48, color: Colors.grey)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (widget.channelName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.channelName,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
                if (widget.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingLiveBanner extends StatelessWidget {
  final LiveNews stream;

  const _UpcomingLiveBanner({required this.stream});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String scheduledText = 'Coming soon';
    if (stream.scheduledAt != null) {
      final diff = stream.scheduledAt!.difference(DateTime.now());
      if (diff.inMinutes > 0 && diff.inMinutes < 60) {
        scheduledText = 'Starts in ${diff.inMinutes} mins';
      } else if (diff.inHours > 0 && diff.inHours < 24) {
        scheduledText = 'Starts in ${diff.inHours} hours';
      } else if (diff.inDays > 0) {
        scheduledText = 'Scheduled for ${stream.scheduledAt!.day}/${stream.scheduledAt!.month}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stream.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      scheduledText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    if (stream.channelName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('• ${stream.channelName}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reminder set for this broadcast'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 32),
              foregroundColor: const Color(0xFFD97706),
              side: const BorderSide(color: Color(0xFFD97706)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Remind', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
