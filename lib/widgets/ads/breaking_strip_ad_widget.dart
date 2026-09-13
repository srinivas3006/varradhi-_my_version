import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_viewability_detector.dart';

/// Top ticker / breaking strip ad widget (Height: 36-48dp)
/// Renders a sleek, compact headline strip with optional thumbnail and destination link.
class BreakingStripAdWidget extends StatelessWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;

  const BreakingStripAdWidget({
    super.key,
    required this.ad,
    this.placementZone = 'strip',
    this.exposureKey,
  });

  Future<void> _handleTap() async {
    AdManager.instance.recordClick(ad, placementZone: placementZone);
    if (ad.destinationUrl.isNotEmpty) {
      final uri = Uri.tryParse(ad.destinationUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdViewabilityDetector(
      ad: ad,
      placementZone: placementZone,
      exposureKey: exposureKey,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          child: Container(
            height: 42, // Height: 36-48dp per spec
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.amberAccent.withValues(alpha: 0.25)
                    : Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                // Ad indicator badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Optional mini thumbnail if image_url exists
                if (ad.imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CachedNetworkImage(
                        imageUrl: ad.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Headline text
                Expanded(
                  child: Text(
                    ad.title.isNotEmpty ? ad.title : 'Featured Promotion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF9A3412),
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: Color(0xFFEA580C),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
