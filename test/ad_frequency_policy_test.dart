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

  group('Home: each ad once, spaced out, capped', () {
    test('one ad in the pool appears once, not every few stories', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: [_ad('kaart')],
        policy: AdFrequencyPolicy.home,
      );
      expect(_adIds(run), ['kaart']);
    });

    test('two ads: each once', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: [_ad('kaart'), _ad('red')],
        policy: AdFrequencyPolicy.home,
      );
      expect(_adIds(run), ['kaart', 'red']);
    });

    test('at least 6 stories between ads, none in the first 3', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: List.generate(8, (i) => _ad('a$i', every: 2)),
        policy: AdFrequencyPolicy.home,
      );
      final layout = _layout(run);
      final positions = [
        for (var i = 0; i < layout.length; i++)
          if (layout[i].startsWith('AD')) i
      ];
      expect(positions.first, greaterThanOrEqualTo(6));
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i] - positions[i - 1] - 1, greaterThanOrEqualTo(6));
      }
    });

    test('never more than 4 ads in the list', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: List.generate(10, (i) => _ad('a$i')),
        policy: AdFrequencyPolicy.home,
      );
      expect(_adIds(run).length, 4);
      expect(_adIds(run).toSet().length, 4, reason: 'all different');
    });
  });

  group('Spotlight: each ad at most twice, never back to back', () {
    test('one ad: twice at most', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: [_ad('kaart')],
        policy: AdFrequencyPolicy.spotlight,
      );
      expect(_adIds(run), ['kaart', 'kaart']);
    });

    test('two ads alternate and stop after two each', () {
      final run = insertAdsIntoFeed<int>(
        contentItems: stories,
        eligibleAds: [_ad('a'), _ad('b')],
        policy: AdFrequencyPolicy.spotlight,
      );
      final ids = _adIds(run);
      expect(ids, ['a', 'b', 'a', 'b']);
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], isNot(ids[i - 1]));
      }
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
