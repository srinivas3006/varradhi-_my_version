import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/repositories/home_feed_repository.dart';

/// The hero is built only from the /feed/home/ response — no separate
/// live, breaking or featured requests.
final _now = DateTime(2026, 10, 1, 12);

NewsArticle _story(
  String id, {
  String type = 'article',
  bool breaking = false,
  bool featured = false,
  double ageDays = 0,
}) =>
    NewsArticle.fromJson({
      'id': id,
      'title': 'Story $id',
      'type': type,
      'published_at': _now
          .subtract(Duration(minutes: (ageDays * 24 * 60).round()))
          .toIso8601String(),
      'metadata': {
        'slug': 'slug-$id',
        'is_breaking': breaking,
        'is_featured': featured,
      },
    });

List<String> _hero(List<NewsArticle> personalized, List<NewsArticle> local,
        {List<NewsArticle> latest = const []}) =>
    homeHeroStories(personalized, local, latest: latest, now: _now)
        .map((a) => a.id)
        .toList();

void main() {
  group('hero from the Home response', () {
    test('live first, then recent breaking, then recent featured', () {
      expect(
        _hero([
          _story('f1', featured: true, ageDays: 1),
          _story('b1', breaking: true, ageDays: 0.5),
          _story('plain', ageDays: 2),
        ], [
          _story('live1', type: 'live'),
          _story('b2', breaking: true, ageDays: 1),
        ]),
        ['live1', 'b1', 'b2', 'f1', 'plain'],
      );
    });

    test('an old "breaking" story no longer leads Home', () {
      // Regression: 9–11-day-old breaking stories filled the hero.
      expect(
        _hero([
          _story('oldBreaking', breaking: true, ageDays: 10),
          _story('today', ageDays: 0.1),
        ], const []),
        ['today', 'oldBreaking'],
        reason: 'it may still fill a slot, by date, after newer news',
      );
    });

    test('the hero is topped up with the newest stories, Latest included',
        () {
      expect(
        _hero(
          [_story('p-old', ageDays: 9), _story('p-mid', ageDays: 4)],
          const [],
          latest: [
            _story('test1', ageDays: 0.03),
            _story('l-old', ageDays: 12),
            _story('l-new', ageDays: 1),
          ],
        ),
        ['test1', 'l-new', 'p-mid', 'p-old', 'l-old'],
      );
    });

    test('is_breaking / is_featured are read from metadata', () {
      expect(_story('x', breaking: true).isBreaking, isTrue);
      expect(_story('y', featured: true).isFeatured, isTrue);
    });

    test('a story that is breaking and featured appears once', () {
      expect(_hero([_story('a1', breaking: true, featured: true)], const []),
          ['a1']);
    });

    test('the same story in both sections appears once', () {
      expect(
          _hero([_story('a1', breaking: true)], [_story('a1', breaking: true)]),
          hasLength(1));
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
      // A citizen post is not hero-eligible as breaking; it only fills a
      // slot by date.
      expect(_hero([_story('u1', type: 'ugc', breaking: true)], const []),
          ['u1']);
    });

    test('the badge is only for recent stories', () {
      expect(homeIsRecent(_story('a', ageDays: 2), now: _now), isTrue);
      expect(homeIsRecent(_story('b', ageDays: 10), now: _now), isFalse);
    });

    test('an empty Home gives an empty hero', () {
      expect(homeHeroStories(const [], const [], now: _now), isEmpty);
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
