import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_viewability_detector.dart';

class AdBannerWidget extends StatelessWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;

  const AdBannerWidget({
    super.key,
    required this.ad,
    this.placementZone = 'banner',
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
    return AdViewabilityDetector(
      ad: ad,
      placementZone: placementZone,
      exposureKey: exposureKey,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.black.withValues(alpha: 0.04),
          ),
          child: CachedNetworkImage(
            imageUrl: ad.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(
              height: 56,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
