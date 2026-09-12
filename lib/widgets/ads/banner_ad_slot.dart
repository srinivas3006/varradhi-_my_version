import 'package:flutter/material.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_banner_widget.dart';

/// An anchored banner ad slot that dynamically loads real backend banner ads.
/// If no active banner ads are returned from the backend, it collapses completely
/// (no dummy/placeholder box).
class BannerAdSlot extends StatefulWidget {
  final String placementZone;
  final double maxHeight;

  const BannerAdSlot({
    super.key,
    this.placementZone = 'banner',
    this.maxHeight = 64,
  });

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  AdBanner? _ad;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    try {
      final ads = await AdManager.instance.getAdsForZone(widget.placementZone);
      if (mounted && ads.isNotEmpty) {
        final selected = AdManager.instance.selectAd(ads, preferType: 'banner');
        if (mounted && selected != null) {
          setState(() {
            _ad = selected;
          });
        }
      }
    } catch (_) {
      // Backend unavailable or no banner ad; collapse gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ad == null) {
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: AdBannerWidget(
        ad: _ad!,
        placementZone: widget.placementZone,
      ),
    );
  }
}
