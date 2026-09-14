import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/core/ads/ad_type_resolver.dart';
import 'package:way2news_clone/core/ads/ad_event_queue.dart';
import 'package:way2news_clone/services/ad_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Frontend Ads Specification & Aspect Ratio Tests', () {
    late AdManager manager;

    setUp(() {
      manager = AdManager.createTest();
      AdEventQueue.instance.reset();
    });

    tearDown(() {
      manager.resetSession();
      AdEventQueue.instance.reset();
    });

    test(
        '1. APK enforces fixed UI aspect ratios and heights per ad type (no stretching)',
        () {
      expect(
          AdTypeResolver.getFixedAspectRatio('banner'), closeTo(16 / 5, 0.001));
      expect(AdTypeResolver.getFixedAspectRatio('box'), closeTo(1.0, 0.001));
      expect(
          AdTypeResolver.getFixedAspectRatio('three_d'), closeTo(4 / 3, 0.001));
      expect(
          AdTypeResolver.getFixedAspectRatio('video'), closeTo(16 / 9, 0.001));
      expect(
          AdTypeResolver.getFixedAspectRatio('poster'), closeTo(4 / 5, 0.001));
      expect(
          AdTypeResolver.getFixedAspectRatio('native'), closeTo(16 / 9, 0.001));
      expect(AdTypeResolver.getFixedAspectRatio('sponsored_card'),
          closeTo(16 / 9, 0.001));
      expect(AdTypeResolver.getFixedAspectRatio('local_listing'),
          closeTo(16 / 7, 0.001));

      // Fixed height components
      expect(AdTypeResolver.getFixedHeight('breaking_strip'), 42.0); // 36-48dp
      expect(AdTypeResolver.getFixedHeight('bottom_sticky'), 64.0); // 56-80dp
    });

    test(
        '2. Video vs Image URL separation: imageUrl is poster, videoUrl is source',
        () {
      final videoAd = AdBanner(
        id: 'v_spec',
        imageUrl: 'https://cdn.example.com/poster.jpg',
        videoUrl: 'https://cdn.example.com/stream.mp4',
        destinationUrl: 'https://example.com',
        adType: 'video',
        placementZone: 'feed',
        targetScope: 'global',
        displayFrequency: 4,
        ctr: 2.0,
      );

      expect(videoAd.isVideo, isTrue);
      expect(videoAd.imageUrl, 'https://cdn.example.com/poster.jpg');
      expect(videoAd.videoUrl, 'https://cdn.example.com/stream.mp4');

      final bannerAd = AdBanner(
        id: 'b_spec',
        imageUrl: 'https://cdn.example.com/banner.jpg',
        videoUrl: '',
        destinationUrl: 'https://example.com',
        adType: 'banner',
        placementZone: 'feed',
        targetScope: 'global',
        displayFrequency: 4,
        ctr: 1.0,
      );

      // imageUrl must not be treated as video
      expect(bannerAd.isVideo, isFalse);
      expect(bannerAd.isBanner, isTrue);
    });

    test('3. Feed placement adheres to display_frequency (every 4 articles)',
        () {
      final pool = [
        AdBanner(
          id: 'ad_rot_1',
          imageUrl: 'https://cdn.example.com/ad1.jpg',
          destinationUrl: 'https://example.com/1',
          adType: 'native',
          placementZone: 'feed',
          targetScope: 'global',
          displayFrequency: 4,
          ctr: 1.0,
        ),
        AdBanner(
          id: 'ad_rot_2',
          imageUrl: 'https://cdn.example.com/ad2.jpg',
          destinationUrl: 'https://example.com/2',
          adType: 'box',
          placementZone: 'feed',
          targetScope: 'global',
          displayFrequency: 4,
          ctr: 1.5,
        ),
      ];

      // 8 articles
      final articles = List.generate(8, (i) => 'Article ${i + 1}');

      final presentation = manager.buildFeedPresentation<String>(
        contentItems: articles,
        adsPool: pool,
        overrideFrequency: 4,
      );

      // Presentation structure should be:
      // Article 1, Article 2, Article 3, Article 4, Ad 1, Article 5, Article 6, Article 7, Article 8, Ad 2
      expect(presentation[0].isAd, isFalse);
      expect(presentation[1].isAd, isFalse);
      expect(presentation[2].isAd, isFalse);
      expect(presentation[3].isAd, isFalse);

      // 1st Ad placed after 4 articles
      expect(presentation[4].isAd, isTrue);
      expect(presentation[4].ad!.id, 'ad_rot_1');

      // Next 4 articles
      expect(presentation[5].isAd, isFalse);
      expect(presentation[6].isAd, isFalse);
      expect(presentation[7].isAd, isFalse);
      expect(presentation[8].isAd, isFalse);

      // 2nd Ad placed after 4 more articles, rotated to ad_rot_2!
      expect(presentation[9].isAd, isTrue);
      expect(presentation[9].ad!.id, 'ad_rot_2');
    });

    test('4. Multiple ads in backend pool rotate cleanly across feed slots',
        () {
      final pool = [
        AdBanner(
          id: 'ad_A',
          imageUrl: 'https://cdn.example.com/a.jpg',
          destinationUrl: 'https://example.com/a',
          adType: 'banner',
          placementZone: 'feed',
          targetScope: 'global',
          displayFrequency: 3,
          ctr: 1.0,
        ),
        AdBanner(
          id: 'ad_B',
          imageUrl: 'https://cdn.example.com/b.jpg',
          destinationUrl: 'https://example.com/b',
          adType: 'three_d',
          placementZone: 'feed',
          targetScope: 'global',
          displayFrequency: 3,
          ctr: 2.0,
        ),
      ];

      final articles = List.generate(9, (i) => 'Item $i');
      final presentation = manager.buildFeedPresentation<String>(
        contentItems: articles,
        adsPool: pool,
        overrideFrequency: 3,
      );

      final adsInFeed =
          presentation.where((p) => p.isAd).map((p) => p.ad!.id).toList();

      // Ensure multiple ads rotate instead of duplicating the same ad in all slots
      expect(adsInFeed.length, greaterThanOrEqualTo(2));
      expect(adsInFeed[0], 'ad_A');
      expect(adsInFeed[1], 'ad_B');
    });

    test('5. Defers daily cap eligibility to backend', () {
      final capped = AdBanner(
        id: 'ad_cap_test',
        imageUrl: 'https://cdn.example.com/cap.jpg',
        destinationUrl: 'https://example.com/cap',
        adType: 'banner',
        placementZone: 'feed',
        targetScope: 'global',
        displayFrequency: 5,
        dailyMaxImpressionsPerUser: 1, // Cap = 1 impression
        ctr: 1.0,
      );

      // 1st time -> eligible
      final first = manager.selectAd([capped]);
      expect(first, isNotNull);
      expect(first!.id, 'ad_cap_test');

      // Record impression
      manager.recordImpression(capped,
          placementZone: 'feed', contextKey: 'first_view');

      // A returned eligible ad stays eligible; session counts are not daily caps.
      final second = manager.selectAd([capped]);
      expect(second, isNotNull);
    });

    test('6. Tracks all supported ad lifecycle event types', () {
      final ad = AdBanner(
        id: 'ad_event_spec',
        imageUrl: 'https://cdn.example.com/test.jpg',
        destinationUrl: 'https://example.com/dest',
        adType: 'native',
        placementZone: 'feed',
        targetScope: 'global',
        displayFrequency: 4,
        ctr: 1.0,
      );

      // Impression
      manager.recordImpression(ad, placementZone: 'feed', contextKey: 'ctx1');
      expect(AdEventQueue.instance.pendingCount, 1);

      // Viewability
      manager.recordViewability(ad, placementZone: 'feed', contextKey: 'ctx1');
      expect(AdEventQueue.instance.pendingCount, 2);

      // Click
      manager.recordClick(ad, placementZone: 'feed');
      expect(AdEventQueue.instance.pendingCount, 3);

      // Dismiss
      manager.recordDismiss(ad, placementZone: 'feed');
      expect(AdEventQueue.instance.pendingCount, 4);

      // Skip
      manager.recordSkip(ad, placementZone: 'feed');
      expect(AdEventQueue.instance.pendingCount, 5);

      // Hide
      manager.recordHide(ad, placementZone: 'feed');
      expect(AdEventQueue.instance.pendingCount, 6);
    });
  });
}
