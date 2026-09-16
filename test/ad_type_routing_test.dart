import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/ads/ad_type_resolver.dart';
import 'package:way2news_clone/models/ad_banner.dart';

AdBanner _ad(String type, {String video = ''}) => AdBanner.fromJson({
      'id': 'a',
      'ad_type': type,
      'image_url': 'https://cdn.example.com/i.jpg',
      'video_url': video,
      'destination_url': 'https://example.com',
    });

void main() {
  test('every ad_type maps to its own component', () {
    const expected = {
      'banner': AdPresentationType.banner,
      'box': AdPresentationType.box,
      'three_d': AdPresentationType.threeD,
      'interstitial': AdPresentationType.interstitial,
      'native': AdPresentationType.nativeCard,
      'video': AdPresentationType.videoCard,
      'poster': AdPresentationType.poster,
      'sponsored_card': AdPresentationType.sponsoredCard,
      'breaking_strip': AdPresentationType.breakingStrip,
      'local_listing': AdPresentationType.localListing,
      'full_screen': AdPresentationType.fullScreen,
      'bottom_sticky': AdPresentationType.bottomSticky,
    };
    expected.forEach((type, want) {
      expect(AdTypeResolver.resolve(_ad(type)), want, reason: type);
    });
  });

  test('a video_url does not hijack another ad_type', () {
    // image types keep their component even when a video is attached
    for (final type in ['poster', 'full_screen', 'banner', 'bottom_sticky']) {
      expect(
        AdTypeResolver.resolve(_ad(type, video: 'https://cdn/v.mp4')),
        isNot(AdPresentationType.videoCard),
        reason: type,
      );
    }
    expect(AdTypeResolver.resolve(_ad('video', video: 'https://cdn/v.mp4')),
        AdPresentationType.videoCard);
  });
}
