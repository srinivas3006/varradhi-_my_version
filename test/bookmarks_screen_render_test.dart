import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/screens/bookmarks_screen.dart';
import 'package:vaaradhi/screens/news_detail_screen.dart';
import 'package:vaaradhi/services/content_engagement_service.dart';
import 'package:vaaradhi/state/app_state.dart';
import 'package:vaaradhi/widgets/news_feed_card.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
          Future<void>? __) async =>
      handler(o);
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.resetBookmarksForTest();
  });

  tearDown(() => AppState.instance.isLoggedIn = false);

  testWidgets('saved stories are drawn, not a blank page', (tester) async {
    // Regression: NewsFeedCard splits its height with Expanded, and inside
    // the Saved screen's ListView it had no height to split. Layout failed
    // and the release APK showed an empty white screen over loaded items.
    AppState.instance.isLoggedIn = true;
    ApiClient.instance.dio.httpClientAdapter = _Adapter((o) => _json({
          'data': [
            {
              'id': 'bm-a',
              'feed_item_type': 'article',
              'content_id': 'art-1',
              'article': {
                'id': 'art-1',
                'title': 'Saved article headline',
                'slug': 'saved-article',
                'summary': 'Summary',
              },
              'ugc': null,
            },
            {
              'id': 'bm-u',
              'feed_item_type': 'ugc',
              'content_id': 'sub-1',
              'article': null,
              'ugc': {
                'id': 'sub-1',
                'type': 'ugc',
                'title': 'Saved citizen post',
                'description': 'Road damage',
              },
            },
          ],
          'meta': {'next': null},
          'errors': null,
        }, 200));

    await tester.pumpWidget(const MaterialApp(home: BookmarksScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull,
        reason: 'the cards must lay out inside the list');
    expect(find.byType(NewsFeedCard), findsWidgets);
    expect(find.text('Saved article headline'), findsOneWidget);
    final card = tester.getSize(find.byType(NewsFeedCard).first);
    expect(card.height, greaterThan(300));
  });


  testWidgets('tapping a saved story opens it', (tester) async {
    // Regression: only "Read More" opened the story, and it shows only when
    // the summary is cut off, so most saved cards could not be opened.
    AppState.instance.isLoggedIn = true;
    ApiClient.instance.dio.httpClientAdapter = _Adapter((o) {
      if (o.path.startsWith('/api/v1/bookmarks/')) {
        return _json({
          'data': [
            {
              'id': 'bm-a',
              'feed_item_type': 'article',
              'content_id': 'art-1',
              'article': {
                'id': 'art-1',
                'title': 'Open me',
                'slug': 'open-me',
              },
            },
          ],
          'meta': {'next': null},
        }, 200);
      }
      return _json({'data': null, 'errors': null}, 200);
    });

    await tester.pumpWidget(const MaterialApp(home: BookmarksScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Open me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NewsDetailScreen), findsOneWidget);
  });

  group('guests bookmark without logging in', () {
    NewsArticle story(String id, {bool ugc = false}) => NewsArticle.fromJson({
          'id': id,
          'slug': 'slug-$id',
          'title': 'Guest story $id',
          'feed_item_type': ugc ? 'ugc' : 'article',
        });

    test('a guest save stays on the phone and sends nothing', () async {
      AppState.instance.isLoggedIn = false;
      var requests = 0;
      ApiClient.instance.dio.httpClientAdapter = _Adapter((o) {
        requests++;
        return _json({}, 500);
      });

      final saved = await ContentEngagementService.instance
          .setBookmarked(story('g1'), nowBookmarked: true);
      expect(saved, isTrue);
      expect(requests, 0);
      expect(AppState.instance.isSavedOnDevice('g1'), isTrue);
      expect(AppState.instance.isStoryBookmarked(story('g1')), isTrue);

      await ContentEngagementService.instance
          .setBookmarked(story('g1'), nowBookmarked: false);
      expect(AppState.instance.isSavedOnDevice('g1'), isFalse);
      expect(AppState.instance.isStoryBookmarked(story('g1')), isFalse);
    });

    testWidgets('the Saved screen lists a guest\'s bookmarks', (tester) async {
      AppState.instance.isLoggedIn = false;
      await AppState.instance.saveStoryOnDevice(story('g2'));

      await tester.pumpWidget(const MaterialApp(home: BookmarksScreen()));
      await tester.pump();

      expect(find.text('Guest story g2'), findsOneWidget);
    });

    test('on login they are copied into the account and leave the phone',
        () async {
      AppState.instance.isLoggedIn = false;
      await AppState.instance.saveStoryOnDevice(story('art-new'));
      await AppState.instance.saveStoryOnDevice(story('art-had'));
      await AppState.instance.saveStoryOnDevice(story('sub-new', ugc: true));

      final calls = <String>[];
      ApiClient.instance.dio.httpClientAdapter = _Adapter((o) {
        calls.add('${o.method} ${o.path}');
        if (o.method == 'GET') {
          // The account already has art-had.
          return _json({
            'data': [
              {'id': 'bm1', 'feed_item_type': 'article',
                  'content_id': 'art-had', 'article': {'id': 'art-had'}},
            ],
            'meta': {'next': null},
          }, 200);
        }
        if (o.path.contains('/ugc/')) {
          return _json({'data': {'bookmarked': true}}, 201);
        }
        return _json({'data': {'id': 'bm2'}}, 201);
      });

      AppState.instance.isLoggedIn = true;
      await ContentEngagementService.instance.syncGuestBookmarks();

      expect(calls, contains('POST /api/v1/bookmarks/'));
      expect(calls, contains('POST /api/v1/ugc/sub-new/bookmark/toggle/'));
      expect(calls.where((c) => c.contains('toggle')).length, 1,
          reason: 'never toggle something the account already has');
      expect(calls.where((c) => c == 'POST /api/v1/bookmarks/').length, 1,
          reason: 'art-had is already in the account');
      expect(AppState.instance.deviceSavedStories, isEmpty);
      for (final id in ['art-new', 'art-had', 'sub-new']) {
        expect(AppState.instance.isBookmarked(id), isTrue, reason: id);
      }
    });

    test('a failed copy keeps the bookmark on the phone for next time',
        () async {
      AppState.instance.isLoggedIn = false;
      await AppState.instance.saveStoryOnDevice(story('art-x'));
      ApiClient.instance.dio.httpClientAdapter = _Adapter((o) =>
          o.method == 'GET'
              ? _json({'data': [], 'meta': {'next': null}}, 200)
              : _json({'errors': {'message': 'down'}}, 503));

      AppState.instance.isLoggedIn = true;
      await ContentEngagementService.instance.syncGuestBookmarks();
      expect(AppState.instance.isSavedOnDevice('art-x'), isTrue);
    });
  });
}
