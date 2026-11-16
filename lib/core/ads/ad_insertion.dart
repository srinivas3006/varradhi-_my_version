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

/// How often ads may appear in one list, the way large feed apps pace them:
/// a minimum number of stories between ads, none at the very top, a cap per
/// screen, each creative shown only a few times, and never the same ad twice
/// in a row. Without it a pool of one or two ads filled a long Home list
/// with the same banner every few stories.
class AdFrequencyPolicy {
  const AdFrequencyPolicy({
    this.minGap = 0,
    this.firstAfter = 0,
    this.maxAdsPerList,
    this.maxRepeatsPerAd,
  });

  /// At least this many stories between two ads (the backend's
  /// display_frequency is used when it asks for more).
  final int minGap;

  /// No ad before this many stories.
  final int firstAfter;

  /// At most this many ads in the whole list (null: no cap).
  final int? maxAdsPerList;

  /// Each ad at most this many times in the list (null: no cap).
  final int? maxRepeatsPerAd;

  /// No pacing beyond the backend's display_frequency (the old behaviour).
  static const none = AdFrequencyPolicy();

  /// Home: paced exactly as each ad was set up in the admin — one ad after
  /// every `display_frequency` stories (5 when unset), all the way down the
  /// list, every ad taking its turn and never the same one twice in a row
  /// when there is another. The backend owns daily caps. (It used to show
  /// each ad once, at most 4, at least 6 stories apart.)
  static const home = AdFrequencyPolicy();

  /// Spotlight: paced exactly as the ad was set up in the admin — one ad
  /// after every `display_frequency` stories (5 when unset), all through
  /// the feed however far the reader goes, rotating through every ad and
  /// never the same one twice in a row when there is another. The backend
  /// owns daily caps. (It used to allow each ad only twice and at least 6
  /// stories apart, so ads stopped appearing after the first few.)
  static const spotlight = AdFrequencyPolicy();

  /// Category lists (zone `category`): at least 6 stories apart, none in
  /// the first 3, at most 4 in all.
  static const category = AdFrequencyPolicy(
    minGap: 6,
    firstAfter: 3,
    maxAdsPerList: 4,
  );

  /// Citizen News (zone `ugc_feed`): at least 5 posts apart, at most 4.
  static const ugcFeed = AdFrequencyPolicy(minGap: 5, maxAdsPerList: 4);

  /// Videos and Reels (zone `video_feed`): at least 8 videos apart, at
  /// most 4.
  static const videoFeed = AdFrequencyPolicy(minGap: 8, maxAdsPerList: 4);
}

/// The ad to show after each content index of [contentItems] — the same
/// pacing as [insertAdsIntoFeed], for lists that keep their own indexes
/// (an ad is drawn under the item it follows).
Map<int, AdBanner> adSlotsAfter<T>({
  required List<T> contentItems,
  required List<AdBanner> eligibleAds,
  required String placementZone,
  required AdFrequencyPolicy policy,
}) {
  final slots = <int, AdBanner>{};
  var contentIndex = -1;
  for (final item in insertAdsIntoFeed<T>(
    contentItems: contentItems,
    eligibleAds: eligibleAds,
    placementZone: placementZone,
    policy: policy,
  )) {
    if (item.isAd) {
      if (contentIndex >= 0) slots[contentIndex] = item.ad!;
    } else {
      contentIndex++;
    }
  }
  return slots;
}

/// [adZone] (as the backend sent it) is the canonical [zone]; an unknown
/// zone matches nothing.
bool _sameZone(String adZone, String zone) {
  try {
    return AdPlacement.canonical(adZone) == zone;
  } on ArgumentError {
    return false;
  }
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
  AdFrequencyPolicy policy = AdFrequencyPolicy.none,
}) {
  final zone = AdPlacement.canonical(placementZone);
  final ids = <String>{};
  final ads = eligibleAds
      .where((ad) =>
          ad.id.isNotEmpty &&
          ids.add(ad.id) &&
          _sameZone(ad.placementZone, zone) &&
          AdTypeResolver.isSupported(ad) &&
          AdPlacement.supports(zone, ad) &&
          !ad.isBottomSticky &&
          (allowTimed || (!ad.isInterstitial && !ad.isFullScreen)))
      .toList();
  final result = <FeedPresentationItem<T>>[];
  final shown = <String, int>{};
  var count = 0;
  var adIndex = 0;
  var placed = 0;
  String? lastAdId;

  /// The next ad in rotation that is still allowed here, or null.
  AdBanner? nextAd() {
    for (var tries = 0; tries < ads.length; tries++) {
      final ad = ads[(adIndex + tries) % ads.length];
      final repeats = shown[ad.id] ?? 0;
      final capped =
          policy.maxRepeatsPerAd != null && repeats >= policy.maxRepeatsPerAd!;
      // Never the same creative twice in a row when there is another.
      final sameAsLast = ad.id == lastAdId && ads.length > 1;
      if (!capped && !sameAsLast) {
        adIndex = (adIndex + tries) % ads.length;
        return ad;
      }
    }
    return null;
  }

  for (var index = 0; index < contentItems.length; index++) {
    final content = contentItems[index];
    final key = contentKey?.call(content) ?? '$index';
    result.add(
        FeedPresentationItem<T>.content(content, stableKey: 'content_$key'));
    count++;
    if (ads.isEmpty) continue;
    if (index + 1 < policy.firstAfter) continue;
    if (policy.maxAdsPerList != null && placed >= policy.maxAdsPerList!) {
      continue;
    }
    final ad = nextAd();
    if (ad == null) continue; // every ad has used up its repeats
    final configured = overrideFrequency ?? ad.displayFrequency;
    var interval = configured > 0 ? configured : 5;
    if (interval < policy.minGap) interval = policy.minGap;
    if (count < interval) continue;
    result.add(
        FeedPresentationItem<T>.ad(ad, stableKey: 'ad_${ad.id}_after_$key'));
    shown[ad.id] = (shown[ad.id] ?? 0) + 1;
    lastAdId = ad.id;
    placed++;
    adIndex++;
    count = 0;
  }
  return result;
}
