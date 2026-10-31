import 'package:flutter/material.dart';

import '../../core/ads/zone_ads.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'unified_ad_widget.dart';

/// One ad for a single-slot zone (article_end): loaded once, any format the
/// zone takes, nothing at all when the zone has no ad.
class ZoneAdSlot extends StatefulWidget {
  const ZoneAdSlot({
    super.key,
    required this.placementZone,
    this.padding = EdgeInsets.zero,
    this.exposureKey,
  });

  final String placementZone;
  final EdgeInsets padding;

  /// One impression per exposure (e.g. per article).
  final String? exposureKey;

  @override
  State<ZoneAdSlot> createState() => _ZoneAdSlotState();
}

class _ZoneAdSlotState extends State<ZoneAdSlot> {
  AdBanner? _ad;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ads = await ZoneAds.load(widget.placementZone);
    final ad = AdManager.instance.selectAd(ads);
    if (mounted && ad != null) setState(() => _ad = ad);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: UnifiedAdWidget(
        key: ValueKey('zone_ad_${widget.placementZone}_${ad.id}'),
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      ),
    );
  }
}
