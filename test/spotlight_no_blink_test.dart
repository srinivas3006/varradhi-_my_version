import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/repositories/news_article_repository.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

const _summary = 'FEED SUMMARY ONLY';
const _body = 'THE FULL STORY TEXT FROM THE DETAIL API';

class _Detail implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    if (o.path.startsWith('/api/v1/articles/story-1')) calls++;
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'id': '11111111-2222-3333-4444-555555555555',
          'slug': 'story-1',
          'title': 'Headline',
          'summary': _summary,
          'content': _body,
          'published_at': '2026-10-26T10:00:00+05:30',
        }
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

NewsArticle _feedCopy() => NewsArticle.fromJson({
      'id': '11111111-2222-3333-4444-555555555555',
      'slug': 'story-1',
      'title': 'Headline',
      'summary': _summary, // the feed carries no body
      'published_at': '2026-10-26T10:00:00+05:30',
    });

/// Spotlight blink while swiping: a card drew the feed summary, then the
/// full story a frame later.
void main() {
  late _Detail api;
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = 'Telugu';
    NewsArticleRepository.instance.clearCache();
    api = _Detail();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  test('peek is synchronous; prefetch fills the cache once', () async {
    final repo = NewsArticleRepository.instance;
    expect(repo.peekDetail('story-1'), isNull);
    repo.prefetchDetail('story-1');
    repo.prefetchDetail('story-1'); // in flight: no second request
    await Future<void>.delayed(Duration.zero);
    await repo.getDetail('story-1');
    expect(api.calls, 1);
    expect(repo.peekDetail('story-1')!.body, contains(_body));
    expect(repo.isFresh('story-1'), isTrue);
    repo.prefetchDetail('story-1'); // fresh: nothing
    expect(api.calls, 1);
  });

  testWidgets('a cached story is drawn complete in its first frame',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Prefetched while the reader was on the previous card.
    await tester.runAsync(
        () => NewsArticleRepository.instance.getDetail('story-1'));
    final before = api.calls;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpotlightNewsCard(
          article: _feedCopy(),
          onTap: () {},
          onShare: () {},
          onClose: () {},
        ),
      ),
    ));
    // First frame: the full story, never the summary.
    expect(find.textContaining('THE FULL STORY', findRichText: true),
        findsWidgets);
    expect(find.textContaining(_summary, findRichText: true), findsNothing);
    expect(api.calls, before, reason: 'fresh cache: no refetch');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
