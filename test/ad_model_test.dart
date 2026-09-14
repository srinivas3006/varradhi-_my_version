import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/core/ads/ad_type_resolver.dart';

void main() {
  group('AdBanner Model Tests', () {
    test('parses full valid JSON payload with all fields', () {
      final json = {
        'id': 'ad_101',
        'title': 'Telangana Handlooms Expo',
        'image_url': 'https://example.com/images/banner.jpg',
        'video_url': 'https://example.com/videos/promo.mp4',
        'destination_url': 'https://handlooms.telangana.gov.in',
        'ad_type': 'video',
        'placement_zone': 'feed',
        'target_scope': 'state',
        'area': 'Telangana',
        'area_id': 'area_ts_01',
        'display_frequency': 4,
        'daily_max_impressions_per_user': 3,
        'ctr': 3.75,
      };

      final ad = AdBanner.fromJson(json);

      expect(ad.id, 'ad_101');
      expect(ad.title, 'Telangana Handlooms Expo');
      expect(ad.imageUrl, 'https://example.com/images/banner.jpg');
      expect(ad.videoUrl, 'https://example.com/videos/promo.mp4');
      expect(ad.destinationUrl, 'https://handlooms.telangana.gov.in');
      expect(ad.adType, 'video');
      expect(ad.placementZone, 'feed');
      expect(ad.targetScope, 'state');
      expect(ad.area, 'Telangana');
      expect(ad.areaId, 'area_ts_01');
      expect(ad.displayFrequency, 4);
      expect(ad.dailyMaxImpressionsPerUser, 3);
      expect(ad.ctr, 3.75);
      expect(ad.isVideo, isTrue);
    });

    test('handles missing, null, and fallback fields safely', () {
      final json = <String, dynamic>{
        'id': 'ad_minimal',
      };

      final ad = AdBanner.fromJson(json);

      expect(ad.id, 'ad_minimal');
      expect(ad.title, 'Sponsored Promotion');
      expect(ad.imageUrl, '');
      expect(ad.videoUrl, '');
      expect(ad.destinationUrl, '');
      expect(ad.adType, 'banner');
      expect(ad.placementZone, 'feed');
      expect(ad.targetScope, 'global');
      expect(ad.area, isNull);
      expect(ad.areaId, isNull);
      expect(ad.displayFrequency, 5); // Default fallback 5
      expect(ad.dailyMaxImpressionsPerUser, 0);
      expect(ad.ctr, 0.0);
      expect(ad.isVideo, isFalse);
    });

    test('safely parses string-coerced and dirty numeric values', () {
      final json = {
        'id': 12345, // int id
        'title': 'Coerced Ad',
        'display_frequency': '8',
        'daily_max_impressions_per_user': '2',
        'ctr': '1.85',
      };

      final ad = AdBanner.fromJson(json);

      expect(ad.id, '12345');
      expect(ad.displayFrequency, 8);
      expect(ad.dailyMaxImpressionsPerUser, 2);
      expect(ad.ctr, 1.85);
    });

    test('normalizes alternative keys (banner_url, target_url, click_url)', () {
      final json = {
        'id': 'ad_alt',
        'banner_url': '/media/banners/sale.jpg',
        'target_url': 'https://example.com/sale',
        'video': 'https://example.com/video.mp4',
      };

      final ad = AdBanner.fromJson(json);

      expect(ad.imageUrl.startsWith('http'), isTrue);
      expect(ad.imageUrl.contains('/media/banners/sale.jpg'), isTrue);
      expect(ad.destinationUrl, 'https://example.com/sale');
      expect(ad.videoUrl, 'https://example.com/video.mp4');
      expect(ad.isVideo, isTrue);
    });

    test('copyWith updates specified fields and preserves existing', () {
      final original = AdBanner(
        id: 'ad_1',
        imageUrl: 'https://example.com/1.jpg',
        destinationUrl: 'https://example.com',
        adType: 'native',
        placementZone: 'feed',
        targetScope: 'global',
        displayFrequency: 5,
        ctr: 1.0,
      );

      final updated = original.copyWith(
        title: 'New Title',
        displayFrequency: 3,
        dailyMaxImpressionsPerUser: 5,
      );

      expect(updated.id, 'ad_1');
      expect(updated.title, 'New Title');
      expect(updated.displayFrequency, 3);
      expect(updated.dailyMaxImpressionsPerUser, 5);
      expect(updated.imageUrl, 'https://example.com/1.jpg');
    });

    test('toJson serializes correctly', () {
      final ad = AdBanner(
        id: 'ad_json',
        title: 'JSON Test',
        imageUrl: 'https://example.com/img.jpg',
        videoUrl: 'https://example.com/vid.mp4',
        destinationUrl: 'https://example.com',
        adType: 'video',
        placementZone: 'feed',
        targetScope: 'local',
        area: 'Hyderabad',
        areaId: 'hyd_01',
        displayFrequency: 4,
        dailyMaxImpressionsPerUser: 2,
        ctr: 2.5,
      );

      final map = ad.toJson();

      expect(map['id'], 'ad_json');
      expect(map['title'], 'JSON Test');
      expect(map['image_url'], 'https://example.com/img.jpg');
      expect(map['video_url'], 'https://example.com/vid.mp4');
      expect(map['area'], 'Hyderabad');
      expect(map['area_id'], 'hyd_01');
      expect(map['display_frequency'], 4);
      expect(map['daily_max_impressions_per_user'], 2);
    });
  });

  group('AdTypeResolver Tests', () {
    test('resolves all 12 frontend ad types accurately', () {
      expect(AdTypeResolver.resolveType('banner'), AdPresentationType.banner);
      expect(AdTypeResolver.resolveType('box'), AdPresentationType.box);
      expect(AdTypeResolver.resolveType('three_d'), AdPresentationType.threeD);
      expect(AdTypeResolver.resolveType('interstitial'),
          AdPresentationType.interstitial);
      expect(
          AdTypeResolver.resolveType('native'), AdPresentationType.nativeCard);
      expect(AdTypeResolver.resolveType('video'), AdPresentationType.videoCard);
      expect(AdTypeResolver.resolveType('poster'), AdPresentationType.poster);
      expect(AdTypeResolver.resolveType('sponsored_card'),
          AdPresentationType.sponsoredCard);
      expect(AdTypeResolver.resolveType('breaking_strip'),
          AdPresentationType.breakingStrip);
      expect(AdTypeResolver.resolveType('local_listing'),
          AdPresentationType.localListing);
      expect(AdTypeResolver.resolveType('full_screen'),
          AdPresentationType.fullScreen);
      expect(AdTypeResolver.resolveType('bottom_sticky'),
          AdPresentationType.bottomSticky);
    });

    test('provides recommended fixed aspect ratios per ad type', () {
      expect(AdTypeResolver.getFixedAspectRatio('banner'), 16 / 5);
      expect(AdTypeResolver.getFixedAspectRatio('box'), 1.0);
      expect(AdTypeResolver.getFixedAspectRatio('three_d'), 4 / 3);
      expect(AdTypeResolver.getFixedAspectRatio('video'), 16 / 9);
      expect(AdTypeResolver.getFixedAspectRatio('poster'), 4 / 5);
      expect(AdTypeResolver.getFixedAspectRatio('native'), 16 / 9);
      expect(AdTypeResolver.getFixedAspectRatio('sponsored_card'), 16 / 9);
      expect(AdTypeResolver.getFixedAspectRatio('local_listing'), 16 / 7);
    });

    test('provides recommended fixed heights for strip and sticky banners', () {
      expect(AdTypeResolver.getFixedHeight('breaking_strip'), 42.0);
      expect(AdTypeResolver.getFixedHeight('bottom_sticky'), 64.0);
    });

    test('resolves explicit type independently of video URL', () {
      expect(AdTypeResolver.resolveType('video'), AdPresentationType.videoCard);

      final videoAd = AdBanner(
        id: 'v1',
        imageUrl: 'https://example.com/poster.jpg',
        videoUrl: 'https://example.com/ad.mp4',
        destinationUrl: '',
        adType: 'native', // marked native but has videoUrl
        placementZone: 'feed',
        targetScope: 'global',
        displayFrequency: 5,
        ctr: 0.0,
      );
      expect(AdTypeResolver.resolve(videoAd), AdPresentationType.nativeCard);
    });

    test(
        'gracefully resolves unrecognized types to AdPresentationType.unsupported',
        () {
      expect(AdTypeResolver.resolveType('unknown_hologram'),
          AdPresentationType.unsupported);
      expect(AdTypeResolver.resolve(null), AdPresentationType.unsupported);
    });
  });
}
