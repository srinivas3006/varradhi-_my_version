import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/state/engagement_store.dart';

void main() {
  final store = EngagementStore.instance;
  setUp(store.reset);

  group('keys', () {
    test('an article and a UGC post with the same id do not collide', () {
      final a = EngagementStore.keyFor(kind: 'article', id: '7');
      final u = EngagementStore.keyFor(kind: 'ugc', id: '7');
      expect(a, isNot(u));
    });
  });

  group('seeding', () {
    test('server counts land', () {
      const k = 'article:1';
      store.seed(k, likeCount: 10, dislikeCount: 2, commentCount: 5);
      expect(store.stateFor(k).likeCount, 10);
      expect(store.stateFor(k).dislikeCount, 2);
      expect(store.stateFor(k).commentCount, 5);
    });

    test('a later feed payload does not undo the reader\'s own tap', () {
      const k = 'article:2';
      store.seed(k, likeCount: 10);
      store.seed(k, reaction: Reaction.like, likeCount: 11);
      // A stale feed response carrying only counts arrives afterwards.
      store.seed(k, likeCount: 11);
      expect(store.stateFor(k).liked, isTrue,
          reason: 'reaction must survive a counts-only seed');
    });
  });

  group('server reconcile', () {
    test('both spellings of the count fields are accepted', () {
      const k = 'article:3';
      store.applyServerCounts(k, {'like_count': 11, 'dislike_count': 1});
      expect(store.stateFor(k).likeCount, 11);
      expect(store.stateFor(k).dislikeCount, 1);

      store.applyServerCounts(k, {'likes_count': 20, 'comments_count': 4});
      expect(store.stateFor(k).likeCount, 20);
      expect(store.stateFor(k).commentCount, 4);
    });

    test('numeric strings are parsed', () {
      const k = 'article:4';
      store.applyServerCounts(k, {'like_count': '9'});
      expect(store.stateFor(k).likeCount, 9);
    });

    test('a response with no counts leaves the entry alone', () {
      const k = 'article:5';
      store.seed(k, likeCount: 3);
      store.applyServerCounts(k, {'status': 'ok'});
      expect(store.stateFor(k).likeCount, 3);
    });
  });

  group('listeners', () {
    test('only the affected item notifies', () {
      const a = 'article:6';
      const b = 'article:7';
      var aNotified = 0;
      var bNotified = 0;
      store.listenableFor(a).addListener(() => aNotified++);
      store.listenableFor(b).addListener(() => bNotified++);

      store.seed(a, likeCount: 1);

      expect(aNotified, 1);
      expect(bNotified, 0, reason: 'an unrelated card must not rebuild');
    });
  });

  group('counts never go negative', () {
    test('clamped at zero', () {
      const k = 'article:8';
      store.seed(k, likeCount: 0, commentCount: 0);
      store.bumpCommentCount(k, -5);
      expect(store.stateFor(k).commentCount, 0);
    });

    test('comment count moves without refetching the feed', () {
      const k = 'article:9';
      store.seed(k, commentCount: 4);
      store.bumpCommentCount(k, 1);
      expect(store.stateFor(k).commentCount, 5);
    });
  });
}
