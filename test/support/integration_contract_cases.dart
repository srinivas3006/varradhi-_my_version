import 'package:way2news_clone/core/ads/ad_insertion.dart';
import 'package:way2news_clone/core/ads/ad_placement.dart';
import 'package:way2news_clone/core/ads/ad_type_resolver.dart';
import 'package:way2news_clone/core/state/feed_state.dart';
import 'package:way2news_clone/models/ad_banner.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/models/spotlight_item.dart';
import 'package:way2news_clone/models/unified_feed_item.dart';

void require(bool value, String reason) {
  if (!value) throw StateError(reason);
}

AdBanner ad(String id,
        {int frequency = 4,
        String type = 'banner',
        String zone = 'feed',
        int duration = 0,
        int cap = 0}) =>
    AdBanner.fromJson({
      'id': id,
      'ad_type': type,
      'placement_zone': zone,
      'image_url': 'https://example.com/$id.jpg',
      'destination_url': 'https://example.com',
      'display_frequency': frequency,
      'display_duration_seconds': duration,
      'daily_max_impressions_per_user': cap
    });

NewsArticle story(String id, List<String> mediaTypes,
        {String kind = 'article'}) =>
    NewsArticle.fromJson({
      'id': id,
      'type': kind,
      'title': 'Story $id',
      'media_items': [
        for (var i = 0; i < mediaTypes.length; i++)
          {
            'media_type': mediaTypes[i],
            'url':
                'https://example.com/$id-$i.${mediaTypes[i] == 'video' ? 'mp4' : 'jpg'}',
            'sort_order': mediaTypes.length - i,
            'is_primary': i == mediaTypes.length - 1
          }
      ]
    });

Map<String, void Function()> integrationContractCases() => {
      'canonical ad duration preserves zero and ignores frequency as time': () {
        final zero = ad('a', frequency: 9);
        final timed = ad('b', duration: 7, cap: 3);
        require(zero.durationSeconds == 0 && zero.displayFrequency == 9,
            'zero timer invented');
        require(
            timed.displayDurationSeconds == 7 &&
                timed.dailyMaxImpressionsPerUser == 3,
            'fields conflated');
        require(timed.toJson()['display_duration_seconds'] == 7,
            'canonical serialization missing');
        require(AdBanner.fromJson(timed.toJson()).durationSeconds == 7,
            'duration lost in cache');
      },
      'zero cap remains backend-default metadata': () {
        require(ad('a', cap: 0).dailyMaxImpressionsPerUser == 0,
            'zero cap rewritten');
        require(
            insertAdsIntoFeed(
                    contentItems: [1, 2, 3, 4],
                    eligibleAds: [ad('a', cap: 0)]).length ==
                5,
            'eligible backend default-cap ad suppressed');
        require(
            insertAdsIntoFeed(
                    contentItems: [1, 2, 3, 4],
                    eligibleAds: <AdBanner>[]).length ==
                4,
            'absent backend ad invented');
      },
      'four parent cards insert one ad and eight insert two': () {
        for (final count in [4, 8]) {
          final run = insertAdsIntoFeed(
              contentItems: List.generate(count, (i) => i),
              eligibleAds: [ad('a')]);
          require(run.where((item) => item.isAd).length == count ~/ 4,
              'incorrect ad count');
          require(run[4].isAd && (count == 4 || run[9].isAd),
              'incorrect insertion positions');
        }
      },
      'ten internal media entries still count as four parents': () {
        final parents = [
          story('a', ['image', 'image', 'image', 'video']),
          story('b', ['image']),
          story('c', ['image', 'video', 'image'], kind: 'ugc'),
          story('d', ['video', 'image'])
        ];
        final run =
            insertAdsIntoFeed(contentItems: parents, eligibleAds: [ad('a')]);
        require(run.length == 5 && run.last.isAd, 'media counted as content');
        require(run.first.content == parents.first && parents.length == 4,
            'parents mutated');
      },
      'multiple ads rotate A B C A without stacking': () {
        final run = insertAdsIntoFeed(
            contentItems: List.generate(16, (i) => i),
            eligibleAds: [ad('a'), ad('b'), ad('c')]);
        require(
            run
                    .where((item) => item.isAd)
                    .map((item) => item.ad!.id)
                    .join(',') ==
                'a,b,c,a',
            'rotation incorrect');
        require(
            run
                    .where((item) => item.isAd)
                    .map((item) => item.stableKey)
                    .toSet()
                    .length ==
                4,
            'repeated ad exposures share one key');
      },
      'each rotating ad owns its interval': () {
        final run = insertAdsIntoFeed(
            contentItems: List.generate(13, (i) => i),
            eligibleAds: [
              ad('a', frequency: 4),
              ad('b', frequency: 6),
              ad('c', frequency: 3)
            ]);
        var count = 0;
        final positions = <int>[];
        for (final entry in run) {
          if (entry.isAd) {
            positions.add(count);
          } else {
            count++;
          }
        }
        require(positions.join(',') == '4,10,13', 'one global frequency used');
      },
      'backend frequency one is not silently clamped': () {
        final run = insertAdsIntoFeed(
            contentItems: [1, 2], eligibleAds: [ad('a', frequency: 1)]);
        require(run.length == 4 && run[1].isAd && run[3].isAd,
            'frequency overridden');
      },
      'duplicate ad records do not duplicate slots': () {
        final run = insertAdsIntoFeed(
            contentItems: List.generate(8, (i) => i),
            eligibleAds: [ad('a'), ad('a'), ad('b')]);
        require(
            run
                    .where((entry) => entry.isAd)
                    .map((entry) => entry.ad!.id)
                    .join(',') ==
                'a,b',
            'duplicate ads stacked');
      },
      'wrong-zone ads and unsupported types are excluded': () {
        final run = insertAdsIntoFeed(
            contentItems: [1, 2, 3, 4],
            eligibleAds: [ad('a', zone: 'article'), ad('b', type: 'unknown')]);
        require(run.length == 4, 'wrong-zone or unsupported creative inserted');
        require(
            AdPlacement.canonical('spotlight') == 'feed' &&
                AdPlacement.canonical('article_detail') == 'article',
            'presentation aliases leaked to API');
      },
      'fullscreen and sticky ads keep their presentation semantics': () {
        final pool = [
          ad('s', type: 'bottom_sticky'),
          ad('f', type: 'full_screen')
        ];
        require(
            insertAdsIntoFeed(contentItems: [1, 2, 3, 4], eligibleAds: pool)
                    .length ==
                4,
            'overlay inserted inline');
        final spotlight = insertAdsIntoFeed(
            contentItems: [1, 2, 3, 4], eligibleAds: pool, allowTimed: true);
        require(spotlight.last.ad?.id == 'f',
            'fullscreen ad missing or sticky inserted as page');
      },
      'stable insertion keys survive rebuild and pagination': () {
        final initial = insertAdsIntoFeed(
            contentItems: [1, 2, 3, 4], eligibleAds: [ad('a')]);
        final expanded = insertAdsIntoFeed(
            contentItems: [1, 2, 3, 4, 5, 6, 7, 8], eligibleAds: [ad('a')]);
        require(initial.last.stableKey == expanded[4].stableKey,
            'existing exposure changed on pagination');
      },
      'article single image stays one parent': () {
        final value = story('a', ['image']);
        require(
            value.orderedMedia.length == 1 &&
                !value.orderedMedia.single.isVideo &&
                SpotlightItem.standard(value).type == SpotlightType.standard,
            'image article misclassified');
      },
      'article images preserve backend order including primary flag': () {
        final value = story('a', ['image', 'image', 'image']);
        require(value.orderedMedia.first.url.endsWith('a-0.jpg'),
            'media reordered by primary/sort flag');
        require(value.orderedMedia.length == 3, 'media missing');
        require(SpotlightItem.standard(value).type == SpotlightType.standard,
            'image count chose content type');
      },
      'article video and mixed media retain individual sources': () {
        final value = story('a', ['image', 'video', 'image', 'video']);
        require(
            value.orderedMedia.map((item) => item.isVideo ? 'v' : 'i').join() ==
                'iviv',
            'mixed ordering lost');
        require(value.orderedMedia[1].url != value.orderedMedia[3].url,
            'videos use one parent source');
        require(story('b', ['video']).orderedMedia.single.isVideo,
            'single video lost');
      },
      'UGC images videos and mixed media stay in one UGC parent': () {
        for (final media in [
          ['image', 'image'],
          ['video', 'video'],
          ['image', 'video', 'image']
        ]) {
          final value = story('u', media, kind: 'ugc');
          require(value.isUgc && value.orderedMedia.length == media.length,
              'UGC media lost');
          require(SpotlightItem.standard(value).type == SpotlightType.ugc,
              'UGC routed as article');
        }
      },
      'UGC projection adapter preserves its media payload': () {
        final value = UnifiedFeedItem.fromJson({
          'id': 'u',
          'type': 'ugc',
          'media_items': [
            {'media_type': 'image', 'url': 'https://example.com/a.jpg'},
            {'media_type': 'video', 'url': 'https://example.com/b.mp4'}
          ],
          'state': 'Example State',
          'district': 'Example District',
          'village': 'Example Village'
        }).toArticle();
        require(
            value.isUgc &&
                value.orderedMedia.length == 2 &&
                value.orderedMedia[1].isVideo,
            'adapter discarded UGC media');
        require(
            value.village == 'Example Village', 'adapter discarded location');
      },
      'article cache roundtrip retains every media entry': () {
        final value = story('a', ['image', 'video', 'image']);
        final restored = NewsArticle.fromJson(value.toJson());
        require(
            restored.orderedMedia.length == 3 &&
                restored.orderedMedia[1].url.endsWith('a-1.mp4'),
            'cache lost media');
      },
      'image_url is never a video source': () {
        final value = NewsArticle.fromJson({
          'id': 'a',
          'media_type': 'video',
          'image_url': 'https://example.com/a.jpg'
        });
        require(value.videoUrl.isEmpty, 'image used as video');
        require(
            ad('a', type: 'video').videoUrl.isEmpty, 'ad image used as video');
      },
      'video media_url supports query strings and HLS': () {
        final value = NewsArticle.fromJson({
          'id': 'u',
          'type': 'ugc',
          'media_url': 'https://example.com/live.m3u8?token=x'
        });
        require(
            value.videoUrl.endsWith('?token=x'), 'HLS media source missing');
      },
      'one poster with multiple images stays one Spotlight item': () {
        final value = SpotlightItem.posterRecord({
          'id': 'p',
          'images': [
            {'image_url': 'https://example.com/one.jpg'},
            {'image_url': 'https://example.com/two.jpg'}
          ]
        });
        require(
            value.type == SpotlightType.poster && value.imageUrls!.length == 2,
            'poster media lost');
      },
      'independent posters remain independent parent records': () {
        final posters = ['p1', 'p2', 'p3']
            .map((id) => SpotlightItem.posterRecord(
                {'id': id, 'image_url': 'https://example.com/$id.jpg'}))
            .toList();
        require(
            posters.length == 3 &&
                posters.map((item) => item.id).toSet().length == 3,
            'posters merged');
        final content = [
          SpotlightItem.standard(story('a', ['image'])),
          ...posters
        ];
        require(
            insertAdsIntoFeed(contentItems: content, eligibleAds: [ad('a')])
                .last
                .isAd,
            'poster not counted as parent');
      },
      'ad aspect ratios remain fixed by type': () {
        for (final entry in {
          'banner': 16 / 5,
          'box': 1.0,
          'three_d': 4 / 3,
          'video': 16 / 9,
          'poster': 4 / 5,
          'native': 16 / 9,
          'sponsored_card': 16 / 9
        }.entries) {
          require(AdTypeResolver.getFixedAspectRatio(entry.key) == entry.value,
              'ratio changed for ${entry.key}');
        }
        require(
            AdTypeResolver.getFixedHeight('bottom_sticky') == 64 &&
                AdTypeResolver.getFixedHeight('breaking_strip') == 42,
            'fixed height lost');
        require(ad('3d', type: 'three_d').toJson()['ad_type'] == 'three_d',
            'noncanonical enum sent');
      },
      'section cursors remain independent and clear on exhaustion': () {
        final village =
            FeedState<String>.success(items: ['v'], nextCursor: 'v2');
        final district =
            FeedState<String>.success(items: ['d'], nextCursor: 'd2');
        final exhausted = village.copyWith(clearCursor: true, hasMore: false);
        require(exhausted.nextCursor == null && district.nextCursor == 'd2',
            'section cursor mixed');
        require(FeedState<String>.initial().items.isEmpty,
            'new location retained prior content');
      },
      'empty content never generates ad-only feed': () {
        require(
            insertAdsIntoFeed(contentItems: <int>[], eligibleAds: [ad('a')])
                .isEmpty,
            'ad before any content');
      },
    };
