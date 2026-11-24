import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/core/widgets/flip_page_view.dart';
import 'package:vaaradhi/repositories/feed_repository.dart';
import 'package:vaaradhi/repositories/news_article_repository.dart';
import 'package:vaaradhi/repositories/top_stories_repository.dart';
import 'package:vaaradhi/services/analytics_queue.dart';
import 'package:vaaradhi/spotlight/spotlight_screen.dart';
import 'package:vaaradhi/spotlight/top_stories_controller.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/article_media_carousel.dart';
import 'package:vaaradhi/widgets/spotlight/spotlight_news_card.dart';

const articleId = '11111111-2222-3333-4444-555555555555';
const submissionId = '22222222-3333-4444-5555-666666666666';
const articlePath = '/api/v1/articles/top-article/';
const ugcPath = '/api/v1/ugc/$submissionId/';

Map<String, dynamic> article({bool editorial = false}) => {
      'id': articleId,
      'type': 'article',
      'title': 'Top article',
      'summary': '',
      'view_count': 0,
      'metadata': {
        'slug': 'top-article',
        'is_top_story': editorial,
        'top_story_reason': editorial ? 'editorial' : 'popular_recent',
        'top_story_score': 123,
      },
    };

const ugc = {
  'id': 'feed-id',
  'type': 'ugc',
  'title': 'Citizen story',
  'summary': 'Citizen summary',
  'metadata': {'source_id': submissionId},
};

ResponseBody response(Object data, {int status = 200, String? retryAfter}) =>
    ResponseBody.fromString(
        jsonEncode({'data': data, 'meta': {}, 'errors': null}), status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          if (retryAfter != null) 'retry-after': [retryAfter],
        });

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = 'English';
    NewsArticleRepository.instance.clearCache();
    FeedRepository.instance.clearCache();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (_) async => 1,
    );
  });

  test(
      'filters omit placeholders and guest defaults; canonical keys isolate location, language and reader',
      () {
    final app = AppState.instance;
    final wasValid = app.hasValidLocation;
    app.hasValidLocation = false;
    addTearDown(() => app.hasValidLocation = wasValid);
    expect(TopStoriesQuery.fromApp(app).parameters.keys, ['lang', 'limit']);
    final query = TopStoriesQuery(
        lang: ' TE ',
        state: ' Telangana ',
        district: 'unknown',
        city: 'Any',
        subdistrict: 'null',
        village: ' ');
    expect(
        query.parameters, {'lang': 'te', 'limit': '10', 'state': 'Telangana'});
    expect(TopStoriesQuery(lang: 'te', state: 'TELANGANA').cacheKey,
        query.cacheKey);
    expect(TopStoriesQuery(lang: 'en', state: 'Telangana').cacheKey,
        isNot(query.cacheKey));
    expect(TopStoriesQuery(lang: 'te', state: 'Andhra Pradesh').cacheKey,
        isNot(query.cacheKey));
    expect(
        TopStoriesQuery(lang: 'te', state: 'Telangana', viewer: 'member')
            .cacheKey,
        isNot(query.cacheKey));
  });

  test(
      'mixed feed preserves order, source IDs, editorial labels and zero views',
      () {
    final items = TopStoriesRepository.parse([
      article(editorial: true),
      {'type': 'video'},
      ugc,
      {...article(), 'id': 'fallback'},
    ]);
    expect(items.map((item) => item.id), [articleId, submissionId, 'fallback']);
    expect(
        items.map((item) => item.isEditorialHighlight), [true, false, false]);
    expect(items.first.article!.slug, 'top-article');
    expect(items.first.article!.viewCount, 0);
    expect(items.first.article!.summary, isEmpty);
    expect(AnalyticsQueue.contentIdOf(items.first.article!)?.key, 'article_id');
    expect(AnalyticsQueue.contentIdOf(items[1].article!)?.key, 'submission_id');
  });

  test(
      'manual refresh replaces ranking, follows editorial expiry and clears empty cache',
      () async {
    var payload = <Object>[article(editorial: true), ugc];
    final adapter = TestAdapter((_) => response(payload));
    final repo = TopStoriesRepository(dio: Dio()..httpClientAdapter = adapter);
    final controller = TopStoriesController(repository: repo);
    addTearDown(controller.dispose);
    final query = TopStoriesQuery(lang: 'te');
    await controller.show(query);
    expect(controller.stories.first.isEditorialHighlight, isTrue);
    payload = [ugc, article()];
    await controller.refresh();
    await controller.refresh();
    expect(
        controller.stories.map((item) => item.id), [submissionId, articleId]);
    expect(
        controller.stories.any((item) => item.isEditorialHighlight), isFalse);
    payload = [];
    await controller.refresh();
    expect(controller.stories, isEmpty);
    expect(controller.failure, isNull);
    expect(await repo.cached(query), isEmpty);
    expect(
        adapter.requests.every((r) =>
            r.path == TopStoriesRepository.endpoint &&
            r.queryParameters.length == 2),
        isTrue);
  });

  test('pending results cannot cross changes of language or saved district',
      () async {
    final oldPending = Completer<ResponseBody>();
    final oldStarted = Completer<void>();
    final adapter = TestAdapter((options) {
      if (options.queryParameters['lang'] == 'te') {
        oldStarted.complete();
        return oldPending.future;
      }
      return response([ugc]);
    });
    final repo = TopStoriesRepository(dio: Dio()..httpClientAdapter = adapter);
    final controller = TopStoriesController(repository: repo);
    addTearDown(controller.dispose);
    final old = TopStoriesQuery(lang: 'te', district: 'Hyderabad');
    final current = TopStoriesQuery(lang: 'en', district: 'Guntur');
    final request = controller.show(old);
    await oldStarted.future;
    await controller.show(current);
    oldPending.complete(response([article()]));
    await request;
    expect(controller.stories.single.id, submissionId);
    expect(await repo.cached(old), isEmpty);
    expect(await repo.cached(current), hasLength(1));
    expect(
        await repo.cached(TopStoriesQuery(lang: 'en', district: 'Hyderabad')),
        isEmpty);
  });

  test(
      'validation details are surfaced and unchanged parameters are never retried',
      () async {
    final adapter = TestAdapter((_) => ResponseBody.fromString(
            jsonEncode({
              'data': null,
              'errors': {
                'details': {
                  'district': ['Invalid district.']
                }
              },
            }),
            400,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            }));
    final controller = TopStoriesController(
        repository:
            TopStoriesRepository(dio: Dio()..httpClientAdapter = adapter));
    addTearDown(controller.dispose);
    final query = TopStoriesQuery(lang: 'all', district: 'Invalid');
    await controller.show(query);
    expect(controller.failure?.details, ['district: Invalid district.']);
    await controller.refresh();
    controller.close();
    await controller.show(query);
    expect(adapter.requests, hasLength(1));
  });

  test(
      'Retry-After is respected; offline and server errors retain only matching cache',
      () async {
    var time = DateTime.utc(2026, 11, 21);
    var status = 200;
    final adapter = TestAdapter((options) {
      if (status == 0) {
        throw DioException(
            requestOptions: options, type: DioExceptionType.connectionError);
      }
      return response([ugc],
          status: status, retryAfter: status == 429 ? '75' : null);
    });
    final repo = TopStoriesRepository(
        dio: Dio()..httpClientAdapter = adapter, now: () => time);
    final controller = TopStoriesController(repository: repo);
    addTearDown(controller.dispose);
    final query = TopStoriesQuery(lang: 'te', city: 'Hyderabad');
    await controller.show(query);
    status = 429;
    await controller.refresh();
    await controller.refresh();
    final reopened = TopStoriesController(repository: repo);
    addTearDown(reopened.dispose);
    await reopened.show(query);
    expect(reopened.failure?.status, 429);
    expect(adapter.requests, hasLength(2));
    expect(controller.stories.single.id, submissionId);
    time = time.add(const Duration(seconds: 75));
    status = 503;
    await controller.refresh();
    expect(controller.failure?.status, 503);
    expect(controller.stories.single.id, submissionId);
    controller.close();
    status = 0;
    await controller.show(query);
    expect(controller.failure?.offline, isTrue);
    expect(controller.stories.single.id, submissionId);
    await controller.show(TopStoriesQuery(lang: 'te', city: 'Guntur'));
    expect(controller.failure?.offline, isTrue);
    expect(controller.stories, isEmpty);
  });

  testWidgets('Top Stories empty state restores the previous Spotlight page',
      (tester) async {
    final app = AppState.instance;
    final prompted = app.contentLanguagePrompted;
    app.contentLanguagePrompted = true;
    addTearDown(() => app.contentLanguagePrompted = prompted);
    final api = TestAdapter((options) => response(
          options.path == '/api/v1/posters/'
              ? [
                  for (final id in ['one', 'two', 'three'])
                    {'id': id, 'image_url': 'https://example.test/$id.jpg'},
                ]
              : [],
        ));
    ApiClient.instance.dio.httpClientAdapter = api;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: SpotlightScreenView(initialStoryIndex: 1)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final normal = tester.widget<FlipPageView>(find.byType(FlipPageView));
    expect(normal.controller.page, 1);
    await tester.tapAt(const Offset(195, 420));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('spotlight_top_stories')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('No Top Stories right now.'), findsOneWidget);
    await tester.tap(find.text('Back to Spotlight'));
    await tester.pump();
    expect(find.text('No Top Stories right now.'), findsNothing);
    final restored = tester.widget<FlipPageView>(find.byType(FlipPageView));
    expect(restored.controller, same(normal.controller));
    expect(restored.controller.page, 1);
    expect(api.requests.where((r) => r.path == TopStoriesRepository.endpoint),
        hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'empty article summary and Citizen News use detail IDs and render full media',
      (tester) async {
    final api = TestAdapter((options) {
      final isUgc = options.path == ugcPath;
      return response({
        'id': isUgc ? submissionId : articleId,
        'slug': 'top-article',
        'title': isUgc ? 'Citizen story' : 'Top article',
        'summary': isUgc ? 'FULL CITIZEN TEXT' : '',
        'content': 'FULL ARTICLE TEXT',
        'media_items': [
          {'media_type': 'image', 'url': 'https://example.test/one.jpg'},
          {'media_type': 'image', 'url': 'https://example.test/two.jpg'},
        ],
      });
    });
    ApiClient.instance.dio.httpClientAdapter = api;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final stories = TopStoriesRepository.parse([article(editorial: true), ugc]);
    for (final item in stories) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SpotlightNewsCard(
        key: ValueKey(item.id),
        article: item.article!,
        topStoriesScope: 'te',
        isEditorialHighlight: item.isEditorialHighlight,
        onTap: () {},
        onShare: () {},
        onClose: () {},
      ))));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
          find.textContaining(
              item.article!.isUgc ? 'FULL CITIZEN TEXT' : 'FULL ARTICLE TEXT',
              findRichText: true),
          findsWidgets);
      expect(find.text("Editor's Pick"),
          item.isEditorialHighlight ? findsOneWidget : findsNothing);
      expect(find.byType(ArticleMediaCarousel), findsOneWidget);
    }
    expect(api.requests.map((r) => r.path), [articlePath, ugcPath]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
