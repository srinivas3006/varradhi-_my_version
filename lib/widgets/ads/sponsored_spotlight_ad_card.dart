import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_viewability_detector.dart';
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

  @override
  State<SponsoredSpotlightAdCard> createState() =>
      _SponsoredSpotlightAdCardState();
}

class _SponsoredSpotlightAdCardState extends State<SponsoredSpotlightAdCard>
    with WidgetsBindingObserver {
  late int _secondsRemaining;
  Timer? _timer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secondsRemaining = (widget.ad.isInterstitial || widget.ad.isFullScreen)
        ? widget.durationSeconds
        : 0;
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (!widget.active ||
        _secondsRemaining <= 0 ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) return;
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
    if (oldWidget.active != widget.active) _startCountdown();
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
      debugPrint('[Ad] unparseable destination: ${widget.ad.destinationUrl}');
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
        debugPrint('[Ad] launch refused for $uri, retrying in-app');
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      debugPrint('[Ad] could not open $uri: $e');
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
              child: Center(
                // 9:16 box for the creative. The card itself stays full-bleed
                // with the blurred backdrop behind, but the ad is drawn into
                // a fixed portrait frame so every creative lands the same
                // shape regardless of the device it is on.
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: widget.ad.videoUrl.isNotEmpty
                    ? AdActivityScope(
                        active: widget.active,
                        child: VideoAdCard(
                            ad: widget.ad,
                            placementZone: widget.placementZone,
                            exposureKey: widget.exposureKey ?? widget.ad.id))
                    : CachedNetworkImage(
                        imageUrl: widget.ad.imageUrl,
                        // Contain, not cover. A full-screen creative is a
                        // poster: its call to action — a phone number, a
                        // WhatsApp button — sits near the edge, and cover
                        // crops whatever does not match the device ratio, so
                        // the one part of the ad that has to survive is the
                        // first thing lost. The blurred backdrop behind fills
                        // the letterbox so it still reads as full-bleed.
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white70),
                        ),
                        errorWidget: (context, url, error) => Column(
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

            // Bottom-Right: Floating Circular White Share Button
          ],
        ),
      ),
    );
  }
}
