import 'package:flutter/foundation.dart';

import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import 'ad_placement.dart';

/// Ads for one of the per-screen zones (home_top, category, ugc_feed,
/// video_feed, article_end): `GET /api/v1/ads/?placement_zone=<zone>`,
/// keeping only that zone's ads in a format the zone renders.
///
/// An empty list means no ad for the placement; nothing is borrowed from
/// another zone. Never throws.
class ZoneAds {
  ZoneAds._();

  /// The request; replaced in tests.
  @visibleForTesting
  static Future<List<AdBanner>> Function(String zone) loader =
      (zone) => AdManager.instance.getAdsForZone(zone);

  static Future<List<AdBanner>> load(String zone) async {
    final canonical = AdPlacement.canonical(zone);
    try {
      final ads = await loader(canonical);
      final ids = <String>{};
      return ads
          .where((ad) =>
              ad.id.isNotEmpty &&
              ids.add(ad.id) &&
              ad.placementZone.trim().toLowerCase() == canonical &&
              AdPlacement.supports(canonical, ad))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
