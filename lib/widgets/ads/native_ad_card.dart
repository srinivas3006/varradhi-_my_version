import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import '../../theme/app_theme.dart';
import 'ad_viewability_detector.dart';
import 'video_ad_card.dart';

import 'box_ad_widget.dart';
import 'three_d_ad_widget.dart';
import 'poster_ad_widget.dart';
import 'ad_banner_widget.dart';
import 'breaking_strip_ad_widget.dart';
import 'local_listing_ad_widget.dart';
import 'bottom_sticky_ad_banner.dart';

/// Backend-driven native in-feed ad card styled identically to regular news cards.
/// Displays an ad with a "Sponsored" label, consistent typography, action buttons,
/// and automatic dwell-based viewability and click tracking via [AdManager].
class NativeAdCard extends StatefulWidget {
  final AdBanner? ad;
  final String placementZone;
  final String? exposureKey;

  const NativeAdCard({
    super.key,
    this.ad,
    this.placementZone = 'feed',
    this.exposureKey,
  });

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  Future<void> _handleTap() async {
    if (widget.ad == null) return;
    HapticFeedback.selectionClick();
    AdManager.instance.recordClick(widget.ad!, placementZone: widget.placementZone);

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

    // Delegate to specialized fixed aspect ratio widgets per ad_type
    if (ad.isVideo) {
      return VideoAdCard(
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      );
    }
    if (ad.isBox) {
      return BoxAdWidget(
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      );
    }
    if (ad.isThreeD) {
      return ThreeDAdWidget(
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      );
    }
    if (ad.isPoster) {
      return PosterAdWidget(
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      );
    }
    if (ad.isBanner) {
      return AdBannerWidget(
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      );
    }
    if (ad.isBreakingStrip) {
      return BreakingStripAdWidget(
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      );
    }
    if (ad.isLocalListing) {
      return LocalListingAdWidget(
        ad: ad,
        placementZone: widget.placementZone,
        exposureKey: widget.exposureKey,
      );
    }
    if (ad.isBottomSticky) {
      return BottomStickyAdBanner(
        ad: ad,
        placementZone: widget.placementZone,
      );
    }

    return AdViewabilityDetector(
      ad: ad,
      placementZone: widget.placementZone,
      exposureKey: widget.exposureKey,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: _handleTap,
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Media Header Frame: Fixed 16:9 Aspect Ratio matching article cards
              AspectRatio(
                aspectRatio: 16 / 9,
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
                          child: Icon(Icons.campaign_rounded, size: 48, color: AppColors.textMuted),
                        ),
                      ),
                    ),

                    // Subtle Bottom Gradient on Image
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top-Left "Sponsored" Frosted Badge Pill
                    Positioned(
                      top: 12,
                      left: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.campaign_rounded, color: Colors.amber, size: 14),
                                SizedBox(width: 5),
                                Text(
                                  'SPONSORED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Top-Right Share Button
                  ],
                ),
              ),

              // Ad Content & Call To Action
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headline
                    Text(
                      ad.title.isNotEmpty ? ad.title : 'Sponsored Promotion',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textDark,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Sponsor Domain / Attribution
                    Text(
                      ad.destinationUrl.isNotEmpty
                          ? 'Sponsored · ${Uri.tryParse(ad.destinationUrl)?.host ?? ad.destinationUrl}'
                          : 'Sponsored Partner',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CTA Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _handleTap,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Learn More',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 15),
                              ],
                            ),
                          ),
                        ),
                      ],
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
