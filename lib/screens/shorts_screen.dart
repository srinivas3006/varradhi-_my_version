import 'package:flutter/material.dart';
import 'video_tab.dart';

/// Screen 13: ShortsScreen
/// - APIs: GET /api/v1/articles/shorts-feed/
/// - Full-screen vertical player with player disposal
class ShortsScreen extends StatelessWidget {
  const ShortsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: VideoTab(),
    );
  }
}
