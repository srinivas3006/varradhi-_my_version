import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../theme/app_theme.dart';

class LiveNewsScreen extends StatefulWidget {
  const LiveNewsScreen({super.key});

  @override
  State<LiveNewsScreen> createState() => _LiveNewsScreenState();
}

class _LiveNewsScreenState extends State<LiveNewsScreen> {
  // Mock YouTube video IDs for live news (Telugu Channels)
  final List<Map<String, String>> _liveChannels = [
    {'id': 'j6rF0N5Y0uM', 'title': 'TV9 Telugu Live - Telangana & AP Breaking News'},
    {'id': 'XWq5kBlakcQ', 'title': 'NTV Telugu Live - 24/7 Live News Updates'},
    {'id': 'O1N6mP3p4_E', 'title': 'V6 News Live - Telangana Local News'},
    {'id': 'Y8sQ-x54L_g', 'title': 'T News Live - Telangana Politics & Updates'},
    {'id': '9Auq9mYxFEE', 'title': 'Sakshi TV Live - Andhra Pradesh & TS News'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Live News'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _liveChannels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final channel = _liveChannels[index];
          return _LiveVideoCard(
            videoId: channel['id']!,
            title: channel['title']!,
          );
        },
      ),
    );
  }
}

class _LiveVideoCard extends StatefulWidget {
  final String videoId;
  final String title;

  const _LiveVideoCard({required this.videoId, required this.title});

  @override
  State<_LiveVideoCard> createState() => _LiveVideoCardState();
}

class _LiveVideoCardState extends State<_LiveVideoCard> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        mute: false,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YoutubePlayer(
            controller: _controller,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
