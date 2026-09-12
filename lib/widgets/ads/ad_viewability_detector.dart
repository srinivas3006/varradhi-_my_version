import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';

/// Reusable viewability detector widget that accurately determines
/// when an advertisement satisfies impression and viewability dwell thresholds.
///
/// Features:
/// - 500ms dwell at >= 50% visibility emits `impression`
/// - 2000ms dwell at >= 50% visibility emits `viewability`
/// - Fast scrolls do NOT trigger events
/// - Deduplicated via [AdManager] per exposure key
class AdViewabilityDetector extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;
  final Widget child;
  final double minVisibilityFraction;
  final Duration impressionDwell;
  final Duration viewabilityDwell;

  const AdViewabilityDetector({
    super.key,
    required this.ad,
    this.placementZone = 'feed',
    this.exposureKey,
    required this.child,
    this.minVisibilityFraction = 0.5,
    this.impressionDwell = const Duration(milliseconds: 500),
    this.viewabilityDwell = const Duration(milliseconds: 2000),
  });

  @override
  State<AdViewabilityDetector> createState() => _AdViewabilityDetectorState();
}

class _AdViewabilityDetectorState extends State<AdViewabilityDetector> {
  Timer? _impressionTimer;
  Timer? _viewabilityTimer;
  bool _impressionFired = false;
  bool _viewabilityFired = false;

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    _impressionTimer?.cancel();
    _impressionTimer = null;
    _viewabilityTimer?.cancel();
    _viewabilityTimer = null;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;

    final isSufficientlyVisible = info.visibleFraction >= widget.minVisibilityFraction;

    if (isSufficientlyVisible) {
      // 1. Dwell timer for impression
      if (!_impressionFired && _impressionTimer == null) {
        _impressionTimer = Timer(widget.impressionDwell, () {
          if (mounted && !_impressionFired) {
            _impressionFired = true;
            AdManager.instance.recordImpression(
              widget.ad,
              placementZone: widget.placementZone,
              contextKey: widget.exposureKey,
            );
          }
        });
      }

      // 2. Dwell timer for viewability
      if (!_viewabilityFired && _viewabilityTimer == null) {
        _viewabilityTimer = Timer(widget.viewabilityDwell, () {
          if (mounted && !_viewabilityFired) {
            _viewabilityFired = true;
            AdManager.instance.recordViewability(
              widget.ad,
              placementZone: widget.placementZone,
              contextKey: widget.exposureKey,
            );
          }
        });
      }
    } else {
      // Visibility dropped below threshold: cancel active dwell timers
      _cancelTimers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detectorKey = Key(
      'ad_detector_${widget.ad.id}_${widget.placementZone}_${widget.exposureKey ?? "0"}',
    );

    return VisibilityDetector(
      key: detectorKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}
