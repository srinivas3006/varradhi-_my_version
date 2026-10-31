import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/ads/ad_insertion.dart';
import 'package:vaaradhi/core/ads/ad_placement.dart';
import 'package:vaaradhi/core/ads/zone_ads.dart';
import 'package:vaaradhi/models/ad_banner.dart';
import 'package:vaaradhi/models/video_item.dart';
import 'package:vaaradhi/repositories/ad_repository.dart';
import 'package:vaaradhi/screens/shorts_viewer_screen.dart';

AdBanner ad(String id, String zone, {String type = 'banner', int freq = 1}) =>
    AdBanner.fromJson({
      'id': id,
      'image_url': 'https://cdn.example.com/$id.jpg',
      'destination_url': 'https://example.com',
      'ad_type': type,
      'placement_zone': zone,
      'display_frequency': freq,
    });

class _AdsAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  List<Map<String, dynamic>> data = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'data': data, 'meta': {}, 'errors': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('zone names', () {
    test('the five new zones are sent exactly as named', () {
      for (final z in [
        'home_top',
        'category',
        'ugc_feed',
        'video_feed',
        'article_end',
      ]) {
        expect(AdPlacement.canonical(z), z);
      }
    });

    test('old aliases still translate as before', () {
      expect(AdPlacement.canonical('article_detail'), 'article');
      expect(AdPlacement.canonical('article_bottom'), 'article');
      expect(AdPlacement.canonical('category_feed'), 'feed');
      for (final z in ['feed', 'article', 'splash', 'search']) {
        expect(AdPlacement.canonical(z), z);
      }
    });

    test('each zone takes only its formats', () {
      bool ok(String zone, String type) =>
          AdPlacement.supports(zone, ad('a', zone, type: type));
      expect(ok('home_top', 'breaking_strip'), isTrue);
      expect(ok('home_top', 'native'), isFalse);
      expect(ok('category', 'video'), isTrue);
      expect(ok('category', 'poster'), isFalse);
      expect(ok('ugc_feed', 'native'), isTrue);
      expect(ok('ugc_feed', 'video'), isFalse);
      expect(ok('video_feed', 'video'), isTrue);
      expect(ok('video_feed', 'box'), isFalse);
      expect(ok('article_end', 'box'), isTrue);
      expect(ok('article_end', 'video'), isFalse);
      expect(ok('category', 'something_new'), isFalse,
          reason: 'unknown ad_type is skipped, not crashed on');
    });
  });

  group('request', () {
    test('placement_zone only, and only that zone\'s ads come back', () async {
      final adapter = _AdsAdapter()
        ..data = [
          {
            'id': 'u1',
            'ad_type': 'native',
            'placement_zone': 'ugc_feed',
            'image_url': 'https://cdn.example.com/u1.jpg',
          },
          {
            'id': 'f1',
            'ad_type': 'banner',
            'placement_zone': 'feed',
            'image_url': 'https://cdn.example.com/f1.jpg',
          },
        ];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter;
      final res = await AdRepository.test(dio: dio)
          .getAds(placementZone: 'ugc_feed', forceRefresh: true);
      final q = adapter.requests.single.queryParameters;
      expect(q['placement_zone'], 'ugc_feed');
      expect(q.containsKey('zone'), isFalse);
      expect(res.data!.map((a) => a.id), ['u1']);
    });

    test('an empty zone gives no ad, nothing from another zone', () async {
      ZoneAds.loader = (_) async => [ad('f', 'feed')];
      addTearDown(() => ZoneAds.loader = (_) async => const []);
      expect(await ZoneAds.load('category'), isEmpty);
    });
  });

  group('frequency', () {
    test('category: 6 apart, none in the first 3, never twice in a row', () {
      final slots = adSlotsAfter<int>(
        contentItems: List.generate(30, (i) => i),
        eligibleAds: [ad('a', 'category'), ad('b', 'category')],
        placementZone: 'category',
        policy: AdFrequencyPolicy.category,
      );
      final positions = slots.keys.toList()..sort();
      expect(positions.first, greaterThanOrEqualTo(5));
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i] - positions[i - 1], greaterThanOrEqualTo(6));
        expect(slots[positions[i]]!.id,
            isNot(slots[positions[i - 1]]!.id));
      }
      expect(slots.length, lessThanOrEqualTo(4));
    });

    test('ugc_feed: at least 5 posts apart', () {
      final slots = adSlotsAfter<int>(
        contentItems: List.generate(20, (i) => i),
        eligibleAds: [ad('a', 'ugc_feed', type: 'native')],
        placementZone: 'ugc_feed',
        policy: AdFrequencyPolicy.ugcFeed,
      );
      final positions = slots.keys.toList()..sort();
      expect(positions, isNotEmpty);
      expect(positions.first, 4, reason: 'after the 5th post');
    });

    test('the only eligible ad may appear again when there is no other', () {
      final slots = adSlotsAfter<int>(
        contentItems: List.generate(30, (i) => i),
        eligibleAds: [ad('only', 'category')],
        placementZone: 'category',
        policy: AdFrequencyPolicy.category,
      );
      expect(slots.length, greaterThan(1));
      expect(slots.values.every((a) => a.id == 'only'), isTrue);
    });

    test('home fallback is only the existing breaking strip', () {
      final home = File('lib/screens/news_feed_tab.dart').readAsStringSync();
      expect(home,
          contains('_breakingStripAds => HomeAds.breakingStrip(_feedAds)'));
      final strip = home.substring(home.indexOf('if (_homeTopAd != null)'));
      expect(strip.substring(0, 600),
          contains('else if (_breakingStripAds.isNotEmpty)'));
      final homeAds = File('lib/core/ads/home_ads.dart').readAsStringSync();
      expect(homeAds,
          contains('ads.where((ad) => ad.isBreakingStrip).toList()'));
    });

    test('a feed-zone ad never lands in a new zone', () {
      final slots = adSlotsAfter<int>(
        contentItems: List.generate(20, (i) => i),
        eligibleAds: [ad('f', 'feed')],
        placementZone: 'category',
        policy: AdFrequencyPolicy.category,
      );
      expect(slots, isEmpty);
    });
  });

  testWidgets('video_feed: an ad page after 8 Shorts, Skip moves on',
      (t) async {
    ZoneAds.loader = (_) async => [ad('v', 'video_feed')];
    addTearDown(() => ZoneAds.loader = (_) async => const []);
    final shorts = List.generate(
      12,
      (i) => VideoItem.fromJson({
        'id': 's$i',
        'title': 'Short $i',
        'video_url': '',
        'thumbnail_url': '',
      }),
    );
    await t.pumpWidget(MaterialApp(
      home: ShortsViewerScreen(shorts: shorts, isActive: false),
    ));
    await t.pump();
    final pager = t.widget<PageView>(find.byType(PageView));
    final delegate = pager.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 13, reason: '12 Shorts + 1 ad page');
  });

  test('screens use the new zones, article_end after the story', () {
    String read(String p) => File(p).readAsStringSync();
    expect(read('lib/screens/category_screen.dart'),
        contains('AdPlacement.category'));
    expect(read('lib/screens/category_screen.dart'),
        isNot(contains("'category_feed'")));
    expect(read('lib/screens/ugc_feed_screen.dart'),
        contains('AdPlacement.ugcFeed'));
    expect(read('lib/screens/shorts_viewer_screen.dart'),
        contains('AdPlacement.videoFeed'));
    expect(read('lib/features/reels/reels_screen.dart'),
        contains('AdPlacement.videoFeed'));
    expect(read('lib/screens/news_feed_tab.dart'),
        contains('AdPlacement.homeTop'));
    final detail = read('lib/screens/news_detail_screen.dart');
    expect(detail, contains('AdPlacement.articleEnd'));
    expect(detail, isNot(contains("'article_bottom'")));
  });
}
