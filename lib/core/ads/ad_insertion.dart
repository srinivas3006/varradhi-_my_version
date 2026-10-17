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

  /// Home: a scrolled list the reader reads top to bottom — each ad once,
  /// at least 6 stories apart, none in the first 3, at most 4 in all.
  static const home = AdFrequencyPolicy(
    minGap: 6,
    firstAfter: 3,
    maxAdsPerList: 4,
    maxRepeatsPerAd: 1,
  );

  /// Spotlight: one full-screen card at a time, so an ad page is a bigger
  /// interruption — at least 6 stories apart, each ad at most twice.
  static const spotlight = AdFrequencyPolicy(
    minGap: 6,
    firstAfter: 4,
    maxRepeatsPerAd: 2,
  );
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
          ad.placementZone == zone &&
          AdTypeResolver.isSupported(ad) &&
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
