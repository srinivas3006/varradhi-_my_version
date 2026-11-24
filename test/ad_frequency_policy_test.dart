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

class _SpotlightCard {
  const _SpotlightCard(this.id,
      {this.isArticle = false, this.isPromotion = false});

  final String id;
  final bool isArticle;
  final bool isPromotion;
}

List<String> _layout<T>(List<FeedPresentationItem<T>> run) =>
    run.map((e) => e.isAd ? 'AD:${e.ad!.id}' : 's').toList();

List<String> _adIds<T>(List<FeedPresentationItem<T>> run) =>
    run.where((e) => e.isAd).map((e) => e.ad!.id).toList();

void main() {
  final stories = List.generate(60, (i) => i);

  for (final rawFrequency in [1, '1']) {
    for (final entry in {
      'Home': AdFrequencyPolicy.home,
      'Spotlight': AdFrequencyPolicy.spotlight,
    }.entries) {
      final policy = entry.value;
      test(
          '${entry.key}: backend ${rawFrequency.runtimeType} frequency '
          '$rawFrequency survives parsing and insertion '
          'with minGap=${policy.minGap}', () {
        final ad = AdBanner.fromJson({
          'id': 'one',
          'display_frequency': rawFrequency,
        });
        expect(ad.displayFrequency, 1);
        final run = insertAdsIntoFeed<int>(
          contentItems: [1, 2, 3],
          eligibleAds: [ad],
          policy: policy,
        );
        expect(_layout(run), ['s', 'AD:one', 's', 'AD:one', 's', 'AD:one']);
        for (var i = 1; i < run.length; i++) {
          expect(run[i].isAd && run[i - 1].isAd, isFalse);
        }
      });
    }
  }

  test('an explicit minimum gap takes precedence over a shorter frequency', () {
    final ad = _ad('one', every: 1);
    const policy = AdFrequencyPolicy(minGap: 3);
    final run = insertAdsIntoFeed<int>(
      contentItems: List.generate(6, (i) => i),
      eligibleAds: [ad],
      policy: policy,
    );
    expect(_layout(run), ['s', 's', 's', 'AD:one', 's', 's', 's', 'AD:one']);
    expect(ad.displayFrequency, 1,
        reason: 'the backend value is never rewritten');
  });

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

    test('spacing counts unique news and defers around promotional posters',
        () {
      final content = <_SpotlightCard>[
        for (var i = 1; i <= 20; i++) ...[
          _SpotlightCard('story-$i', isArticle: true),
          if (i == 6 || i == 12) _SpotlightCard('poster-$i', isPromotion: true),
        ],
      ];
      final run = insertAdsIntoFeed<_SpotlightCard>(
        contentItems: content,
        eligibleAds: [_ad('a', every: 6), _ad('b', every: 6)],
        policy: AdFrequencyPolicy.spotlight,
        isEligibleContent: (card) => card.isArticle,
        eligibleContentKey: (card) => card.isArticle ? card.id : null,
        isPromotion: (card) => card.isPromotion,
      );

      final adPositions = [
        for (var i = 0; i < run.length; i++)
          if (run[i].isAd) i,
      ];
      expect(adPositions, isNotEmpty);
      for (final position in adPositions) {
        expect(run[position - 1].content!.isPromotion, isFalse);
        expect(
            position + 1 == run.length
                ? false
                : run[position + 1].content?.isPromotion ?? false,
            isFalse);
      }
      for (var i = 1; i < adPositions.length; i++) {
        final newsBetween = run
            .sublist(adPositions[i - 1] + 1, adPositions[i])
            .where((entry) => entry.content?.isArticle ?? false)
            .length;
        expect(newsBetween, greaterThanOrEqualTo(6));
      }
    });

    test('refresh and pagination preserve consumed article and ad progress',
        () {
      final progress = AdInsertionProgress();
      final content = List.generate(
        20,
        (index) => _SpotlightCard('story-${index + 1}', isArticle: true),
      );
      final ads = [_ad('a', every: 6), _ad('b', every: 6)];

      final initial = insertAdsIntoFeed<_SpotlightCard>(
        contentItems: content,
        eligibleAds: ads,
        policy: AdFrequencyPolicy.spotlight,
        progress: progress,
        isEligibleContent: (card) => card.isArticle,
        eligibleContentKey: (card) => card.id,
      );
      expect(_adIds(initial), ['a', 'b', 'a']);

      for (var i = 1; i <= 6; i++) {
        progress.recordContentConsumed('story-$i');
      }
      progress.recordAdShown('a');

      final refreshed = insertAdsIntoFeed<_SpotlightCard>(
        contentItems: content,
        eligibleAds: ads,
        policy: AdFrequencyPolicy.spotlight,
        progress: progress,
        isEligibleContent: (card) => card.isArticle,
        eligibleContentKey: (card) => card.id,
      );
      final rebuilt = insertAdsIntoFeed<_SpotlightCard>(
        contentItems: content,
        eligibleAds: ads,
        policy: AdFrequencyPolicy.spotlight,
        progress: progress,
        isEligibleContent: (card) => card.isArticle,
        eligibleContentKey: (card) => card.id,
      );

      expect(_adIds(refreshed), ['b', 'a']);
      expect(refreshed.map((entry) => entry.stableKey).toList(),
          rebuilt.map((entry) => entry.stableKey).toList(),
          reason: 'rebuilding the same feed must retain its ad sequence');
      expect(progress.totalContentConsumed, 6);
      expect(progress.contentSinceLastAd, 0);
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
