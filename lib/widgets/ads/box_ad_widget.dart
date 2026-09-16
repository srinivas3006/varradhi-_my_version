import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import '../../theme/app_theme.dart';
import 'ad_badge.dart';
import 'ad_viewability_detector.dart';

/// Square / Box ad widget (Aspect ratio: 1:1)
/// Used between cards or in grid layouts with BoxFit.cover.
class BoxAdWidget extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;

  const BoxAdWidget({
    super.key,
    required this.ad,
    this.placementZone = 'feed',
    this.exposureKey,
  });

  @override
  State<BoxAdWidget> createState() => _BoxAdWidgetState();
}

class _BoxAdWidgetState extends State<BoxAdWidget> {
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 1.0, // Fixed 1:1 square ratio
          child: InkWell(
            onTap: _handleTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
              AdBadge.positioned(),
                CachedNetworkImage(
                  imageUrl: widget.ad.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? Colors.white10 : AppColors.chipBg,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _hasError = true);
                    });
                    return const SizedBox.shrink();
                  },
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
