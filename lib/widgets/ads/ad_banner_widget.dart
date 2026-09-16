import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import '../../theme/app_theme.dart';
import 'ad_badge.dart';
import 'ad_viewability_detector.dart';

/// Banner Ad Widget (Aspect ratio: 16:5, height ~90-120dp)
/// Renders a banner ad in feed or banner sections with fixed aspect ratio,
/// BoxFit.cover, Sponsored pill, and error fallback.
class AdBannerWidget extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;

  const AdBannerWidget({
    super.key,
    required this.ad,
    this.placementZone = 'banner',
    this.exposureKey,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  bool _hasError = false;

  Future<void> _handleTap() async {
    AdManager.instance.recordClick(widget.ad, placementZone: widget.placementZone);
    if (widget.ad.destinationUrl.isNotEmpty) {
      final uri = Uri.tryParse(widget.ad.destinationUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.placementZone,
      exposureKey: widget.exposureKey,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 16 / 5, // Fixed 16:5 aspect ratio per spec (height ~90-120dp)
          child: InkWell(
            onTap: _handleTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.ad.imageUrl,
                  fit: BoxFit.cover, // Keep image BoxFit.cover inside fixed aspect ratio
                  placeholder: (context, url) => Container(
                    color: isDark ? Colors.white10 : AppColors.chipBg,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    // Hide that ad on error
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _hasError = true);
                    });
                    return const SizedBox.shrink();
                  },
                ),

                AdBadge.positioned(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
