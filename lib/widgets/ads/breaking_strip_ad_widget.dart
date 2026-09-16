import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_viewability_detector.dart';

/// Top ticker / breaking strip ad widget (Height: 36-48dp)
/// Renders a sleek, compact headline strip with optional thumbnail and destination link.
class BreakingStripAdWidget extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;

  const BreakingStripAdWidget({
    super.key,
    required this.ad,
    this.placementZone = 'strip',
    this.exposureKey,
  });

  @override
  State<BreakingStripAdWidget> createState() => _BreakingStripAdWidgetState();
}

class _BreakingStripAdWidgetState extends State<BreakingStripAdWidget> {
  bool _hasError = false;

  /// An ad with nowhere to go must not ripple under the finger: a strip that
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

  @override
  Widget build(BuildContext context) {
    // A creative that failed to load leaves nothing to advertise, so give the
    // space back to the feed rather than holding a blank bar above it.
    if (_hasError) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.placementZone,
      exposureKey: widget.exposureKey,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isClickable ? _handleTap : null,
          child: Container(
            height: 48, // Compact height for top strip
            width: double.infinity,
            color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF0F0F0),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
