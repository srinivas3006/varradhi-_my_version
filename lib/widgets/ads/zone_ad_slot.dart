import 'package:flutter/material.dart';

import '../../core/ads/zone_ads.dart';
import '../../models/ad_banner.dart';
import '../../repositories/ad_repository.dart';
import '../../services/ad_manager.dart';
import '../../state/app_state.dart';
import 'unified_ad_widget.dart';

/// One ad for a single-slot zone (article_end): loaded once, any format the
/// zone takes, nothing at all when the zone has no ad.
class ZoneAdSlot extends StatefulWidget {
  const ZoneAdSlot({
    super.key,
    required this.placementZone,
    this.padding = EdgeInsets.zero,
    this.exposureKey,
    this.language,
    this.category,
  });

  final String placementZone;
  final EdgeInsets padding;

  /// One impression per exposure (e.g. per article).
  final String? exposureKey;
  final String? language;
  final String? category;

  @override
  State<ZoneAdSlot> createState() => _ZoneAdSlotState();
}

class _ZoneAdSlotState extends State<ZoneAdSlot> {
  AdBanner? _ad;
  int _generation = 0;
  String? _targeting;

  @override
  void initState() {
    super.initState();
    if (AdRepository.managedDeliveryEnabled) {
      AppState.instance.addListener(_targetingChanged);
    }
    _load();
  }

  Future<void> _load() async {
    final request = ++_generation;
    _targeting = AdRepository.targetingKey;
    final ad = AdRepository.managedDeliveryEnabled
        ? await AdRepository.instance.decide(
            placementZone: widget.placementZone,
            language: widget.language,
            category: widget.category,
          )
        : AdManager.instance.selectAd(await ZoneAds.load(widget.placementZone));
    if (mounted && request == _generation && ad != null) {
      setState(() => _ad = ad);
    }
  }

  void _targetingChanged() {
    if (_targeting == AdRepository.targetingKey) return;
    if (_ad != null) setState(() => _ad = null);
    _load();
  }

  @override
  void didUpdateWidget(covariant ZoneAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placementZone != widget.placementZone ||
        oldWidget.exposureKey != widget.exposureKey ||
        oldWidget.language != widget.language ||
        oldWidget.category != widget.category) {
      _ad = null;
      _load();
    }
  }

  @override
  void dispose() {
    if (AdRepository.managedDeliveryEnabled) {
      AppState.instance.removeListener(_targetingChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: UnifiedAdWidget(
        key: ValueKey(
            ad.exposure?.id ?? 'zone_ad_${widget.placementZone}_${ad.id}'),
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      ),
    );
  }
}
