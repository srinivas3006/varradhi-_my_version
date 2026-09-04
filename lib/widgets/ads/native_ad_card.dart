import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/ad_banner.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Backend-driven native in-feed ad card. Displays ad title, image, and CTA
/// fetched dynamically from ApiService with automatic impression & click analytics.
class NativeAdCard extends StatefulWidget {
  final AdBanner? ad;

  const NativeAdCard({super.key, this.ad});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  bool _impressionTracked = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (widget.ad != null && !_impressionTracked && info.visibleFraction > 0.5) {
      _impressionTracked = true;
      ApiService.instance.trackAdEvent(widget.ad!.id, 'impression');
    }
  }

  Future<void> _handleTap() async {
    if (widget.ad == null) return;
    ApiService.instance.trackAdEvent(widget.ad!.id, 'click');
    if (widget.ad!.destinationUrl.isNotEmpty) {
      final uri = Uri.tryParse(widget.ad!.destinationUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (ad == null) {
      return const SizedBox.shrink();
    }

    return VisibilityDetector(
      key: Key('native_ad_${ad.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE7E7EA),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ad Banner Image / Media Frame
              SizedBox(
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: ad.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark ? Colors.white10 : AppColors.chipBg,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? Colors.white10 : AppColors.chipBg,
                        child: const Center(
                          child: Icon(Icons.storefront_rounded, size: 48, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Ad',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Title and CTA Action Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title.isNotEmpty ? ad.title : 'Sponsored Promotion',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textDark,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ad.destinationUrl.isNotEmpty ? 'Sponsored · ${ad.destinationUrl}' : 'Sponsored Content',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _handleTap,
                        child: const Text(
                          'Learn More',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
