import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/repositories/home_feed_repository.dart';

/// The hero is built only from the /feed/home/ response — no separate
/// live, breaking or featured requests.
NewsArticle _story(
  String id, {
  String type = 'article',
  bool breaking = false,
  bool featured = false,
}) =>
    NewsArticle.fromJson({
      'id': id,
      'title': 'Story $id',
      'type': type,
      'metadata': {
        'slug': 'slug-$id',
        'is_breaking': breaking,
        'is_featured': featured,
      },
    });

void main() {
  group('hero from the Home response', () {
    test('live first, then breaking, then featured', () {
      final hero = homeHeroStories([
        _story('f1', featured: true),
        _story('b1', breaking: true),
        _story('plain'),
      ], [
        _story('live1', type: 'live'),
        _story('b2', breaking: true),
      ]);
      expect(hero.map((a) => a.id), ['live1', 'b1', 'b2', 'f1']);
    });

    test('is_breaking / is_featured are read from metadata', () {
      expect(_story('x', breaking: true).isBreaking, isTrue);
      expect(_story('y', featured: true).isFeatured, isTrue);
    });

    test('a story that is breaking and featured appears once', () {
      final hero = homeHeroStories(
          [_story('a1', breaking: true, featured: true)], const []);
      expect(hero.map((a) => a.id), ['a1']);
    });

    test('the same story in both sections appears once', () {
      final hero = homeHeroStories(
          [_story('a1', breaking: true)], [_story('a1', breaking: true)]);
      expect(hero, hasLength(1));
    });

    test('dedupe is by kind:id — an article and a citizen post may share ids',
        () {
      final article = _story('same', type: 'article');
      final post = _story('same', type: 'ugc');
      expect(homeStoryKey(article), 'article:same');
      expect(homeStoryKey(post), 'ugc:same');
      expect(homeStoryKey(article), isNot(homeStoryKey(post)));
    });

    test('only articles count as breaking or featured', () {
      final hero = homeHeroStories(
          [_story('u1', type: 'ugc', breaking: true)], const []);
      // Not breaking-eligible, so the fallback applies.
      expect(hero.map((a) => a.id), ['u1']);
    });

    test('with none of those, the first five personalized stories', () {
      final personalized =
          List.generate(8, (i) => _story('p$i'));
      final hero = homeHeroStories(personalized, [_story('near')]);
      expect(hero.map((a) => a.id), ['p0', 'p1', 'p2', 'p3', 'p4']);
    });

    test('an empty Home gives an empty hero', () {
      expect(homeHeroStories(const [], const []), isEmpty);
    });
  });

  group('For You rail', () {
    final now = DateTime(2026, 10, 1, 12);
    NewsArticle aged(String id, double days, {String type = 'article'}) =>
        NewsArticle.fromJson({
          'id': id,
          'title': 'Story $id',
          'type': type,
          'published_at': now
              .subtract(Duration(minutes: (days * 24 * 60).round()))
              .toIso8601String(),
        });

    test('newest first, whatever order the server ranked them in', () {
      final rail = homeForYouStories(
          [aged('old', 11), aged('new', 8.4), aged('mid', 9.3)], const [],
          now: now);
      expect(rail.map((a) => a.id), ['new', 'mid', 'old']);
    });

    test('once there is fresh news, old stories drop out', () {
      final rail = homeForYouStories([
        aged('stale1', 10),
        aged('f1', 0.2),
        aged('stale2', 12),
        aged('f2', 1),
        aged('f3', 2),
        aged('f4', 2.5),
      ], const [], now: now);
      expect(rail.map((a) => a.id), ['f1', 'f2', 'f3', 'f4']);
    });

    test('with too little fresh news, all of it — never an empty rail', () {
      final rail = homeForYouStories(
          [aged('f1', 0.5), aged('old', 10)], const [],
          now: now);
      expect(rail.map((a) => a.id), ['f1', 'old']);
    });

    test('live streams and hero stories are not repeated in the rail', () {
      final live = aged('live1', 1, type: 'live');
      final heroStory = aged('h1', 1);
      final rail = homeForYouStories(
          [live, heroStory, aged('a1', 2)], [live, heroStory],
          now: now);
      expect(rail.map((a) => a.id), ['a1']);
    });
  });
}
