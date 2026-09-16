import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_viewability_detector.dart';

/// Sticky bottom banner ad (Height: 56-80dp, default 64dp).
/// Stays fixed above the bottom navigation bar with dismiss control.
class BottomStickyAdBanner extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final VoidCallback? onDismiss;

  const BottomStickyAdBanner({
    super.key,
    required this.ad,
    this.placementZone = 'bottom_sticky',
    this.onDismiss,
  });

  @override
  State<BottomStickyAdBanner> createState() => _BottomStickyAdBannerState();
}

class _BottomStickyAdBannerState extends State<BottomStickyAdBanner> {
  bool _isDismissed = false;
  bool _hasError = false;

  /// An ad with nowhere to go must not ripple under the finger: a banner that
  /// responds to a tap and then does nothing reads as a broken app. It also
  /// must not report a click it cannot deliver.
  bool get _isClickable => widget.ad.destinationUrl.trim().isNotEmpty;

  Future<void> _handleTap() async {
    AdManager.instance
        .recordClick(widget.ad, placementZone: widget.placementZone);
    final uri = Uri.tryParse(widget.ad.destinationUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleDismiss() {
    AdManager.instance
        .recordDismiss(widget.ad, placementZone: widget.placementZone);
    setState(() => _isDismissed = true);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed || _hasError) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.placementZone,
      child: Container(
        height: 64, // Height: 56-80dp per spec
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Background Image
            if (widget.ad.imageUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: widget.ad.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _hasError = true);
                    });
                    return const SizedBox.shrink();
                  },
                ),
              ),

            // Tap handler over the whole banner
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: _isClickable ? _handleTap : null),
              ),
            ),

            // SPONSORED Pill
            Positioned(
              top: 8,
              left: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C3E35), // Dark brown pill
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SPONSORED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            // Close / Dismiss button in top-right
            // The dismiss control gets a real 48dp touch target. The 22dp
            // circle it had was below the minimum and easy to miss, which on
            // an ad the reader is trying to get rid of means they instead hit
            // the banner underneath and get sent to the advertiser.
            Positioned(
              top: 0,
              right: 0,
              // A plain IconButton keeps the default 48dp tap target while the
              // visible chip stays small, so the control is easy to hit
              // without eating the 64dp banner.
              child: IconButton(
                onPressed: _handleDismiss,
                padding: EdgeInsets.zero,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
