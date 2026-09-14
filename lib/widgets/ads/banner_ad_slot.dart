import 'package:flutter/material.dart';
import '../../models/ad_banner.dart';
import '../../state/app_state.dart';
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
    this.placementZone = 'feed',
    this.maxHeight = 64,
  });

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  AdBanner? _ad;
  int _generation = 0;
  late String _identity;
  String get _currentIdentity => [
        AppState.instance.contentLanguage,
        AppState.instance.stateName,
        AppState.instance.district,
        AppState.instance.city,
        AppState.instance.subdistrict,
        AppState.instance.village,
        widget.placementZone
      ].join('|');
  void _onContextChanged() {
    if (_identity == _currentIdentity) return;
    _identity = _currentIdentity;
    setState(() => _ad = null);
    _loadBannerAd();
  }

  @override
  void didUpdateWidget(covariant BannerAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onContextChanged();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onContextChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _identity = _currentIdentity;
    AppState.instance.addListener(_onContextChanged);
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    final generation = ++_generation;
    try {
      final ads = await AdManager.instance.getAdsForZone(widget.placementZone);
      if (mounted && generation == _generation && ads.isNotEmpty) {
        final selected = AdManager.instance
            .selectAd(ads.where((ad) => ad.isBanner).toList());
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
