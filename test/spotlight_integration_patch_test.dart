import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/models/spotlight_item.dart';
import 'package:way2news_clone/repositories/feed_repository.dart';
import 'package:way2news_clone/spotlight/spotlight_controller.dart';
import 'package:way2news_clone/state/app_state.dart';

class _FeedAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<void>? oldRequest;
  Completer<void>? oldStarted;
  bool mixed = false;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    requests.add(options);
    final district = options.queryParameters['district'];
    var data = <Map<String, dynamic>>[];
    if (options.path.contains('/articles/feed/')) {
      if (district == 'Old' && oldRequest != null) {
        if (!oldStarted!.isCompleted) oldStarted!.complete();
        await oldRequest!.future;
      }
      data = [
        {
          'id': 'article-$district',
          'title': 'Article $district',
          'district': district,
          'published_at': '2026-09-14T12:00:00Z',
          'media_items': [
            {'media_type': 'image', 'url': 'https://example.com/1.jpg'},
            {'media_type': 'video', 'url': 'https://example.com/2.mp4'},
            {'media_type': 'image', 'url': 'https://example.com/3.jpg'},
          ],
        }
      ];
    } else if (mixed && options.path.contains('/ugc/feed/')) {
      data = [
        {
          'id': 'ugc-1',
          'title': 'Citizen report',
          'content_type': 'ugc',
          'media_items': [
            {'media_type': 'image', 'url': 'https://example.com/ugc.jpg'},
            {'media_type': 'video', 'url': 'https://example.com/ugc.mp4'},
          ]
        }
      ];
    } else if (mixed && options.path.contains('/posters/')) {
      data = [
        for (final id in ['poster-a', 'poster-b'])
          {
            'id': id,
            'images': [
              'https://example.com/$id.jpg',
              'https://example.com/$id-2.jpg'
            ]
          }
      ];
    } else if (mixed && options.path.endsWith('/ads/')) {
      data = [
        {
          'id': 'ad-a',
          'ad_type': 'banner',
          'placement_zone': 'feed',
          'display_frequency': 4,
          'image_url': 'https://example.com/ad.jpg'
        }
      ];
    }
    return ResponseBody.fromString(
        jsonEncode({'data': data, 'meta': {}, 'errors': null}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClientAdapter previous;
  late _FeedAdapter adapter;
  setUp(() {
    // The first-run news-language sheet is onboarding, not the
    // behaviour under test here.
    AppState.instance.contentLanguagePrompted = true;
    previous = ApiClient.instance.dio.httpClientAdapter;
    adapter = _FeedAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
    FeedRepository.instance.clearCache();
    AppState.instance.district = 'Selected';
  });
  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = previous;
  });

  test(
      'Spotlight composes four parents and one ad without splitting mixed media',
      () async {
    adapter.mixed = true;
    final controller = SpotlightController();
    addTearDown(controller.dispose);
    await controller.loadFeed();
    final items = controller.state.feed;
    expect(items.map((item) => item.type), [
      SpotlightType.standard,
      SpotlightType.ugc,
      SpotlightType.poster,
      SpotlightType.poster,
      SpotlightType.ad
    ]);
    expect(items.first.article!.orderedMedia.length, 3);
    expect(items[1].article!.orderedMedia.length, 2);
    expect(items[2].imageUrls!.length, 2);
    expect(items[3].id, 'poster-b');
    final adRequest =
        adapter.requests.singleWhere((r) => r.path.endsWith('/ads/'));
    expect(adRequest.queryParameters['zone'], 'feed');
    expect(adRequest.queryParameters['district'], 'Selected');
  });

  test(
      'location switch clears content and rejects a late old-location response',
      () async {
    AppState.instance.district = 'Old';
    adapter.oldRequest = Completer<void>();
    adapter.oldStarted = Completer<void>();
    final controller = SpotlightController();
    addTearDown(controller.dispose);
    final oldLoad = controller.loadFeed();
    await adapter.oldStarted!.future;
    AppState.instance.district = 'New';
    final newLoad = controller.updateLocation();
    expect(controller.state.feed, isEmpty);
    await newLoad;
    expect(controller.state.feed.single.article!.id, 'article-New');
    adapter.oldRequest!.complete();
    await oldLoad;
    expect(controller.state.feed.single.article!.id, 'article-New');
  });
}
