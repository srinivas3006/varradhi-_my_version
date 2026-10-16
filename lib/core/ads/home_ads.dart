import 'package:flutter/foundation.dart';

import '../../models/ad_banner.dart';

/// The single `GET /api/v1/ads/` response of a Home load.
///
/// NewsFeedTab makes the request once per load and publishes the result
/// here; every Home placement reads from it — inline feed slots and the
/// breaking strip (NewsFeedTab) and the bottom sticky banner (HomeScreen) —
/// so Home never asks for ads twice.
class HomeAds {
  HomeAds._();

  static final ValueNotifier<List<AdBanner>> current =
      ValueNotifier<List<AdBanner>>(const []);

  /// Ticker strip above the feed.
  static List<AdBanner> breakingStrip(List<AdBanner> ads) =>
      ads.where((ad) => ad.isBreakingStrip).toList();

  /// The bottom banner over the nav bar.
  static List<AdBanner> bottomSticky(List<AdBanner> ads) =>
      ads.where((ad) => ad.isBottomSticky).toList();

  /// 3D ads: shown as the small floating ad that comes and goes
  /// (PacedAdsOverlay), not as a card in the feed.
  static List<AdBanner> threeD(List<AdBanner> ads) =>
      ads.where((ad) => ad.isThreeD && ad.imageUrl.isNotEmpty).toList();

  /// The 3D corner ad's pool: 3D ads (picture or video) and video ads,
  /// which play inside the 3D shapes. Video ads keep their feed slots too.
  static List<AdBanner> corner3d(List<AdBanner> ads) => ads
      .where((ad) =>
          (ad.isThreeD &&
              (ad.imageUrl.isNotEmpty || ad.videoUrl.trim().isNotEmpty)) ||
          (ad.isVideo && ad.videoUrl.trim().isNotEmpty))
      .toList();

  /// Slots between Latest stories: everything not reserved above.
  static List<AdBanner> inline(List<AdBanner> ads) => ads
      .where((ad) => !ad.isBreakingStrip && !ad.isBottomSticky && !ad.isThreeD)
      .toList();
}
