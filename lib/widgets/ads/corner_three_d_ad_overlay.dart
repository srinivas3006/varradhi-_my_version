import 'package:flutter/material.dart';

import '../../core/ads/ad_pacer.dart';
import '../../core/ads/home_ads.dart';
import '../../models/ad_banner.dart';
import 'floating_three_d_ad.dart';

/// The 3D / video corner ad, over every screen of the app.
///
/// Mounted once above the Navigator (MaterialApp.builder). [AdPacer] brings
/// it every 2 minutes of use; each appearance takes the next ad of the pool,
/// the next 3D format ([ThreeDAdStyle.rotation], unless the ad names one)
/// and the next corner of the screen. Empty space passes touches through.
class CornerThreeDAdOverlay extends StatefulWidget {
  const CornerThreeDAdOverlay({super.key, this.pool, this.size = 112});

  /// Ads to choose from; defaults to the `/ads/` response.
  @visibleForTesting
  final ValueNotifier<List<AdBanner>>? pool;

  /// The corner of the [rotation]-th appearance.
  static AdCorner cornerFor(int rotation) =>
      AdCorner.values[rotation % AdCorner.values.length];

  /// Base edge length of the ad.
  final double size;

  @override
  State<CornerThreeDAdOverlay> createState() => _CornerThreeDAdOverlayState();
}

/// The four corners, in the order appearances move through them.
enum AdCorner { bottomRight, topLeft, bottomLeft, topRight }

class _CornerThreeDAdOverlayState extends State<CornerThreeDAdOverlay> {
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

  @override
  Widget build(BuildContext context) {
    final pacer = AdPacer.instance;
    final ads = HomeAds.corner3d(_pool.value);
    final rotation = pacer.floatingRotation;
    final ad = pacer.floatingVisible && ads.isNotEmpty
        ? ads[rotation % ads.length]
        : null;
    final corner = CornerThreeDAdOverlay.cornerFor(rotation);
    final pad = MediaQuery.paddingOf(context);
    // Clear of app bars at the top and nav / action bars at the bottom.
    final top = pad.top + 72;
    final bottom = pad.bottom + 92;
    final isTop = corner == AdCorner.topLeft || corner == AdCorner.topRight;
    final isLeft = corner == AdCorner.topLeft || corner == AdCorner.bottomLeft;

    // A text style for the ad, which sits above the Navigator (no Material
    // there). No Material itself: it would take touches from the screen.
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
      child: Stack(
        children: [
          Positioned(
            top: isTop ? top : null,
            bottom: isTop ? null : bottom,
            left: isLeft ? 12 : null,
            right: isLeft ? null : 12,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: ad == null
                  ? const SizedBox.shrink(key: ValueKey('no_corner_3d'))
                  : FloatingThreeDAd(
                      key: ValueKey('corner_3d_${ad.id}_$rotation'),
                      ad: ad,
                      size: widget.size,
                      style: ThreeDAdStyle.forAd(ad, rotation),
                      onClose: () => pacer.dismiss(AdPacer.floating3d),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
