import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_viewability_detector.dart';
import 'full_screen_ad_image.dart';
import 'video_ad_card.dart';

/// Full-screen sponsored ad card for Spotlight mode.
///
/// Faithfully styled after the production design:
/// - Top-Left: Frosted pill with campaign speaker icon and 'Sponsored' label.
/// - Top-Right: Frosted pill with live countdown timer and close '✕' button.
/// - Full-bleed media banner with opaque backdrop (zero content bleed).
/// - Bottom-Right: Floating circular share button with native sharing.
class SponsoredSpotlightAdCard extends StatefulWidget {
  final AdBanner ad;
  final VoidCallback onClose;
  final int durationSeconds;
  final bool active;
  final String? exposureKey;
  final String placementZone;

  const SponsoredSpotlightAdCard({
    super.key,
    required this.ad,
    required this.onClose,
    this.durationSeconds = 0,
    this.active = true,
    this.exposureKey,
    this.placementZone = 'feed',
  });

  /// Whole seconds of video left, rounded up (shows 1 until the very end).
  static int secondsLeft(Duration position, Duration duration) {
    final ms = (duration - position).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  State<SponsoredSpotlightAdCard> createState() =>
      _SponsoredSpotlightAdCardState();
}

class _SponsoredSpotlightAdCardState extends State<SponsoredSpotlightAdCard>
    with WidgetsBindingObserver {
  late int _secondsRemaining;
  Timer? _timer;
  bool _isClosing = false;

  /// A video ad's countdown follows the video (time left to play), not a
  /// clock: it holds while the video buffers or pauses and ends with it.
  /// Falls back to the clock if the video cannot be played.
  bool get _followsVideo =>
      widget.ad.videoUrl.trim().isNotEmpty && !_videoFailed;
  bool _videoFailed = false;

  /// The video failed with no poster before this page was reached: it is
  /// skipped the moment it becomes the current page.
  bool _skipWhenReached = false;

  void _onVideoProgress(Duration position, Duration duration) {
    final left = SponsoredSpotlightAdCard.secondsLeft(position, duration);
    if (mounted && left > 0 && left != _secondsRemaining) {
      setState(() => _secondsRemaining = left);
    }
  }

  /// Watched to the end: the same as the countdown running out.
  void _onVideoCompleted() {
    if (!mounted || !widget.active) return;
    setState(() => _secondsRemaining = 0);
    AdManager.instance
        .recordHide(widget.ad, placementZone: widget.placementZone);
    _handleClose(isManualDismiss: false);
  }

  void _onVideoFailed() {
    if (!mounted) return;
    // Nothing to show at all (no poster to fall back on): never leave the
    // reader on a black page with a spinner. The page is removed, as when
    // its time is up; nothing was seen, so nothing is recorded.
    if (widget.ad.imageUrl.trim().isEmpty) {
      debugPrint('[Ad] video ${widget.ad.id} could not play; skipping it');
      if (widget.active) {
        _handleClose(isManualDismiss: false);
      } else {
        _skipWhenReached = true;
      }
      return;
    }
    setState(() {
      _videoFailed = true;
      _secondsRemaining = widget.durationSeconds;
    });
    _startCountdown();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Timed ads count down on Skip: full-screen, interstitial and video
    // (display_duration_seconds; 0 means no timer).
    _secondsRemaining = (widget.ad.isInterstitial ||
            widget.ad.isFullScreen ||
            widget.ad.videoUrl.trim().isNotEmpty)
        ? widget.durationSeconds
        : 0;
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (_followsVideo ||
        !widget.active ||
        _secondsRemaining <= 0 ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        t.cancel();
        setState(() => _secondsRemaining = 0);
        AdManager.instance
            .recordHide(widget.ad, placementZone: widget.placementZone);
        _handleClose(isManualDismiss: false);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SponsoredSpotlightAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active && _skipWhenReached) {
        // Failed while it was still the page ahead.
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => mounted ? _handleClose(isManualDismiss: false) : null);
        return;
      }
      _startCountdown();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCountdown();
    } else {
      _timer?.cancel();
    }
  }

  void _handleClose({bool isManualDismiss = true}) {
    if (_isClosing) return;
    _isClosing = true;
    _timer?.cancel();
    HapticFeedback.lightImpact();

    if (isManualDismiss) {
      AdManager.instance
          .recordDismiss(widget.ad, placementZone: widget.placementZone);
    }

    widget.onClose();
  }

  Future<void> _handleAdTap() async {
    if (widget.ad.destinationUrl.isEmpty) return;
    HapticFeedback.selectionClick();
    AdManager.instance
        .recordClick(widget.ad, placementZone: widget.placementZone);

    final uri = Uri.tryParse(widget.ad.destinationUrl);
    if (uri == null) {
      if (kDebugMode) {
        debugPrint('[Ad] unparseable destination');
      }
      return;
    }

    // canLaunchUrl is advisory: it answers false whenever package visibility
    // hides the handler, which is how a click with a perfectly good
    // destination ended up doing nothing at all. Try the launch regardless
    // and let it report its own failure.
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (kDebugMode) {
          debugPrint('[Ad] launch refused, retrying in-app');
        }
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Ad] could not open destination: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.placementZone,
      active: widget.active,
      exposureKey: widget.exposureKey ?? widget.ad.id,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color:
            Colors.black, // Opaque black prevents background news text overlap
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred, darkened copy of the creative, so the bars left by
            // BoxFit.contain read as deliberate rather than as the ad having
            // failed to load. Cropping this is fine: it is decoration.
            if (widget.ad.imageUrl.isNotEmpty)
              IgnorePointer(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                  child: CachedNetworkImage(
                    imageUrl: widget.ad.imageUrl,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.55),
                    colorBlendMode: BlendMode.darken,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Ad Creative / Media Frame
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleAdTap,
              // The creative gets the whole page between the disclosure/skip
              // row and the home indicator. A fixed 9:16 frame used to sit
              // inside that, which shrank any creative on screens taller or
              // wider than 9:16 and left a band of backdrop around it.
              // Image and video alike use the whole page; the Ad / Skip row
              // floats over them. Video was the feed card in a 9:16 frame —
              // a small player above a white box — not a full-screen ad.
              child: SizedBox.expand(
                child: widget.ad.videoUrl.isNotEmpty
                    ? AdActivityScope(
                        active: widget.active,
                        child: VideoAdCard(
                          ad: widget.ad,
                          placementZone: widget.placementZone,
                          exposureKey: widget.exposureKey ?? widget.ad.id,
                          fullScreen: true,
                          onProgress: _onVideoProgress,
                          onCompleted: _onVideoCompleted,
                          onFailed: _onVideoFailed,
                        ),
                      )
                    // Fills the phone screen when the creative is (close to)
                    // the phone's ratio; a very different one is shown whole
                    // over a blurred copy, so its call to action near the
                    // edge is never cropped away (FullScreenAdImage).
                    : FullScreenAdImage(
                        imageUrl: widget.ad.imageUrl,
                        errorBuilder: (context) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.campaign_rounded,
                                size: 64, color: Colors.white54),
                            const SizedBox(height: 12),
                            Text(
                              widget.ad.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // Ad disclosure. Deliberately smaller and quieter than the old
            // "📢 SPONSORED" pill — the industry convention, and what the
            // reference app uses — but still opaque-backed, white on black
            // and always on top of the creative, so it stays legible on any
            // artwork. It is a disclosure, not decoration: it must never be
            // possible for a creative to hide it.
            //
            // Kept top-LEFT rather than top-right as in the reference, since
            // the skip/close control already owns the top-right corner and
            // overlapping the two would obscure both.
            Positioned(
              top: topPadding + 14,
              left: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ad',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.info_outline,
                            color: Colors.white70, size: 11),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top-Right: Frosted Countdown & Dismiss Pill
            Positioned(
              top: topPadding + 14,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            _secondsRemaining > 0
                                ? 'Skip $_secondsRemaining'
                                : 'Skip',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: _handleClose,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
