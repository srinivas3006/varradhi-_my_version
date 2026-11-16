import 'package:flutter/material.dart';

import '../../core/ads/ad_placement.dart';
import '../../core/ads/ad_type_resolver.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_viewability_detector.dart';
import 'unified_ad_widget.dart';
import 'video_ad_card.dart';

/// A `video_feed` ad as one full page of the Shorts / Reels pager.
///
/// A video creative fills the page (as Spotlight's does): it plays with
/// sound once visible and pauses when swiped away (it is only active while it is
/// the page on screen). "Skip" moves to the next page; for a video it also
/// sends a `skip` event.
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

  /// A video ad of a type meant to take a whole page. Other types keep their
  /// own layout (ad_type decides, not a video_url alone).
  bool get _fullScreenVideo =>
      ad.videoUrl.trim().isNotEmpty &&
      const {
        AdPresentationType.videoCard,
        AdPresentationType.fullScreen,
        AdPresentationType.interstitial,
      }.contains(AdTypeResolver.resolve(ad));

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
        fit: StackFit.expand,
        children: [
          if (_fullScreenVideo)
            AdActivityScope(
              active: active,
              child: VideoAdCard(
                ad: ad,
                placementZone: AdPlacement.videoFeed,
                exposureKey: exposureKey,
                fullScreen: true,
              ),
            )
          else
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
          // Top right, as on the Spotlight ad: the bottom of the page holds
          // the ad's title and call to action.
          Positioned(
            right: 12,
            top: MediaQuery.paddingOf(context).top + 12,
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
        ],
      ),
    );
  }
}
