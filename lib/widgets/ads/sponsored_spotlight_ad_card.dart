import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import '../../utils/share_service.dart';
import 'ad_viewability_detector.dart';

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
  final String placementZone;

  const SponsoredSpotlightAdCard({
    super.key,
    required this.ad,
    required this.onClose,
    this.durationSeconds = 4,
    this.placementZone = 'spotlight',
  });

  @override
  State<SponsoredSpotlightAdCard> createState() =>
      _SponsoredSpotlightAdCardState();
}

class _SponsoredSpotlightAdCardState extends State<SponsoredSpotlightAdCard> {
  late int _secondsRemaining;
  Timer? _timer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        t.cancel();
        setState(() => _secondsRemaining = 0);
        AdManager.instance
            .recordSkip(widget.ad, placementZone: widget.placementZone);
        _handleClose(isManualDismiss: false);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
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
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleShare() {
    HapticFeedback.lightImpact();
    final shareText = widget.ad.destinationUrl.isNotEmpty
        ? '${widget.ad.title}\n${widget.ad.destinationUrl}'
        : widget.ad.title;
    ShareService.shareText(shareText);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.placementZone,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color:
            Colors.black, // Opaque black prevents background news text overlap
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ad Creative / Media Frame
            GestureDetector(
              onTap: _handleAdTap,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.ad.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
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

            // Top-Left: Frosted "Sponsored" Badge Pill
            Positioned(
              top: topPadding + 14,
              left: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_rounded,
                            color: Colors.amber, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'SPONSORED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
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
            Positioned(
              bottom: bottomPadding + 32,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleShare,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: Colors.black87,
                      size: 22,
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
