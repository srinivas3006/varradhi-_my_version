import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';

/// Carries Spotlight activity through the existing specialized ad widgets.
class AdActivityScope extends InheritedWidget {
  final bool active;
  const AdActivityScope(
      {super.key, required this.active, required super.child});
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdActivityScope>()?.active ??
      true;
  @override
  bool updateShouldNotify(AdActivityScope oldWidget) =>
      active != oldWidget.active;
}

/// Counts an exposure only after continuous foreground visibility.
class AdViewabilityDetector extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;
  final Widget child;
  final bool active;
  final double minVisibilityFraction;
  final Duration impressionDwell;
  final Duration viewabilityDwell;

  const AdViewabilityDetector({
    super.key,
    required this.ad,
    this.placementZone = 'feed',
    this.exposureKey,
    required this.child,
    this.active = true,
    this.minVisibilityFraction = 0.5,
    this.impressionDwell = const Duration(seconds: 1),
    this.viewabilityDwell = const Duration(seconds: 1),
  });

  @override
  State<AdViewabilityDetector> createState() => _AdViewabilityDetectorState();
}

class _AdViewabilityDetectorState extends State<AdViewabilityDetector>
    with WidgetsBindingObserver {
  static int _nextExposure = 0;
  late String _instanceExposure;
  Timer? _impressionTimer;
  Timer? _viewabilityTimer;
  bool _impressionFired = false;
  bool _viewabilityFired = false;
  bool _visible = false;
  bool _scopeActive = true;
  bool _foreground = true;
  String get _exposure => widget.exposureKey ?? _instanceExposure;

  @override
  void initState() {
    super.initState();
    _instanceExposure = 'exposure_${_nextExposure++}';
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeActive = AdActivityScope.isActive(context);
    _syncTimers();
  }

  @override
  void didUpdateWidget(covariant AdViewabilityDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.id != widget.ad.id ||
        oldWidget.exposureKey != widget.exposureKey ||
        oldWidget.placementZone != widget.placementZone) {
      _cancelTimers();
      _impressionFired = false;
      _viewabilityFired = false;
      _visible = false;
      _instanceExposure = 'exposure_${_nextExposure++}';
    }
    _syncTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimers();
  }

  void _cancelTimers() {
    _impressionTimer?.cancel();
    _viewabilityTimer?.cancel();
    _impressionTimer = null;
    _viewabilityTimer = null;
  }

  bool get _eligible =>
      mounted && widget.active && _scopeActive && _visible && _foreground;

  void _syncTimers() {
    if (!_eligible) {
      _cancelTimers();
      return;
    }
    if (!_impressionFired && _impressionTimer == null) {
      _impressionTimer = Timer(widget.impressionDwell, () {
        if (!_eligible || _impressionFired) return;
        _impressionFired = true;
        AdManager.instance.recordImpression(widget.ad,
            placementZone: widget.placementZone, contextKey: _exposure);
      });
    }
    if (!_viewabilityFired && _viewabilityTimer == null) {
      _viewabilityTimer = Timer(widget.viewabilityDwell, () {
        if (!_eligible || _viewabilityFired) return;
        _viewabilityFired = true;
        AdManager.instance.recordViewability(widget.ad,
            placementZone: widget.placementZone, contextKey: _exposure);
      });
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
        key: ValueKey(
            'ad_${widget.ad.id}_${widget.placementZone}_${_exposure}_$_instanceExposure'),
        onVisibilityChanged: (info) {
          _visible = info.visibleFraction >= widget.minVisibilityFraction;
          _syncTimers();
        },
        child: widget.child,
      );
}
