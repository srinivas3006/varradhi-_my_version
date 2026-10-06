import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/repositories/news_article_repository.dart';

/// The detail endpoint, whose story gains a second image after the admin
/// edits it.
class _Detail implements HttpClientAdapter {
  int images = 1;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
      Future<void>? __) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'id': '619aa543',
          'title': 'test1',
          'slug': 'test1',
          'media_items': [
            for (var i = 0; i < images; i++)
              {
                'media_type': 'image',
                'url': 'https://cdn.test/$i.jpg',
                'thumbnail_url': 'https://cdn.test/$i.jpg',
                'sort_order': i,
              },
          ],
        },
        'meta': {},
        'errors': null,
      }),
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

  late _Detail api;
  late DateTime clock;
  final repo = NewsArticleRepository.instance;

  setUp(() {
    api = _Detail();
    ApiClient.instance.dio.httpClientAdapter = api;
    repo.clearCache();
    clock = DateTime(2026, 10, 1, 12, 0);
    repo.now = () => clock;
  });
  tearDown(() => repo.now = DateTime.now);

  test('an image the admin adds later shows up — not kept for the session',
      () async {
    final first = await repo.getDetail('test1');
    expect(first.orderedMedia, hasLength(1));

    api.images = 2; // the admin adds a second image
    clock = clock.add(NewsArticleRepository.cacheTtl);
    final later = await repo.getDetail('test1');
    expect(later.orderedMedia, hasLength(2));
  });

  test('within the reuse window it is not refetched', () async {
    await repo.getDetail('test1');
    clock = clock.add(const Duration(seconds: 30));
    await repo.getDetail('test1');
    expect(api.calls, 1);
  });

  test('clearing (Spotlight refresh) fetches it fresh', () async {
    await repo.getDetail('test1');
    api.images = 2;
    repo.clearCache();
    final fresh = await repo.getDetail('test1');
    expect(fresh.orderedMedia, hasLength(2));
    expect(api.calls, 2);
  });

  test('a two-image story becomes a two-page carousel', () {
    final a = NewsArticle.fromJson({
      'id': '619aa543',
      'title': 'test1',
      'media_type': 'image',
      'thumbnail_url': 'https://cdn.test/0.jpg',
      'media_items': [
        {'media_type': 'image', 'url': 'https://cdn.test/0.jpg', 'sort_order': 0},
        {'media_type': 'image', 'url': 'https://cdn.test/1.jpg', 'sort_order': 1},
      ],
    });
    // SpotlightNewsCard uses the swipeable ArticleMediaCarousel whenever
    // orderedMedia has more than one item.
    expect(a.orderedMedia.map((m) => m.url),
        ['https://cdn.test/0.jpg', 'https://cdn.test/1.jpg']);
  });
}
