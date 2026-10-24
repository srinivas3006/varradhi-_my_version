import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/ads/ad_pacer.dart';
import 'package:vaaradhi/services/ad_manager.dart';
import 'package:vaaradhi/widgets/ads/full_screen_ad_image.dart';

void main() {
  group('full-screen creative fills the phone screen', () {
    const phone = 9 / 19.5; // a modern phone

    test('made at the phone ratio: fills edge to edge', () {
      expect(FullScreenAdImage.fills(1080 / 2340, phone), isTrue);
      expect(FullScreenAdImage.fills(1080 / 2400, phone), isTrue);
    });

    test('9:16 portrait poster: fills (only a sliver trimmed)', () {
      expect(FullScreenAdImage.fills(9 / 16, phone), isFalse,
          reason: '22 % off a 19.5:9 phone: shown whole, nothing cropped');
      expect(FullScreenAdImage.fills(9 / 16, 9 / 17), isTrue);
    });

    test('wide banner: shown whole over a blurred copy, never cropped', () {
      expect(FullScreenAdImage.fills(16 / 9, phone), isFalse);
      expect(FullScreenAdImage.fills(1, phone), isFalse);
    });

    test('every full-screen ad uses it', () {
      for (final f in [
        'lib/widgets/ads/interstitial_ad_overlay.dart',
        'lib/widgets/ads/sponsored_spotlight_ad_card.dart',
        'lib/screens/splash_screen.dart',
      ]) {
        expect(File(f).readAsStringSync(), contains('FullScreenAdImage('),
            reason: f);
      }
    });
  });

  test('ads that came every 5 minutes now come every 2', () {
    expect(AdPacer.sticky.every, const Duration(minutes: 2));
    expect(AdPacer.floating3d.every, const Duration(minutes: 2));
    final m = AdManager.instance;
    expect(m.minInterstitialCooldown, const Duration(minutes: 2));
    expect(m.minSessionAgeForInterstitial, const Duration(minutes: 2));
  });
}
