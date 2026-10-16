import 'package:flutter/material.dart';

import '../../core/ads/ad_pacer.dart';
import '../../core/ads/home_ads.dart';
import '../../models/ad_banner.dart';
import 'bottom_sticky_ad_banner.dart';
import 'floating_three_d_ad.dart';

/// The ads that come and go, laid over a screen: the bottom banner and the
/// small floating 3D ad. [AdPacer] decides when each is on screen; this only
/// draws them, slides them in and out, and rotates through the pool.
///
/// Place it as `Positioned.fill` in the screen's Stack. Empty space passes
/// touches through to the screen below.
class PacedAdsOverlay extends StatefulWidget {
  const PacedAdsOverlay({
    super.key,
    required this.bottomInset,
    this.showSticky = true,
    this.showFloating = true,
    this.floatingSize = 128,
    this.pool,
  });

  /// Distance from the bottom of the screen to where the ads may start
  /// (above the nav bar or action bar).
  final double bottomInset;
  final bool showSticky;
  final bool showFloating;

  /// Edge length of the floating 3D ad.
  final double floatingSize;

  /// Ads to choose from; defaults to the Home `/ads/` response.
  @visibleForTesting
  final ValueNotifier<List<AdBanner>>? pool;

  @override
  State<PacedAdsOverlay> createState() => _PacedAdsOverlayState();
}

class _PacedAdsOverlayState extends State<PacedAdsOverlay> {
  ValueNotifier<List<AdBanner>> get _pool => widget.pool ?? HomeAds.current;

  @override
  void initState() {
    super.initState();
    AdPacer.instance.addListener(_changed);
    _pool.addListener(_changed);
  }

  @override
  void dispose() {
    AdPacer.instance.removeListener(_changed);
    _pool.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  static AdBanner? _pick(List<AdBanner> ads, int rotation) =>
      ads.isEmpty ? null : ads[rotation % ads.length];

  @override
  Widget build(BuildContext context) {
    final pacer = AdPacer.instance;
    final ads = _pool.value;
    final sticky = widget.showSticky && pacer.stickyVisible
        ? _pick(HomeAds.bottomSticky(ads), pacer.stickyRotation)
        : null;
    final floating = widget.showFloating && pacer.floatingVisible
        ? _pick(HomeAds.threeD(ads), pacer.floatingRotation)
        : null;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.bottomInset,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(begin: const Offset(0, 1.2), end: Offset.zero)
                  .animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: sticky == null
                ? const SizedBox.shrink(key: ValueKey('no_sticky'))
                : BottomStickyAdBanner(
                    key: ValueKey('paced_sticky_${sticky.id}'),
                    ad: sticky,
                    placementZone: 'feed',
                    onDismiss: () => pacer.dismiss(AdPacer.sticky),
                  ),
          ),
        ),
        Positioned(
          right: 14,
          // Sits above the banner when both are up.
          bottom: widget.bottomInset + (sticky != null ? 82 : 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: floating == null
                ? const SizedBox.shrink(key: ValueKey('no_floating'))
                : FloatingThreeDAd(
                    key: ValueKey('paced_3d_${floating.id}'),
                    ad: floating,
                    size: widget.floatingSize,
                    onClose: () => pacer.dismiss(AdPacer.floating3d),
                  ),
          ),
        ),
      ],
    );
  }
}
