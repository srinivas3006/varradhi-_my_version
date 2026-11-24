import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/ads/ad_event_queue.dart';
import '../../core/ads/ad_video_measurement.dart';
import '../../core/media/video_playback_controller.dart';
import '../../models/ad_banner.dart';
import '../../state/app_state.dart';
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
  final VideoPlaybackController? playback;

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
    this.playback,
  });

  /// CachedNetworkImage invokes this builder only for a decoded creative.
  static Widget Function(BuildContext, ImageProvider)? imageBuilder(
      AdBanner ad) {
    final exposure = ad.exposure;
    if (exposure == null) return null;
    return (context, provider) => Image(
          image: provider,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, synchronous) {
            final media =
                context.dependOnInheritedWidgetOfExactType<_AdMedia>();
            if (frame != null && media != null) {
              return _PaintedCreative(
                key: ValueKey(exposure.id),
                onPaint: () => media.painted(exposure.id),
                child: child,
              );
            }
            return child;
          },
        );
  }

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
  double _visibleFraction = 0;
  bool _mediaPainted = false;
  bool _routeActive = true;
  Timer? _expiryTimer;
  Stopwatch? _qualifying;
  bool _available = true;
  AdVideoMeasurement? _video;
  final _clock = Stopwatch()..start();
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
    if (widget.ad.exposure != null) _listenForOfferChanges(true);
    _bindVideo();
    _scheduleExpiry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeActive = AdActivityScope.isActive(context);
    _routeActive = ModalRoute.isCurrentOf(context) ?? true;
    _syncTimers();
  }

  @override
  void didUpdateWidget(covariant AdViewabilityDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tracked = widget.ad.exposure != null;
    if (tracked != (oldWidget.ad.exposure != null)) {
      _listenForOfferChanges(tracked);
    }
    if (oldWidget.ad.exposure?.id != widget.ad.exposure?.id ||
        oldWidget.playback != widget.playback) {
      if (oldWidget.ad.exposure != null) {
        oldWidget.playback?.removeListener(_sampleVideo);
      }
      if (oldWidget.ad.exposure?.id != widget.ad.exposure?.id) {
        _finishVideo(oldWidget);
        _video = null;
      } else {
        _video?.interrupt();
      }
      _bindVideo();
    }
    if (oldWidget.ad.id != widget.ad.id ||
        oldWidget.exposureKey != widget.exposureKey ||
        oldWidget.ad.exposure?.id != widget.ad.exposure?.id ||
        oldWidget.placementZone != widget.placementZone) {
      _cancelTimers();
      _impressionFired = false;
      _viewabilityFired = false;
      _visible = false;
      _visibleFraction = 0;
      _mediaPainted = false;
      _instanceExposure = 'exposure_${_nextExposure++}';
      _scheduleExpiry();
    }
    _syncTimers();
  }

  void _listenForOfferChanges(bool listen) {
    if (listen) {
      AppState.instance.addListener(_availabilityChanged);
      AdEventQueue.instance.invalidation.addListener(_availabilityChanged);
    } else {
      AppState.instance.removeListener(_availabilityChanged);
      AdEventQueue.instance.invalidation.removeListener(_availabilityChanged);
    }
  }

  void _bindVideo() {
    final exposure = widget.ad.exposure;
    if (exposure == null || widget.playback == null) return;
    _video ??= AdVideoMeasurement(selectedDurationMs: exposure.videoDurationMs);
    widget.playback!.addListener(_sampleVideo);
  }

  bool get _foregroundVisible =>
      mounted &&
      widget.active &&
      _scopeActive &&
      _routeActive &&
      _foreground &&
      _available &&
      _visibleFraction >= 0.5;

  void _sampleVideo() {
    final playback = widget.playback;
    final video = _video;
    if (playback == null || video == null) return;
    final events = video.sample(playback.value, _clock.elapsedMilliseconds,
        eligible: _foregroundVisible);
    if (events.contains('video_start')) _painted(widget.ad.exposure!.id);
    for (final event in events) {
      AdManager.instance.recordVideoEvent(
          widget.ad, widget.placementZone, event, video.telemetry);
    }
    if (!_viewabilityFired && video.continuousMs >= 2000) {
      _viewabilityFired = true;
      AdManager.instance.recordViewability(widget.ad,
          placementZone: widget.placementZone,
          visibleFraction: _visibleFraction,
          visibleDurationMs: video.continuousMs);
    }
  }

  void _finishVideo(AdViewabilityDetector previous) {
    final video = _video;
    if (video?.hasWatched != true) return;
    AdManager.instance.recordVideoEvent(
        previous.ad, previous.placementZone, 'video_watch', video!.telemetry);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _availabilityChanged();
    _syncTimers();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _available = AdManager.instance.canDisplay(widget.ad);
    final expires = widget.ad.exposure?.expiresAt;
    if (expires == null || !_available) return;
    final end = widget.ad.endsAt;
    final deadline = end != null && end.isBefore(expires) ? end : expires;
    _expiryTimer =
        Timer(deadline.difference(DateTime.now()), _availabilityChanged);
  }

  void _availabilityChanged() {
    if (!mounted || widget.ad.exposure == null) return;
    final available = AdManager.instance.canDisplay(widget.ad);
    if (_available && !available) setState(() => _available = false);
    _syncTimers();
  }

  void _painted(String exposureId) {
    if (!mounted || widget.ad.exposure?.id != exposureId || _mediaPainted) {
      return;
    }
    _mediaPainted = true;
    _syncTimers();
  }

  void _cancelTimers() {
    _impressionTimer?.cancel();
    _viewabilityTimer?.cancel();
    _impressionTimer = null;
    _viewabilityTimer = null;
    _qualifying = null;
  }

  bool get _eligible =>
      mounted && widget.active && _scopeActive && _visible && _foreground;

  void _syncTimers() {
    if (widget.ad.exposure != null) {
      if (!_foregroundVisible) _video?.interrupt();
      _trackExposure();
      return;
    }
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

  void _trackExposure() {
    final onScreen = mounted &&
        widget.active &&
        _scopeActive &&
        _routeActive &&
        _foreground &&
        _available &&
        _mediaPainted;
    if (onScreen && _visibleFraction > 0 && !_impressionFired) {
      _impressionFired = true;
      AdManager.instance.recordImpression(widget.ad,
          placementZone: widget.placementZone, contextKey: _exposure);
    }
    if (!onScreen || _visibleFraction < 0.5) {
      _cancelTimers();
      return;
    }
    if (_viewabilityFired || _viewabilityTimer != null || widget.ad.isVideo) {
      return;
    }
    _qualifying = Stopwatch()..start();
    _viewabilityTimer = Timer(const Duration(seconds: 1), () {
      final elapsed = _qualifying?.elapsedMilliseconds ?? 0;
      _viewabilityFired = true;
      AdManager.instance.recordViewability(widget.ad,
          placementZone: widget.placementZone,
          visibleFraction: _visibleFraction,
          visibleDurationMs: elapsed < 1000 ? 1000 : elapsed);
    });
  }

  @override
  void dispose() {
    if (widget.ad.exposure != null) {
      widget.playback?.removeListener(_sampleVideo);
      _finishVideo(widget);
    }
    _cancelTimers();
    _expiryTimer?.cancel();
    if (widget.ad.exposure != null) _listenForOfferChanges(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      !_available && widget.ad.exposure != null
          ? const SizedBox.shrink()
          : VisibilityDetector(
              key: ValueKey(
                  'ad_${widget.ad.id}_${widget.placementZone}_${_exposure}_$_instanceExposure'),
              onVisibilityChanged: (info) {
                _visibleFraction = info.visibleFraction;
                _visible = info.visibleFraction >= widget.minVisibilityFraction;
                _syncTimers();
              },
              child: widget.ad.exposure == null
                  ? widget.child
                  : _AdMedia(painted: _painted, child: widget.child),
            );
}

class _AdMedia extends InheritedWidget {
  const _AdMedia({required this.painted, required super.child});
  final ValueChanged<String> painted;

  @override
  bool updateShouldNotify(_AdMedia oldWidget) => false;
}

class _PaintedCreative extends SingleChildRenderObjectWidget {
  const _PaintedCreative({
    required super.key,
    required this.onPaint,
    required super.child,
  });

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _CreativePaintObserver(onPaint);
}

class _CreativePaintObserver extends RenderProxyBox {
  _CreativePaintObserver(this.onPaint);
  final VoidCallback onPaint;
  bool _reported = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_reported || child == null || size.isEmpty) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => onPaint());
  }
}
