import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/news_article.dart';

/// The shape the live feed actually returns, verified against
/// GET /api/v1/articles/feed/ — singular *_count names, my_reaction,
/// is_bookmarked.
Map<String, dynamic> _liveShape({
  int like = 0,
  int dislike = 0,
  int comment = 0,
  int view = 0,
  String? reaction,
  bool bookmarked = false,
}) =>
    {
      'id': 'a1',
      'title': 'T',
      'like_count': like,
      'dislike_count': dislike,
      'comment_count': comment,
      'view_count': view,
      'my_reaction': reaction,
      'is_bookmarked': bookmarked,
    };

void main() {
  group('counts parse from the names the backend actually sends', () {
    // Regression: the model read likes_count / comments_count, but the API
    // sends like_count / comment_count. Only dislike_count was listed, which
    // is why a dislike showed its number while likes and comments read 0.
    test('like_count reaches the model', () {
      expect(NewsArticle.fromJson(_liveShape(like: 42)).likes, 42);
    });

    test('comment_count reaches the model', () {
      expect(NewsArticle.fromJson(_liveShape(comment: 7)).comments, 7);
    });

    test('dislike_count still works', () {
      expect(NewsArticle.fromJson(_liveShape(dislike: 1)).dislikes, 1);
    });

    test('view_count still works', () {
      expect(NewsArticle.fromJson(_liveShape(view: 99)).viewCount, 99);
    });

    test('a full payload parses every count at once', () {
      final a = NewsArticle.fromJson(
          _liveShape(like: 5, dislike: 2, comment: 3, view: 10));
      expect([a.likes, a.dislikes, a.comments, a.viewCount], [5, 2, 3, 10]);
    });
  });

  group('plural spellings still work, for older endpoints', () {
    test('likes_count is accepted as a fallback', () {
      expect(
        NewsArticle.fromJson({'id': '1', 'title': 'T', 'likes_count': 8}).likes,
        8,
      );
    });

    test('comments_count is accepted as a fallback', () {
      expect(
        NewsArticle.fromJson({'id': '1', 'title': 'T', 'comments_count': 4})
            .comments,
        4,
      );
    });

    test('the singular name wins when both are present', () {
      final a = NewsArticle.fromJson(
          {'id': '1', 'title': 'T', 'like_count': 9, 'likes_count': 1});
      expect(a.likes, 9);
    });
  });

  group('reaction and bookmark state read the live keys', () {
    test('my_reaction like marks the article liked', () {
      final a = NewsArticle.fromJson(_liveShape(reaction: 'like'));
      expect(a.isLiked, isTrue);
      expect(a.isDisliked, isFalse);
    });

    test('my_reaction dislike marks it disliked', () {
      final a = NewsArticle.fromJson(_liveShape(reaction: 'dislike'));
      expect(a.isDisliked, isTrue);
      expect(a.isLiked, isFalse);
    });

    test('a null reaction is neutral', () {
      final a = NewsArticle.fromJson(_liveShape());
      expect(a.isLiked, isFalse);
      expect(a.isDisliked, isFalse);
    });

    test('is_bookmarked is honoured', () {
      expect(NewsArticle.fromJson(_liveShape(bookmarked: true)).isBookmarked,
          isTrue);
      expect(NewsArticle.fromJson(_liveShape()).isBookmarked, isFalse);
    });
  });

  group('missing counts degrade to zero, not to a crash', () {
    test('an empty payload parses', () {
      final a = NewsArticle.fromJson({'id': '1', 'title': 'T'});
      expect([a.likes, a.dislikes, a.comments], [0, 0, 0]);
    });

    test('string counts are coerced', () {
      final a = NewsArticle.fromJson(
          {'id': '1', 'title': 'T', 'like_count': '12'});
      expect(a.likes, 12);
    });
  });
}
