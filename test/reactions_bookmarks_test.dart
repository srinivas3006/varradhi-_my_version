import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaaradhi/core/network/dio_client.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/services/api_service.dart';
import 'package:vaaradhi/services/content_engagement_service.dart';
import 'package:vaaradhi/state/app_state.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
          Future<void>? __) =>
      handler(o);
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = AppState.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state.likedItemIds.clear();
    state.dislikedItemIds.clear();
    state.resetBookmarksForTest();
    // Server calls are for accounts; a guest's bookmarks stay on the phone.
    state.isLoggedIn = true;
  });

  tearDown(() => state.isLoggedIn = false);

  group('every screen agrees on one bookmark state', () {
    NewsArticle story({bool bookmarked = false}) => NewsArticle.fromJson(
        {'id': 'a1', 'slug': 's1', 'is_bookmarked': bookmarked});

    test('the server flag counts until the reader decides', () {
      expect(state.isStoryBookmarked(story(bookmarked: true)), isTrue);
      expect(state.isStoryBookmarked(story()), isFalse);
    });

    test('removing a bookmark wins over a stale copy that says saved', () {
      // Regression: screens OR-ed their own copy's is_bookmarked with the
      // shared state, so a bookmark removed on one screen still showed as
      // saved on any screen holding an older copy of the story.
      final staleCopy = story(bookmarked: true);
      state.setBookmarked('a1', false);
      expect(state.isStoryBookmarked(staleCopy), isFalse);
    });

    test('adding a bookmark wins over a stale copy that says not saved', () {
      final staleCopy = story();
      state.setBookmarked('a1', true);
      expect(state.isStoryBookmarked(staleCopy), isTrue);
    });

    test('logging out forgets the account\'s bookmarks', () {
      // Regression: only citizen-post bookmarks were cleared, so the next
      // account on the phone saw the previous account's saved articles.
      final src = File('lib/state/app_state.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('_clearLocalSession() async'));
      final body = fn.substring(0, fn.indexOf('\n  }\n'));
      expect(body, contains('bookmarkedItemIds.clear();'));
      expect(body, contains('_bookmarkDecisions.clear();'));
    });

    test('there is one name for it, and no leftover duplicate calls', () {
      final api = File('lib/services/api_service.dart').readAsStringSync();
      expect(api, isNot(contains('removeBookmark(')));
      final engagement =
          File('lib/services/content_engagement_service.dart')
              .readAsStringSync();
      expect(engagement, isNot(contains('setSaved(')));
    });

    test('the Saved screen deletes server rows by bookmark id', () {
      final screen =
          File('lib/screens/bookmarks_screen.dart').readAsStringSync();
      expect(screen, contains('deleteBookmark(item.id)'));
      // Phone copies are only a guest's bookmarks now, never an account's.
      expect(screen, contains('if (!item.onDevice)'));
    });

    test('a story with only a slug is keyed by its slug', () {
      final slugOnly = NewsArticle.fromJson({'slug': 's9'});
      expect(AppState.bookmarkKey(slugOnly), 's9');
      state.setBookmarked('s9', true);
      expect(state.isStoryBookmarked(slugOnly), isTrue);
    });
  });

  void serve(Future<ResponseBody> Function(RequestOptions) h) {
    ApiClient.instance.dio.httpClientAdapter = _Adapter(h);
  }

  group('backend reaction state reaches the model', () {
    test('a previously liked article parses as liked', () {
      final a = NewsArticle.fromJson({'id': '1', 'is_liked_by_user': true});
      expect(a.isLiked, isTrue);
      expect(a.isDisliked, isFalse);
    });

    test('a previously disliked article parses as disliked', () {
      // Regression: there was no isDisliked field at all, so a dislike the
      // backend reported had nowhere to land and the button stayed blank.
      final a = NewsArticle.fromJson({'id': '1', 'my_reaction': 'dislike'});
      expect(a.isDisliked, isTrue);
      expect(a.isLiked, isFalse);
    });

    test('reaction_type and is_disliked_by_user are both honoured', () {
      expect(
        NewsArticle.fromJson({'id': '1', 'reaction_type': 'dislike'})
            .isDisliked,
        isTrue,
      );
      expect(
        NewsArticle.fromJson({'id': '1', 'is_disliked_by_user': true})
            .isDisliked,
        isTrue,
      );
    });

    test('a previously bookmarked article parses as bookmarked', () {
      final a =
          NewsArticle.fromJson({'id': '1', 'is_bookmarked_by_user': true});
      expect(a.isBookmarked, isTrue);
    });

    test('an untouched article is neutral', () {
      final a = NewsArticle.fromJson({'id': '1'});
      expect(a.isLiked, isFalse);
      expect(a.isDisliked, isFalse);
      expect(a.isBookmarked, isFalse);
    });
  });

  group('like and dislike are mutually exclusive', () {
    test('liking clears an existing dislike', () {
      state.setReaction('a1', 'dislike');
      expect(state.isDisliked('a1'), isTrue);
      state.setReaction('a1', 'like');
      expect(state.isLiked('a1'), isTrue);
      expect(state.isDisliked('a1'), isFalse,
          reason: 'a reader cannot show both at once');
    });

    test('disliking clears an existing like', () {
      state.setReaction('a1', 'like');
      state.setReaction('a1', 'dislike');
      expect(state.isDisliked('a1'), isTrue);
      expect(state.isLiked('a1'), isFalse);
    });

    test('none clears both', () {
      state.setReaction('a1', 'like');
      state.setReaction('a1', 'none');
      expect(state.isLiked('a1'), isFalse);
      expect(state.isDisliked('a1'), isFalse);
      expect(state.getReaction('a1'), 'none');
    });
  });

  group('the reaction request matches the backend contract', () {
    test('like sends PUT with reaction_type', () async {
      String? method, path;
      Object? body;
      serve((o) async {
        method = o.method;
        path = o.path;
        body = o.data;
        return _json({'data': {'like_count': 5}}, 200);
      });

      final res = await ApiService.instance.postArticleReaction('a1', 'like');
      expect(method, 'PUT');
      expect(path, '/api/v1/articles/a1/reaction/');
      expect(body, {'reaction_type': 'like'});
      expect(res['like_count'], 5);
    });

    test('dislike sends PUT with reaction_type dislike', () async {
      Object? body;
      serve((o) async {
        body = o.data;
        return _json({'data': {'like_count': 2}}, 200);
      });
      await ApiService.instance.postArticleReaction('a1', 'dislike');
      expect(body, {'reaction_type': 'dislike'});
    });

    test('removing a reaction sends DELETE, not a PUT of "none"', () async {
      String? method, path;
      serve((o) async {
        method = o.method;
        path = o.path;
        return _json({'data': {'like_count': 4}}, 200);
      });
      await ApiService.instance.postArticleReaction('a1', 'none');
      expect(method, 'DELETE');
      expect(path, '/api/v1/articles/a1/reaction/');
    });

    test('the server count is returned rather than inferred', () async {
      serve((o) async => _json({'data': {'like_count': 42}}, 200));
      final res = await ApiService.instance.postArticleReaction('a1', 'like');
      expect(res['like_count'], 42,
          reason: 'the UI must render the authoritative count');
    });

    test('a failed reaction surfaces instead of being swallowed', () async {
      serve((o) async => _json({'errors': {'message': 'nope'}}, 500));
      expect(
        () => ApiService.instance.postArticleReaction('a1', 'like'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('bookmark contract', () {
    test('toggle posts article_id to the toggle endpoint', () async {
      String? method, path;
      Object? body;
      serve((o) async {
        method = o.method;
        path = o.path;
        body = o.data;
        return _json({'data': {'bookmarked': true}}, 200);
      });

      await ApiService.instance.toggleBookmark('a1');
      expect(method, 'POST');
      expect(path, '/api/v1/bookmarks/toggle/');
      expect(body, {'article_id': 'a1'});
    });

    test('toggle returns the server state, not the hoped-for one', () async {
      serve((o) async => _json({'data': {'bookmarked': false}}, 200));
      expect(await ApiService.instance.toggleBookmark('a1'), isFalse);
    });

    test('saving uses the safe add endpoint, never the toggle (§3)', () async {
      // The toggle turned a save into an unsave whenever the server already
      // held the bookmark. POST /bookmarks/ can only ever add.
      final calls = <String>[];
      Object? body;
      serve((o) async {
        calls.add('${o.method} ${o.path}');
        body = o.data;
        return _json({
          'data': {'id': 'bm1', 'message': 'Bookmarked successfully.'}
        }, 201);
      });
      final story = NewsArticle.fromJson({'id': 'a2', 'title': 't'});
      expect(
          await ContentEngagementService.instance
              .setBookmarked(story, nowBookmarked: true),
          isTrue);
      expect(calls, ['POST /api/v1/bookmarks/']);
      expect(body, {'article_id': 'a2'});
    });

    test('saving an article already saved still ends saved (200)', () async {
      serve((o) async => _json(
          {'data': {'message': 'Article already bookmarked.'}}, 200));
      final story = NewsArticle.fromJson({'id': 'a2', 'title': 't'});
      expect(
          await ContentEngagementService.instance
              .setBookmarked(story, nowBookmarked: true),
          isTrue);
    });

    test('unsaving uses the toggle and follows data.bookmarked (§2)', () async {
      final calls = <String>[];
      serve((o) async {
        calls.add('${o.method} ${o.path}');
        return _json({
          'data': {'bookmarked': false, 'message': 'Bookmark removed.'}
        }, 200);
      });
      final story = NewsArticle.fromJson({'id': 'a1', 'title': 't'});
      expect(
          await ContentEngagementService.instance
              .setBookmarked(story, nowBookmarked: false),
          isFalse);
      expect(calls, ['POST /api/v1/bookmarks/toggle/']);
    });

    test('a failed save is sent once, never retried', () async {
      var calls = 0;
      serve((o) async {
        calls++;
        return _json({'errors': {'message': 'down'}}, 503);
      });
      final story = NewsArticle.fromJson({'id': 'a1', 'title': 't'});
      expect(
          await ContentEngagementService.instance
              .setBookmarked(story, nowBookmarked: true),
          isNull);
      expect(calls, 1);
    });

    test('a failed toggle throws so the caller can roll back', () async {
      serve((o) async => _json({'errors': {'message': 'nope'}}, 500));
      expect(
        () => ApiService.instance.toggleBookmark('a1'),
        throwsA(isA<DioException>()),
      );
    });

    test('local toggle flips and survives a rebuild of the set', () {
      expect(state.isBookmarked('a1'), isFalse);
      state.toggleBookmark('a1');
      expect(state.isBookmarked('a1'), isTrue);
      state.toggleBookmark('a1');
      expect(state.isBookmarked('a1'), isFalse);
    });

    test('getBookmarks parses standard DRF results envelope with nested article', () async {
      serve((o) async {
        return _json({
          'count': 1,
          'next': null,
          'results': [
            {
              'id': 'bm_1',
              'article': {
                'id': 'art_1',
                'title': 'Saved Article 1',
                'slug': 'saved-article-1',
              },
            }
          ]
        }, 200);
      });

      final items = await ApiService.instance.getBookmarks();
      expect(items.length, 1);
      expect(items.first.id, 'bm_1');
      expect(items.first.story.id, 'art_1');
      expect(items.first.story.title, 'Saved Article 1');
      expect(items.first.story.isBookmarked, isTrue);
    });

    test('the combined list parses articles and citizen posts (§5)',
        () async {
      serve((o) async => _json({
            'data': [
              {
                'id': 'bm-a',
                'feed_item_type': 'article',
                'content_id': 'art-9',
                'article': {
                  'id': 'art-9',
                  'title': 'Article title',
                  'slug': 'article-title',
                },
                'ugc': null,
                'created_at': '2026-09-30T11:00:00+05:30',
              },
              {
                'id': 'bm-u',
                'feed_item_type': 'ugc',
                'content_id': 'sub-9',
                'article': null,
                'ugc': {
                  'id': 'sub-9',
                  'type': 'ugc',
                  'title': 'Road damage near Kesaram',
                  'description': 'Citizen report description',
                  'thumbnail_url': 'https://cdn.example.com/ugc.jpg',
                  'is_bookmarked': true,
                },
                'created_at': '2026-09-30T10:30:00+05:30',
              },
            ],
            'meta': {'count': 2, 'next': null, 'previous': null},
            'errors': null,
          }, 200));

      final items = await ApiService.instance.getBookmarks();
      expect(items.map((i) => i.id), ['bm-a', 'bm-u']);

      final article = items[0];
      expect(article.isUgc, isFalse);
      expect(article.contentId, 'art-9');
      expect(article.story.slug, 'article-title');

      // Regression: a citizen row has article: null, and was parsed from the
      // bookmark row itself — a blank card carrying the bookmark's id.
      final ugc = items[1];
      expect(ugc.isUgc, isTrue);
      expect(ugc.contentId, 'sub-9');
      expect(ugc.story.id, 'sub-9');
      expect(ugc.story.isUgc, isTrue);
      expect(ugc.story.title, 'Road damage near Kesaram');
      expect(ugc.story.summary, 'Citizen report description');
    });

    test('pages follow meta.next exactly and de-duplicate by bookmark id (§6)',
        () async {
      final requested = <String>[];
      serve((o) async {
        requested.add(o.uri.toString());
        if (o.uri.queryParameters['cursor'] == 'p2') {
          return _json({
            'data': [
              {'id': 'bm1', 'feed_item_type': 'article', 'content_id': 'a1',
                  'article': {'id': 'a1', 'title': 'one'}},
              {'id': 'bm2', 'feed_item_type': 'article', 'content_id': 'a2',
                  'article': {'id': 'a2', 'title': 'two'}},
            ],
            'meta': {'next': null},
          }, 200);
        }
        return _json({
          'data': [
            {'id': 'bm1', 'feed_item_type': 'article', 'content_id': 'a1',
                'article': {'id': 'a1', 'title': 'one'}},
          ],
          'meta': {
            'next':
                'https://api.vaaradhinews.com/api/v1/bookmarks/?cursor=p2&page_size=20'
          },
        }, 200);
      });

      final items = await ApiService.instance.getBookmarks();
      expect(items.map((i) => i.id), ['bm1', 'bm2']);
      expect(requested.last,
          'https://api.vaaradhinews.com/api/v1/bookmarks/?cursor=p2&page_size=20');
      expect(requested.first, contains('page_size=20'));
      expect(requested.first, isNot(contains('page=')));
    });

    test('delete uses the bookmark id; 204 is success, 404 already gone (§7)',
        () async {
      String? path;
      serve((o) async {
        path = o.path;
        return ResponseBody.fromString('', 204);
      });
      expect(await ApiService.instance.deleteBookmark('bm-u'), isTrue);
      expect(path, '/api/v1/bookmarks/bm-u/');

      serve((o) async => _json({
            'data': null,
            'errors': {'code': 404, 'message': 'Bookmark not found.'},
          }, 404));
      expect(await ApiService.instance.deleteBookmark('bm-x'), isFalse);
    });

    test('getBookmarks parses wrapped data envelope and preserves bookmarked flag', () async {
      serve((o) async {
        return _json({
          'data': [
            {
              'id': 'bm_2',
              'article': {
                'id': 'art_2',
                'title': 'Saved Article 2',
              },
            }
          ]
        }, 200);
      });

      final items = await ApiService.instance.getBookmarks();
      expect(items.length, 1);
      expect(items.first.story.id, 'art_2');
      expect(items.first.story.isBookmarked, isTrue);
    });
  });

  group('feed and detail read the same state', () {
    test('model field OR local set is what both screens render', () {
      // The card and the detail screen both read
      // `article.isX || AppState.isX(id)`. Either source alone was the bug:
      // the set ignored the backend, the field ignored the current session.
      final fromBackend = NewsArticle.fromJson({
        'id': 'a1',
        'is_liked_by_user': true,
        'is_bookmarked_by_user': true,
      });
      expect(fromBackend.isLiked || state.isLiked('a1'), isTrue);
      expect(fromBackend.isBookmarked || state.isBookmarked('a1'), isTrue);

      final fresh = NewsArticle.fromJson({'id': 'a2'});
      state.setReaction('a2', 'like');
      expect(fresh.isLiked || state.isLiked('a2'), isTrue,
          reason: 'a like made this session shows even though the feed '
              'payload predates it');
    });
  });

  group('article dislike counts & mutual exclusivity contract', () {
    test('NewsArticle parses and mutates dislike count', () {
      final article = NewsArticle.fromJson({
        'id': 'a10',
        'title': 'Test',
        'likes_count': 10,
        'dislike_count': 4,
        'is_liked': false,
        'is_disliked': false,
      });

      expect(article.likes, 10);
      expect(article.dislikes, 4);

      // Mutate optimistically
      article.dislikes++;
      expect(article.dislikes, 5);

      article.dislikes--;
      expect(article.dislikes, 4);
    });

    test('mutual exclusivity: dislike increments dislikes and decrements likes if previously liked', () {
      final article = NewsArticle.fromJson({
        'id': 'a11',
        'likes_count': 5,
        'dislike_count': 2,
        'is_liked': true,
        'is_disliked': false,
      });

      // User taps dislike:
      final wasLiked = article.isLiked;
      article.isLiked = false;
      article.isDisliked = true;
      if (wasLiked) {
        article.likes = (article.likes - 1).clamp(0, 100000);
      }
      article.dislikes = article.dislikes + 1;

      expect(article.likes, 4);
      expect(article.dislikes, 3);
      expect(article.isLiked, isFalse);
      expect(article.isDisliked, isTrue);
    });

    test('mutual exclusivity: like increments likes and decrements dislikes if previously disliked', () {
      final article = NewsArticle.fromJson({
        'id': 'a12',
        'likes_count': 8,
        'dislike_count': 3,
        'is_liked': false,
        'is_disliked': true,
      });

      // User taps like:
      final wasDisliked = article.isDisliked;
      article.isDisliked = false;
      article.isLiked = true;
      if (wasDisliked) {
        article.dislikes = (article.dislikes - 1).clamp(0, 100000);
      }
      article.likes = article.likes + 1;

      expect(article.likes, 9);
      expect(article.dislikes, 2);
      expect(article.isLiked, isTrue);
      expect(article.isDisliked, isFalse);
    });

    test('server response updates both like_count and dislike_count', () async {
      serve((o) async => _json({
        'data': {
          'like_count': 15,
          'dislike_count': 7,
        }
      }, 200));

      final res = await ApiService.instance.postArticleReaction('a1', 'dislike');
      expect(res['like_count'], 15);
      expect(res['dislike_count'], 7);
    });
  });
}

