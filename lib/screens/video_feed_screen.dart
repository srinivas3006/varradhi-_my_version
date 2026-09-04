import 'package:flutter/material.dart';
import 'video_tab.dart';

/// Full-screen Video / Reels Feed Screen wrapper that delegates to [VideoTab]
/// for unified dual-engine video playback, lazy initialization, and gesture controls.
class VideoFeedScreen extends StatelessWidget {
  const VideoFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoTab();
  }
}
