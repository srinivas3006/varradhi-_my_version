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

  Future<void> _handleTap() async {
    AdManager.instance.recordClick(widget.ad, placementZone: widget.placementZone);
    if (widget.ad.destinationUrl.isNotEmpty) {
      final uri = Uri.tryParse(widget.ad.destinationUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _handleDismiss() {
    AdManager.instance.recordDismiss(widget.ad, placementZone: widget.placementZone);
    setState(() => _isDismissed = true);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

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
            InkWell(
              onTap: _handleTap,
              child: Row(
                children: [
                  // Banner Image thumbnail / cover
                  if (widget.ad.imageUrl.isNotEmpty)
                    SizedBox(
                      width: 100,
                      height: 64,
                      child: CachedNetworkImage(
                        imageUrl: widget.ad.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),

                  const SizedBox(width: 12),

                  // Headline and Sponsored Label
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'AD',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Sponsored',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.ad.title.isNotEmpty ? widget.ad.title : 'Featured Promotion',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Destination CTA icon
                  const Padding(
                    padding: EdgeInsets.only(right: 36.0),
                    child: Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Close / Dismiss button in top-right
            Positioned(
              top: 4,
              right: 6,
              child: InkWell(
                onTap: _handleDismiss,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
