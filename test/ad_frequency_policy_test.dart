import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/ads/ad_insertion.dart';
import 'package:vaaradhi/models/ad_banner.dart';

AdBanner _ad(String id, {int every = 3}) => AdBanner(
      id: id,
      imageUrl: 'https://cdn.test/$id.jpg',
      destinationUrl: '',
      adType: 'banner',
      placementZone: 'feed',
      targetScope: 'global',
      displayFrequency: every,
      ctr: 0,
    );

List<String> _layout(List<FeedPresentationItem<int>> run) =>
    run.map((e) => e.isAd ? 'AD:${e.ad!.id}' : 's').toList();

List<String> _adIds(List<FeedPresentationItem<int>> run) =>
    run.where((e) => e.isAd).map((e) => e.ad!.id).toList();

void main() {
  final stories = List.generate(60, (i) => i);

  group('Home: as set in the admin, all the way down', () {
    test('an ad after every display_frequency stories, never running out', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: [_ad('kaart', every: 5)],
        policy: AdFrequencyPolicy.home,
      );
      expect(_adIds(run).length, 12, reason: '60 stories / 5');
      expect(_layout(run).take(6), ['s', 's', 's', 's', 's', 'AD:kaart']);
    });

    test('a short frequency is kept as set', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: List.generate(9, (i) => i),
        eligibleAds: [_ad('x', every: 3)],
        policy: AdFrequencyPolicy.home,
      );
      expect(_adIds(run), ['x', 'x', 'x']);
    });

    test('every ad takes its turn, never the same twice in a row', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: List.generate(10, (i) => _ad('a$i', every: 5)),
        policy: AdFrequencyPolicy.home,
      );
      final ids = _adIds(run);
      expect(ids.take(10).toSet().length, 10, reason: 'all 10 ads shown');
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], isNot(ids[i - 1]));
      }
    });
  });

  group('Spotlight: as set in the admin, all the way down', () {
    test('an ad after every display_frequency stories, never running out', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: [_ad('kaart', every: 5)],
        policy: AdFrequencyPolicy.spotlight,
      );
      expect(_adIds(run).length, 12, reason: '60 stories / 5');
      final layout = _layout(run);
      expect(layout.take(6), ['s', 's', 's', 's', 's', 'AD:kaart']);
    });

    test('a short frequency is kept, not stretched to 6', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: List.generate(9, (i) => i),
        eligibleAds: [_ad('x', every: 3)],
        policy: AdFrequencyPolicy.spotlight,
      );
      expect(_adIds(run), ['x', 'x', 'x']);
    });

    test('every ad takes its turn, never the same twice in a row', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: [_ad('a'), _ad('b'), _ad('c')],
        policy: AdFrequencyPolicy.spotlight,
      );
      final ids = _adIds(run);
      expect(ids.take(6), ['a', 'b', 'c', 'a', 'b', 'c']);
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], isNot(ids[i - 1]));
      }
    });

    test('a video ad is placed like any other', () {
      final video = AdBanner.fromJson({
        'id': 'vid',
        'image_url': 'https://cdn.test/p.jpg',
        'video_url': 'https://cdn.test/v.mp4',
        'ad_type': 'video',
        'placement_zone': 'spotlight',
        'display_frequency': 4,
      });
      final run = insertAdsIntoFeed<int>(
        contentItems: List.generate(12, (i) => i),
        eligibleAds: [video],
        allowTimed: true,
        policy: AdFrequencyPolicy.spotlight,
      );
      expect(_adIds(run), ['vid', 'vid', 'vid'],
          reason: 'zone "spotlight" is the feed placement');
    });
  });

  test('without a policy the old rotation is unchanged', () {
    final run = insertAdsIntoFeed<int>(
      contentItems: List.generate(9, (i) => i),
      eligibleAds: [_ad('x')],
    );
    expect(_adIds(run), ['x', 'x', 'x']);
  });

  test('Home and Spotlight use their policies', () {
    expect(File('lib/screens/news_feed_tab.dart').readAsStringSync(),
        contains('policy: AdFrequencyPolicy.home'));
    expect(File('lib/spotlight/spotlight_controller.dart').readAsStringSync(),
        contains('policy: AdFrequencyPolicy.spotlight'));
  });
}
