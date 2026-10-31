import 'package:flutter/material.dart';

import '../../core/ads/ad_placement.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'unified_ad_widget.dart';

/// A `video_feed` ad as one full page of the Shorts / Reels pager.
///
/// A video creative uses the feed's video ad card: it starts muted once
/// visible and pauses when swiped away (it is only active while it is the
/// page on screen). "Skip" moves to the next page; for a video it also sends
/// a `skip` event.
class VideoFeedAdPage extends StatelessWidget {
  const VideoFeedAdPage({
    super.key,
    required this.ad,
    required this.active,
    required this.onSkip,
    this.exposureKey,
  });

  final AdBanner ad;
  final bool active;
  final VoidCallback onSkip;
  final String? exposureKey;

  void _skip() {
    if (ad.isVideo) {
      AdManager.instance.recordSkip(ad, placementZone: AdPlacement.videoFeed);
    }
    onSkip();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: Key('video_feed_ad_${ad.id}'),
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: UnifiedAdWidget(
                ad: ad,
                active: active,
                placementZone: AdPlacement.videoFeed,
                exposureKey: exposureKey,
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 96,
            child: SafeArea(
              top: false,
              child: TextButton.icon(
                key: const Key('video_feed_ad_skip'),
                onPressed: _skip,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: const Text('Skip'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
