import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ads/ad_placement.dart';
import '../../core/ads/ad_type_resolver.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_badge.dart';
import 'ad_viewability_detector.dart';
import 'breaking_strip_ad_widget.dart';

/// The `home_top` ad: one thin strip above the Home news list, in the space
/// the breaking strip uses. A breaking_strip creative uses its own widget; a
/// banner is cropped into the same 48dp strip. The close button hides it
/// for this Home load and sends a `dismiss` event.
class HomeTopAdStrip extends StatelessWidget {
  const HomeTopAdStrip({super.key, required this.ad, required this.onClose});

  static const height = 48.0;

  final AdBanner ad;
  final VoidCallback onClose;

  void _close() {
    AdManager.instance.recordDismiss(ad, placementZone: AdPlacement.homeTop);
    onClose();
  }

  @override
  Widget build(BuildContext context) {
    final strip = AdTypeResolver.resolve(ad) == AdPresentationType.breakingStrip
        ? BreakingStripAdWidget(
            ad: ad,
            placementZone: AdPlacement.homeTop,
            exposureKey: 'home_top_${ad.id}',
          )
        : _BannerStrip(ad: ad);
    return SizedBox(
      key: const Key('home_top_ad'),
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: strip),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              key: const Key('home_top_ad_close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: _close,
              icon: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStrip extends StatelessWidget {
  const _BannerStrip({required this.ad});

  final AdBanner ad;

  bool get _clickable => ad.destinationUrl.trim().isNotEmpty;

  Future<void> _open() async {
    // Click first, then the destination.
    AdManager.instance.recordClick(ad, placementZone: AdPlacement.homeTop);
    final uri = Uri.tryParse(ad.destinationUrl.trim());
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdViewabilityDetector(
      ad: ad,
      placementZone: AdPlacement.homeTop,
      exposureKey: 'home_top_${ad.id}',
      child: Material(
        color: const Color(0xFFF0F0F0),
        child: InkWell(
          onTap: _clickable ? _open : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ad.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: ad.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              const Positioned(left: 6, top: 6, child: AdBadge()),
            ],
          ),
        ),
      ),
    );
  }
}
