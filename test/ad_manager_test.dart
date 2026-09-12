import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/services/ad_manager.dart';
import 'package:way2news_clone/core/ads/ad_event_queue.dart';

void main() {
  group('AdManager Tests', () {
    late AdManager manager;

    final adA = AdBanner(
      id: 'ad_A',
      title: 'Ad A',
      imageUrl: 'https://example.com/a.jpg',
      destinationUrl: 'https://example.com/a',
      adType: 'native',
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: 4,
      ctr: 1.0,
    );

    final adB = AdBanner(
      id: 'ad_B',
      title: 'Ad B',
      imageUrl: 'https://example.com/b.jpg',
      destinationUrl: 'https://example.com/b',
      adType: 'native',
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: 4,
      ctr: 2.0,
    );

    final cappedAd = AdBanner(
      id: 'ad_capped',
      title: 'Capped Ad',
      imageUrl: 'https://example.com/c.jpg',
      destinationUrl: 'https://example.com/c',
      adType: 'banner',
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: 5,
      dailyMaxImpressionsPerUser: 1, // max 1 per user
      ctr: 1.5,
    );

    setUp(() {
      manager = AdManager.createTest();
      AdEventQueue.instance.reset();
    });

    tearDown(() {
      manager.resetSession();
      AdEventQueue.instance.reset();
    });

    test('selectAd returns null when pool is empty', () {
      expect(manager.selectAd([]), isNull);
    });

    test('selectAd selects available unshown ad from pool', () {
      final selected = manager.selectAd([adA, adB]);
      expect(selected, isNotNull);
      expect(selected!.id, 'ad_A');
    });

    test('selectAd rotates to next unshown ad after an ad is shown', () {
      manager.markAdShown(adA);
      final next = manager.selectAd([adA, adB]);
      expect(next, isNotNull);
      expect(next!.id, 'ad_B');
    });

    test('selectAd avoids immediate repeat when all ads have been shown', () {
      manager.markAdShown(adA);
      manager.markAdShown(adB);
      // Last shown was adB, so it should rotate back to adA
      final rotated = manager.selectAd([adA, adB]);
      expect(rotated, isNotNull);
      expect(rotated!.id, 'ad_A');
    });

    test('enforces dailyMaxImpressionsPerUser cap', () {
      // 1st time -> eligible
      final first = manager.selectAd([cappedAd]);
      expect(first, isNotNull);
      expect(first!.id, 'ad_capped');

      // Record impression
      manager.recordImpression(cappedAd, placementZone: 'feed', contextKey: 'exp1');

      // 2nd time -> daily cap reached (limit 1)
      final second = manager.selectAd([cappedAd]);
      expect(second, isNull);
    });

    test('canShowFeedAd respects minArticlesBeforeFirstAd and displayFrequency', () {
      // Never in first 2 items
      expect(manager.canShowFeedAd(contentIndex: 0, displayFrequency: 4), isFalse);
      expect(manager.canShowFeedAd(contentIndex: 1, displayFrequency: 4), isFalse);

      // Frequency 4: after min 2 items, slots at index 5, 9, 13
      // (contentIndex - 2 + 1) % 4 == 0 -> index 5: (5-2+1)=4 % 4 == 0 -> true
      expect(manager.canShowFeedAd(contentIndex: 2, displayFrequency: 4), isFalse);
      expect(manager.canShowFeedAd(contentIndex: 3, displayFrequency: 4), isFalse);
      expect(manager.canShowFeedAd(contentIndex: 4, displayFrequency: 4), isFalse);
      expect(manager.canShowFeedAd(contentIndex: 5, displayFrequency: 4), isTrue);
    });

    test('interstitial is blocked on cold launch before minSessionAge', () {
      // By default minSessionAgeForInterstitial is 5 minutes
      expect(manager.canShowInterstitial(), isFalse);
    });

    test('interstitial is blocked if engagement count is insufficient', () {
      // Simulate session age expired
      manager.minSessionAgeForInterstitial = Duration.zero;

      // Engagement count is 0 (below threshold of 3)
      expect(manager.canShowInterstitial(), isFalse);

      manager.recordContentInteraction();
      manager.recordContentInteraction();
      expect(manager.canShowInterstitial(), isFalse);

      manager.recordContentInteraction(); // 3rd interaction
      expect(manager.canShowInterstitial(), isTrue);
    });

    test('interstitial is blocked while active video is playing', () {
      manager.minSessionAgeForInterstitial = Duration.zero;
      manager.recordContentInteraction();
      manager.recordContentInteraction();
      manager.recordContentInteraction();

      expect(manager.canShowInterstitial(), isTrue);

      // Video playback begins
      manager.registerActiveVideo();
      expect(manager.isVideoActivelyPlaying, isTrue);
      expect(manager.canShowInterstitial(), isFalse);

      // Video playback ends
      manager.unregisterActiveVideo();
      expect(manager.isVideoActivelyPlaying, isFalse);
      expect(manager.canShowInterstitial(), isTrue);
    });

    test('interstitial is blocked during cooldown after previous interstitial', () {
      manager.minSessionAgeForInterstitial = Duration.zero;
      manager.minInterstitialCooldown = const Duration(minutes: 5);
      manager.recordContentInteraction();
      manager.recordContentInteraction();
      manager.recordContentInteraction();

      // Show interstitial
      manager.markAdShown(adA, isInterstitial: true);
      expect(manager.lastInterstitialTime, isNotNull);

      // Cooldown active -> blocked
      expect(manager.canShowInterstitial(), isFalse);

      // When cooldown is zero -> allowed
      manager.minInterstitialCooldown = Duration.zero;
      expect(manager.canShowInterstitial(), isTrue);
    });

    test('recordImpression deduplicates emissions for identical exposure keys', () {
      manager.recordImpression(adA, placementZone: 'feed', contextKey: 'slot_1');
      expect(AdEventQueue.instance.pendingCount, 1);

      // Second call with same key must be ignored
      manager.recordImpression(adA, placementZone: 'feed', contextKey: 'slot_1');
      expect(AdEventQueue.instance.pendingCount, 1);

      // Different exposure key -> recorded
      manager.recordImpression(adA, placementZone: 'feed', contextKey: 'slot_2');
      expect(AdEventQueue.instance.pendingCount, 2);
    });

    test('recordViewability deduplicates emissions for identical exposure keys', () {
      manager.recordViewability(adA, placementZone: 'feed', contextKey: 'slot_1');
      expect(AdEventQueue.instance.pendingCount, 1);

      // Repeated notification ignored
      manager.recordViewability(adA, placementZone: 'feed', contextKey: 'slot_1');
      expect(AdEventQueue.instance.pendingCount, 1);
    });

    test('recordClick, recordDismiss, and recordSkip enqueue events', () {
      manager.recordClick(adA, placementZone: 'feed');
      manager.recordDismiss(adA, placementZone: 'feed');
      manager.recordSkip(adA, placementZone: 'feed');

      expect(AdEventQueue.instance.pendingCount, 3);
    });
  });
}
