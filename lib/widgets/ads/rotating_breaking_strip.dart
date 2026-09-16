import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ad_banner.dart';
import 'breaking_strip_ad_widget.dart';

/// A ticker slot that cycles through its creatives on a timer.
///
/// `breaking_strip` holds one fixed place near the top of the feed rather
/// than being dealt between articles, so with several eligible creatives the
/// slot has to rotate or all but the first would never be seen — which is
/// exactly what a `firstWhere` at the call site produced.
///
/// Each creative that comes up reports its own impression, because each is a
/// separate view the advertiser is owed. That falls out of the keyed child:
/// a new [BreakingStripAdWidget] instance gets a fresh exposure key from
/// AdViewabilityDetector.
class RotatingBreakingStrip extends StatefulWidget {
  const RotatingBreakingStrip({
    super.key,
    required this.ads,
    this.placementZone = 'strip',
    this.rotateEvery = const Duration(seconds: 15),
  });

  /// Eligible strip creatives, in backend order.
  final List<AdBanner> ads;
  final String placementZone;

  /// 15s is the middle of the permitted 10–20s for a ticker strip.
  final Duration rotateEvery;

  @override
  State<RotatingBreakingStrip> createState() => _RotatingBreakingStripState();
}

class _RotatingBreakingStripState extends State<RotatingBreakingStrip> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(RotatingBreakingStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed pool restarts the cycle rather than leaving the index
    // pointing past the end of a shorter list.
    if (oldWidget.ads.length != widget.ads.length) {
      _index = 0;
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    // One creative has nothing to rotate to; running a timer for it would
    // rebuild the strip every few seconds for no reason.
    if (widget.ads.length < 2) return;
    if (widget.rotateEvery <= Duration.zero) return;

    _timer = Timer.periodic(widget.rotateEvery, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.ads.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) return const SizedBox.shrink();
    final ad = widget.ads[_index % widget.ads.length];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: BreakingStripAdWidget(
        // Keyed by ad id so the switcher animates between creatives and each
        // one mounts fresh — which is what makes its impression fire.
        key: ValueKey(ad.id),
        ad: ad,
        placementZone: widget.placementZone,
      ),
    );
  }
}
