import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/repositories/ad_repository.dart';

class _MockDioAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}

  static ResponseBody json(dynamic body, int status) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('AdRepository Tests', () {
    late Dio dio;
    late AdRepository repo;
    int requestCount = 0;

    setUp(() {
      requestCount = 0;
      dio = Dio(BaseOptions(baseUrl: 'https://api.varradhi.com'));
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        requestCount++;
        return _MockDioAdapter.json({
          'success': true,
          'data': [
            {
              'id': 'ad_1',
              'title': 'Test Promo',
              'image_url': 'https://example.com/banner.jpg',
              'destination_url': 'https://example.com',
              'ad_type': 'banner',
              'placement_zone': 'feed',
              'target_scope': 'global',
              'display_frequency': 5,
              'ctr': 1.0,
            }
          ]
        }, 200);
      });

      repo = AdRepository.test(dio: dio);
      repo.clearCache();
    });

    test('fetches ads with targeting parameters successfully', () async {
      final res = await repo.getAds(
        placementZone: 'feed',
        state: 'Telangana',
        district: 'Suryapet',
      );

      expect(res.isSuccess, isTrue);
      expect(res.data!.length, 1);
      expect(res.data!.first.id, 'ad_1');
      expect(requestCount, 1);
    });

    test('caches ads and satisfies subsequent requests from cache within TTL',
        () async {
      // First call -> hits network
      final first =
          await repo.getAds(placementZone: 'feed', state: 'Telangana');
      expect(first.isSuccess, isTrue);
      expect(requestCount, 1);

      // Second call -> returns from cache, does NOT hit network
      final second =
          await repo.getAds(placementZone: 'feed', state: 'Telangana');
      expect(second.isSuccess, isTrue);
      expect(second.data!.length, 1);
      expect(requestCount, 1);
    });

    test('forceRefresh bypasses cache and hits network', () async {
      await repo.getAds(placementZone: 'feed', state: 'Telangana');
      expect(requestCount, 1);

      await repo.getAds(
          placementZone: 'feed', state: 'Telangana', forceRefresh: true);
      expect(requestCount, 2);
    });

    test('clearCache invalidates cached entries', () async {
      await repo.getAds(placementZone: 'feed', state: 'Telangana');
      expect(requestCount, 1);

      repo.clearCache();

      await repo.getAds(placementZone: 'feed', state: 'Telangana');
      expect(requestCount, 2);
    });

    test('deduplicates concurrent in-flight requests', () async {
      // Fire two identical requests simultaneously
      final f1 = repo.getAds(placementZone: 'article', state: 'Telangana');
      final f2 = repo.getAds(placementZone: 'article', state: 'Telangana');

      final results = await Future.wait([f1, f2]);

      expect(results[0].isSuccess, isTrue);
      expect(results[1].isSuccess, isTrue);
      // Both futures resolved but only 1 network request was made
      expect(requestCount, 1);
    });

    test('handles network error safely and returns fallback data', () async {
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        return _MockDioAdapter.json({'detail': 'Server error'}, 500);
      });
      repo = AdRepository.test(dio: dio);

      final res = await repo.getAds(placementZone: 'search');

      expect(res.hasErrors, isTrue);
      expect(res.data, isEmpty);
    });
  });
}
