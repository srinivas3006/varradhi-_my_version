import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/ad_banner.dart';

/// Intelligent, behavior-based monetization engine.
///
/// Ensures ads feel natural, native, and never interrupt the user experience.
/// Implements:
/// 1. Dwell-time qualification (>= 2s dwell counts as meaningful read).
/// 2. Rapid-swipe suppression (fast swipes delay ads).
/// 3. Article count rules (1 ad per 4-6 meaningful reads, or 5 meaningful spotlight swipes).
/// 4. Hard rules: No ad in first 2 articles, cooldown of 3-4 articles, no back-to-back, no repeat ads on back-swipe.
/// 5. Comprehensive session tracking (articlesReadCount, lastAdShownIndex, userEngagementScore).
class AdDeliveryService extends ChangeNotifier {
  static final AdDeliveryService instance = AdDeliveryService._internal();
  AdDeliveryService._internal();

  // --- Session Tracking State ---
  int _articlesReadCount = 0;
  int _lastAdShownIndex = -999;
  int _lastAdShownArticleCount = -999;
  double _userEngagementScore = 1.0;

  // Track positions and creative IDs already shown to prevent repeat ads
  final Set<String> _shownAdIds = <String>{};
  final Set<int> _shownAdPositions = <int>{};

  // Internal counters for Spotlight swipe mode
  int _meaningfulSpotlightSwipes = 0;
  int _consecutiveFastSwipes = 0;
  bool _isRapidSwiping = false;

  // Dwell timer tracking
  DateTime? _pageDwellStartTime;
  int? _currentArticleIndex;

  // Getters for external consumption & analytics
  int get articlesReadCount => _articlesReadCount;
  int get lastAdShownIndex => _lastAdShownIndex;
  double get userEngagementScore => _userEngagementScore;
  int get meaningfulSpotlightSwipes => _meaningfulSpotlightSwipes;
  bool get isRapidSwiping => _isRapidSwiping;

  // --- Configuration Constants ---
  static const int minArticlesBeforeFirstAd =
      5; // Show first ad after 5 content items
  static const int minCooldownArticles =
      3; // Skip next 3-4 articles before next ad
  static const int spotlightSwipesThreshold =
      5; // Show ad after 5 meaningful swipes
  static const int feedArticlesInterval =
      5; // Show 1 ad after every 5 content items
  static const Duration meaningfulDwellThreshold =
      Duration(milliseconds: 2000); // >= 2s
  static const Duration rapidSwipeThreshold =
      Duration(milliseconds: 1400); // < 1.4s

  /// Called when a user settles on an article page/card (e.g. In Spotlight or Full Card).
  void onPageSelected(int index) {
    final now = DateTime.now();

    // Check dwell time on the previous article if any
    if (_pageDwellStartTime != null && _currentArticleIndex != null) {
      final elapsed = now.difference(_pageDwellStartTime!);
      _evaluateDwell(
        articleIndex: _currentArticleIndex!,
        dwellDuration: elapsed,
      );
    }

    _pageDwellStartTime = now;
    _currentArticleIndex = index;
  }

  /// Evaluates whether the time spent on an article qualifies as a meaningful read or a fast swipe.
  void _evaluateDwell({
    required int articleIndex,
    required Duration dwellDuration,
    bool userScrolled = false,
  }) {
    if (dwellDuration < rapidSwipeThreshold && !userScrolled) {
      // User flicked rapidly
      _consecutiveFastSwipes++;
      _isRapidSwiping = true;
      // Rapid swiping decreases engagement score slightly and delays ad delivery
      _userEngagementScore = max(0.5, _userEngagementScore - 0.05);
      debugPrint(
          '[AdDelivery] Fast swipe detected on item $articleIndex (${dwellDuration.inMilliseconds}ms). Ad delayed. Fast streak: $_consecutiveFastSwipes');
    } else if (dwellDuration >= meaningfulDwellThreshold || userScrolled) {
      // Meaningful read!
      _consecutiveFastSwipes = 0;
      _isRapidSwiping = false;
      _articlesReadCount++;
      _meaningfulSpotlightSwipes++;

      // Increase engagement score
      final bonus = min(1.0, dwellDuration.inMilliseconds / 5000.0) * 0.15;
      _userEngagementScore = min(3.0, _userEngagementScore + bonus);

      debugPrint(
          '[AdDelivery] Meaningful read on item $articleIndex (${dwellDuration.inMilliseconds}ms). Read count: $_articlesReadCount, Meaningful swipes: $_meaningfulSpotlightSwipes, Score: ${_userEngagementScore.toStringAsFixed(2)}');
      notifyListeners();
    }
  }

  /// Explicitly records a meaningful content interaction (e.g. User scrolled, liked, or read more).
  void recordContentInteraction(int articleIndex) {
    if (_currentArticleIndex == articleIndex) {
      _evaluateDwell(
        articleIndex: articleIndex,
        dwellDuration: meaningfulDwellThreshold,
        userScrolled: true,
      );
    }
  }

  /// Checks if an ad can be naturally inserted in the Spotlight (Swipe Mode) flow.
  ///
  /// Strictly checks:
  /// - Hard Rule: currentIndex >= 2 (never in first 2 articles)
  /// - Hard Rule: Cooldown passed (>= 3 meaningful articles since last ad)
  /// - Spotlight Rule: >= 5 meaningful swipes completed
  /// - Rapid Swiping: Must NOT be rapidly swiping
  /// - No Repeat: Position must not have been shown already
  bool canShowSpotlightAd(
      {required int targetIndex, required bool isSwipingBack}) {
    // Hard Rule 1: Never show in first 2 articles
    if (targetIndex < minArticlesBeforeFirstAd) {
      return false;
    }

    // Hard Rule 4: If user is swiping back, never show an ad
    if (isSwipingBack) {
      return false;
    }

    // Hard Rule 4: Position already had an ad
    if (_shownAdPositions.contains(targetIndex)) {
      return false;
    }

    // If user is rapidly swiping, delay ad until user settles
    if (_isRapidSwiping || _consecutiveFastSwipes >= 2) {
      debugPrint(
          '[AdDelivery] Spotlight ad blocked: Rapid swiping in progress');
      return false;
    }

    // Cool-down check: skip next 3-4 articles before next ad
    if (_lastAdShownIndex >= 0 &&
        (targetIndex - _lastAdShownIndex).abs() <= minCooldownArticles) {
      return false;
    }

    // Cool-down in terms of articles consumed
    if (_lastAdShownArticleCount >= 0 &&
        (_articlesReadCount - _lastAdShownArticleCount) < minCooldownArticles) {
      return false;
    }

    // Spotlight Rule: Show ad after 5 meaningful swipes
    if (_meaningfulSpotlightSwipes >= spotlightSwipesThreshold) {
      return true;
    }

    return false;
  }

  /// Checks if a native ad can be placed at [articleIndex] in the news feed list.
  bool canShowFeedAd({required int articleIndex}) {
    // Hard Rule 1: Never in first 2 articles
    if (articleIndex < minArticlesBeforeFirstAd) {
      return false;
    }

    // Position already shown
    if (_shownAdPositions.contains(articleIndex)) {
      return false;
    }

    // Cooldown check: at least 3-4 articles between ads
    if (_lastAdShownIndex >= 0 &&
        (articleIndex - _lastAdShownIndex) < (minCooldownArticles + 1)) {
      return false;
    }

    // Deterministic fallback: show one ad after every 5 content items.
    if (_articlesReadCount >= feedArticlesInterval ||
        (articleIndex >= minArticlesBeforeFirstAd &&
            articleIndex % feedArticlesInterval == 0)) {
      return true;
    }

    return false;
  }

  /// Selects the best non-repeating ad from available inventory.
  AdBanner? selectAd(List<AdBanner> availableAds) {
    if (availableAds.isEmpty) return null;

    // Filter out ads already shown this session
    final unshownAds =
        availableAds.where((ad) => !_shownAdIds.contains(ad.id)).toList();

    if (unshownAds.isNotEmpty) {
      // Pick ad with highest display weight or first available
      return unshownAds.first;
    }

    // If all ads have been shown at least once, rotate back to the oldest
    return availableAds.first;
  }

  /// Marks an ad as shown to enforce anti-repeat and cooldown tracking.
  void markAdShown({
    required String adId,
    required int position,
  }) {
    _shownAdIds.add(adId);
    _shownAdPositions.add(position);
    _lastAdShownIndex = position;
    _lastAdShownArticleCount = _articlesReadCount;
    _meaningfulSpotlightSwipes =
        0; // Reset counter for next 5 meaningful swipes

    debugPrint(
        '[AdDelivery] Ad shown: ID=$adId at position=$position. Resetting meaningful swipes counter.');
    notifyListeners();
  }

  /// Resets the dwell timer and session state (e.g. On pull-to-refresh).
  void resetSession() {
    _articlesReadCount = 0;
    _lastAdShownIndex = -999;
    _lastAdShownArticleCount = -999;
    _meaningfulSpotlightSwipes = 0;
    _consecutiveFastSwipes = 0;
    _isRapidSwiping = false;
    _pageDwellStartTime = DateTime.now();
    _shownAdPositions.clear();
    _shownAdIds.clear();
    notifyListeners();
  }
}
