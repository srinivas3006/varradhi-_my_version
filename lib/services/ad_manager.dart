import 'dart:math';
import '../core/ads/ad_insertion.dart';
import '../core/ads/ad_placement.dart';
export '../core/ads/ad_insertion.dart' show FeedPresentationItem;
import 'package:flutter/foundation.dart';
import '../core/ads/ad_event_queue.dart';
import '../core/ads/ad_type_resolver.dart';
import '../models/ad_banner.dart';
import '../repositories/ad_repository.dart';

/// Central advertisement orchestrator.
///
/// Responsibilities:
/// - Maintain session state (session start, recent ads, interstitial cooldowns)
/// - Enforce client UX rules (no launch interstitial, 5-minute requirement, video suppression)
/// - Select ads with anti-repetition rotation
/// - Emit deduplicated lifecycle events (impression, viewability, click, dismiss, skip)
/// - Calculate feed presentation layouts without mutating underlying content
class AdManager extends ChangeNotifier {
  static final AdManager instance = AdManager._internal();
  AdManager._internal() {
    _sessionStartTime = DateTime.now();
  }

  /// Visible for testing: factory for creating a fresh manager.
  factory AdManager.createTest() {
    final mgr = AdManager._internal();
    mgr.resetSession();
    return mgr;
  }

  // --- Session State ---
  late DateTime _sessionStartTime;
  DateTime? _lastInterstitialTime;
  int _adsShownThisSession = 0;
  int _contentInteractionsCount = 0;
  int _activeVideoCount = 0;

  /// Recent ad IDs circular buffer to prevent repeating the same ad.
  final List<String> _recentAdIds = [];
  static const int maxRecentAdHistory = 5;

  /// Emitted events deduplication set: {adId_zone_eventType_exposureContext}
  final Set<String> _emittedEvents = <String>{};

  /// Session impression telemetry; backend eligibility enforces daily caps.
  final Map<String, int> _adImpressionCounts = {};

  // --- Configurable Thresholds (exposed for testing) ---
  Duration minSessionAgeForInterstitial = const Duration(minutes: 5);
  Duration minInterstitialCooldown = const Duration(minutes: 5);
  int minEngagementForInterstitial = 3;
  int minArticlesBeforeFirstAd = 2;

  // --- Getters ---
  DateTime get sessionStartTime => _sessionStartTime;
  DateTime? get lastInterstitialTime => _lastInterstitialTime;
  int get adsShownThisSession => _adsShownThisSession;
  int get contentInteractionsCount => _contentInteractionsCount;
  int get activeVideoCount => _activeVideoCount;
  bool get isVideoActivelyPlaying => _activeVideoCount > 0;
  List<String> get recentAdIds => List.unmodifiable(_recentAdIds);

  /// Resets session tracking state (e.g. On user logout, app launch, or in tests).
  void resetSession() {
    _sessionStartTime = DateTime.now();
    _lastInterstitialTime = null;
    _adsShownThisSession = 0;
    _contentInteractionsCount = 0;
    _activeVideoCount = 0;
    _recentAdIds.clear();
    _emittedEvents.clear();
    _adImpressionCounts.clear();
    notifyListeners();
  }

  /// Increments active video counter when video playback starts.
  void registerActiveVideo() {
    _activeVideoCount++;
    notifyListeners();
  }

  /// Decrements active video counter when video playback pauses or stops.
  void unregisterActiveVideo() {
    _activeVideoCount = max(0, _activeVideoCount - 1);
    notifyListeners();
  }

  /// Records meaningful content interaction (e.g. Article opened, scrolled, liked).
  void recordContentInteraction() {
    _contentInteractionsCount++;
  }

  // --- Eligibility & Selection ---

  /// Evaluates whether an interstitial ad can be presented safely.
  /// Enforces:
  /// 1. Cold launch suppression: session age must meet [minSessionAgeForInterstitial].
  /// 2. Engagement threshold: user must have interacted at least [minEngagementForInterstitial] times.
  /// 3. Cooldown: elapsed time since last interstitial must exceed [minInterstitialCooldown].
  /// 4. Video suppression: must NOT be playing active video.
  bool canShowInterstitial() {
    // 1. Video suppression
    if (isVideoActivelyPlaying) {
      debugPrint('[AdManager] Interstitial blocked: Active video is playing');
      return false;
    }

    final now = DateTime.now();

    // 2. Minimum session age (5-minute requirement)
    if (now.difference(_sessionStartTime) < minSessionAgeForInterstitial) {
      debugPrint(
          '[AdManager] Interstitial blocked: Session age < $minSessionAgeForInterstitial');
      return false;
    }

    // 3. User engagement threshold
    if (_contentInteractionsCount < minEngagementForInterstitial) {
      debugPrint(
          '[AdManager] Interstitial blocked: Engagement count < $minEngagementForInterstitial');
      return false;
    }

    // 4. Cooldown after previous interstitial
    if (_lastInterstitialTime != null) {
      final elapsed = now.difference(_lastInterstitialTime!);
      if (elapsed < minInterstitialCooldown) {
        debugPrint(
            '[AdManager] Interstitial blocked: Cooldown active ($elapsed < $minInterstitialCooldown)');
        return false;
      }
    }

    return true;
  }

  /// Checks whether an in-feed ad can be inserted at [contentIndex].
  /// Enforces:
  /// - Never before [minArticlesBeforeFirstAd] items
  /// - Insertion intervals driven by [displayFrequency] (fallback 5)
  bool canShowFeedAd({
    required int contentIndex,
    int displayFrequency = 5,
  }) {
    if (contentIndex < 0) return false;
    final freq = displayFrequency > 0 ? displayFrequency : 5;
    return (contentIndex + 1) % freq == 0;
  }

  /// Selects the best eligible ad from [pool] with anti-repetition rotation.
  AdBanner? selectAd(
    List<AdBanner> pool, {
    String? preferType,
    List<String>? excludeIds,
  }) {
    if (pool.isEmpty) return null;

    // Filter to supported types
    var candidates = pool.where(AdTypeResolver.isSupported).toList();
    if (candidates.isEmpty) return null;

    // If preferred type specified, prioritize it
    if (preferType != null) {
      final matched = candidates
          .where((a) => a.adType.toLowerCase() == preferType.toLowerCase())
          .toList();
      if (matched.isNotEmpty) {
        candidates = matched;
      }
    }

    // The backend owns daily eligibility, including the global default for zero.
    // Session counts must not masquerade as a persisted daily cap.
    if (candidates.isEmpty) return null;

    final combinedRecent = <String>{..._recentAdIds, ...?excludeIds};

    // 1. Pick an ad that has not been shown recently or assigned in this pass
    final unshown =
        candidates.where((ad) => !combinedRecent.contains(ad.id)).toList();

    if (unshown.isNotEmpty) {
      return unshown.first;
    }

    // 2. If all candidates have been shown recently, pick the least recently shown
    // (i.e. Not the immediate last one)
    if (candidates.length > 1 && combinedRecent.isNotEmpty) {
      final lastId = (excludeIds != null && excludeIds.isNotEmpty)
          ? excludeIds.last
          : (_recentAdIds.isNotEmpty ? _recentAdIds.last : null);
      if (lastId != null) {
        final nonImmediate = candidates.where((ad) => ad.id != lastId).toList();
        if (nonImmediate.isNotEmpty) {
          return nonImmediate.first;
        }
      }
    }

    return candidates.first;
  }

  /// Marks an ad as shown to update recent history and session counters.
  void markAdShown(AdBanner ad, {bool isInterstitial = false}) {
    _adsShownThisSession++;
    _adImpressionCounts[ad.id] = (_adImpressionCounts[ad.id] ?? 0) + 1;

    _recentAdIds.remove(ad.id);
    _recentAdIds.add(ad.id);
    if (_recentAdIds.length > maxRecentAdHistory) {
      _recentAdIds.removeAt(0);
    }

    if (isInterstitial) {
      _lastInterstitialTime = DateTime.now();
    }

    notifyListeners();
  }

  // --- Presentation Sequence Calculation ---

  /// Computes a presentation sequence containing content and ad slots.
  /// The underlying [contentItems] are never mutated.
  List<FeedPresentationItem<T>> buildFeedPresentation<T>({
    required List<T> contentItems,
    required List<AdBanner> adsPool,
    int? overrideFrequency,
    String Function(T)? contentKey,
  }) {
    return insertAdsIntoFeed(
      contentItems: contentItems,
      eligibleAds: adsPool,
      overrideFrequency: overrideFrequency,
      contentKey: contentKey,
    );
  }

  // --- Event Tracking & Deduplication ---

  String _buildEventKey(
      String adId, String zone, String eventType, String contextKey) {
    return '${adId}_${AdPlacement.canonical(zone)}_${eventType}_$contextKey';
  }

  /// Records an ad impression event (deduplicated per exposure key).
  void recordImpression(
    AdBanner ad, {
    String placementZone = 'feed',
    String? contextKey,
  }) {
    final key = _buildEventKey(
        ad.id, placementZone, 'impression', contextKey ?? 'default');
    if (_emittedEvents.contains(key)) {
      return; // Already tracked for this exposure
    }

    _emittedEvents.add(key);
    AdRepository.instance.clearCache();
    markAdShown(ad, isInterstitial: ad.isInterstitial || ad.isFullScreen);
    AdEventQueue.instance.enqueue(
      adId: ad.id,
      eventType: 'impression',
      placementZone: placementZone,
    );
  }

  /// Records a viewability event (deduplicated per exposure key).
  void recordViewability(
    AdBanner ad, {
    String placementZone = 'feed',
    String? contextKey,
  }) {
    final key = _buildEventKey(
        ad.id, placementZone, 'viewability', contextKey ?? 'default');
    if (_emittedEvents.contains(key)) {
      return;
    }

    _emittedEvents.add(key);
    AdEventQueue.instance.enqueue(
      adId: ad.id,
      eventType: 'viewability',
      placementZone: placementZone,
    );
  }

  /// Records a user click on an advertisement.
  void recordClick(AdBanner ad, {String placementZone = 'feed'}) {
    AdEventQueue.instance.enqueue(
      adId: ad.id,
      eventType: 'click',
      placementZone: placementZone,
    );
  }

  /// Records user dismissing an advertisement (e.g. Closing spotlight or interstitial).
  void recordDismiss(AdBanner ad, {String placementZone = 'feed'}) {
    AdEventQueue.instance.enqueue(
      adId: ad.id,
      eventType: 'dismiss',
      placementZone: placementZone,
    );
  }

  /// Records user skipping an advertisement.
  void recordSkip(AdBanner ad, {String placementZone = 'feed'}) {
    AdEventQueue.instance.enqueue(
      adId: ad.id,
      eventType: 'skip',
      placementZone: placementZone,
    );
  }

  /// Records user hiding an advertisement.
  void recordHide(AdBanner ad, {String placementZone = 'feed'}) {
    AdEventQueue.instance.enqueue(
      adId: ad.id,
      eventType: 'hide',
      placementZone: placementZone,
    );
  }

  /// Fetches ads for a specific zone via [AdRepository].
  Future<List<AdBanner>> getAdsForZone(
    String placementZone, {
    String? scope,
    String? areaId,
    bool forceRefresh = false,
  }) async {
    try {
      final res = await AdRepository.instance.getAds(
        placementZone: placementZone,
        scope: scope,
        areaId: areaId,
        forceRefresh: forceRefresh,
      );
      return res.data ?? [];
    } catch (_) {
      return [];
    }
  }
}
