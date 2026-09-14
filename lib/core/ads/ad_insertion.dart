import '../../models/ad_banner.dart';
import 'ad_type_resolver.dart';
import 'ad_placement.dart';

/// Item wrapper for feed presentation layer that preserves original content.
class FeedPresentationItem<T> {
  final T? content;
  final AdBanner? ad;
  final bool isAd;
  final String stableKey;

  const FeedPresentationItem.content(this.content, {required this.stableKey})
      : ad = null,
        isAd = false;

  const FeedPresentationItem.ad(this.ad, {required this.stableKey})
      : content = null,
        isAd = true;
}

/// Deterministic rotation: the next ad's interval is measured in parent
/// content cards since the previous insertion. Media and ads never increment it.
List<FeedPresentationItem<T>> insertAdsIntoFeed<T>({
  required List<T> contentItems,
  required List<AdBanner> eligibleAds,
  String placementZone = 'feed',
  bool allowTimed = false,
  int? overrideFrequency,
  String Function(T)? contentKey,
}) {
  final zone = AdPlacement.canonical(placementZone);
  final ids = <String>{};
  final ads = eligibleAds
      .where((ad) =>
          ad.id.isNotEmpty &&
          ids.add(ad.id) &&
          ad.placementZone == zone &&
          AdTypeResolver.isSupported(ad) &&
          !ad.isBottomSticky &&
          (allowTimed || (!ad.isInterstitial && !ad.isFullScreen)))
      .toList();
  final result = <FeedPresentationItem<T>>[];
  var count = 0;
  var adIndex = 0;
  for (var index = 0; index < contentItems.length; index++) {
    final content = contentItems[index];
    final key = contentKey?.call(content) ?? '$index';
    result.add(
        FeedPresentationItem<T>.content(content, stableKey: 'content_$key'));
    count++;
    if (ads.isEmpty) continue;
    final ad = ads[adIndex % ads.length];
    final configured = overrideFrequency ?? ad.displayFrequency;
    final interval = configured > 0 ? configured : 5;
    if (count < interval) continue;
    result.add(
        FeedPresentationItem<T>.ad(ad, stableKey: 'ad_${ad.id}_after_$key'));
    adIndex++;
    count = 0;
  }
  return result;
}
