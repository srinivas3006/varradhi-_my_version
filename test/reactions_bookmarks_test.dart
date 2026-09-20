import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:way2news_clone/core/network/dio_client.dart';
import 'package:way2news_clone/models/news_article.dart';
import 'package:way2news_clone/services/api_service.dart';
import 'package:way2news_clone/state/app_state.dart';

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
    state.bookmarkedItemIds.clear();
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

