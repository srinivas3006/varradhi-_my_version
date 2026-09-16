import 'package:flutter/material.dart';
import '../../core/ads/ad_type_resolver.dart';
import '../../models/ad_banner.dart';
import 'ad_banner_widget.dart';
import 'box_ad_widget.dart';
import 'three_d_ad_widget.dart';
import 'poster_ad_widget.dart';
import 'breaking_strip_ad_widget.dart';
import 'local_listing_ad_widget.dart';
import 'bottom_sticky_ad_banner.dart';
import 'native_ad_card.dart';
import 'video_ad_card.dart';
import 'ad_viewability_detector.dart';

/// Master frontend ad component that resolves any backend [ad.adType]
/// into its required fixed aspect-ratio container and specialized UI layout.
///
/// Ensures compliance with:
/// - Fixed UI aspect ratios per ad type (no stretching, BoxFit.cover)
/// - Separation of image_url and video_url (no treating image_url as video)
/// - Guaranteed 'Sponsored' / 'Ad' badges
/// - Verified destination URL handling
/// - Automatic impression & viewability tracking
class UnifiedAdWidget extends StatelessWidget {
  final AdBanner ad;
  final bool active;
  final String placementZone;
  final String? exposureKey;

  const UnifiedAdWidget({
    super.key,
    required this.ad,
    this.active = true,
    this.placementZone = 'feed',
    this.exposureKey,
  });

  @override
  Widget build(BuildContext context) =>
      AdActivityScope(active: active, child: _buildCreative(context));

  Widget _buildCreative(BuildContext context) {
    // ad_type picks the component, nothing else. This used to short-circuit
    // on ad.isVideo, which is true for any ad merely carrying a video_url —
    // so a full_screen or poster creative with a video attached rendered as a
    // 16:9 video card instead of its declared type. The switch below already
    // has a videoCard case, driven by ad_type.
    final presentationType = AdTypeResolver.resolve(ad);

    switch (presentationType) {
      case AdPresentationType.banner:
        return AdBannerWidget(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );

      case AdPresentationType.box:
        return BoxAdWidget(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );

      case AdPresentationType.threeD:
        return ThreeDAdWidget(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );

      case AdPresentationType.poster:
        return PosterAdWidget(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );

      case AdPresentationType.breakingStrip:
        return BreakingStripAdWidget(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );

      case AdPresentationType.localListing:
        return LocalListingAdWidget(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );

      case AdPresentationType.bottomSticky:
        return BottomStickyAdBanner(
          ad: ad,
          placementZone: placementZone,
        );

      case AdPresentationType.nativeCard:
      case AdPresentationType.sponsoredCard:
        return NativeAdCard(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );

      case AdPresentationType.videoCard:
        return VideoAdCard(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );

      case AdPresentationType.interstitial:
      case AdPresentationType.fullScreen:
        // Interstitials/full-screen are screen-transition ads shown via showInterstitialAd
        // For inline feed presentation, fallback gracefully to native card or banner
        return NativeAdCard(
          ad: ad,
          placementZone: placementZone,
          exposureKey: exposureKey,
        );
      case AdPresentationType.unsupported:
        return const SizedBox.shrink();
    }
  }
}
