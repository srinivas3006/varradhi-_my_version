import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/news_article.dart';
import 'package:vaaradhi/models/spotlight_item.dart';
import 'package:vaaradhi/spotlight/spotlight_controller.dart';

SpotlightItem _story(String id, {String kind = 'article', int hour = 0}) =>
    SpotlightItem.standard(NewsArticle.fromJson({
      'id': id,
      'title': id,
      'feed_item_type': kind,
      'published_at': DateTime(2026, 10, 26, hour).toIso8601String(),
    }));

SpotlightItem _poster(String id) =>
    SpotlightItem(id: id, type: SpotlightType.poster);

List<String> _ids(List<SpotlightItem> f) => [for (final i in f) i.id];

/// Loading the next page must not move what is already on screen
/// (Spotlight blinked: the pre-loaded next card became another story).
void main() {
  test('cards already shown keep their places; new ones go to the end', () {
    final a = _story('a', hour: 10), b = _story('b', hour: 8);
    final p1 = _poster('poster-1');
    final shown = [a, b, p1, SpotlightItem.shimmer()];
    // Rebuilt from scratch: a newer citizen post sorts between a and b, and
    // the poster moves — the old behaviour.
    final u = _story('u', kind: 'ugc', hour: 9);
    final c = _story('c', hour: 3);
    final rebuilt = [a, u, b, c, p1];

    final merged = SpotlightController.appendOnly(shown, rebuilt);
    expect(_ids(merged).take(3), ['a', 'b', 'poster-1'],
        reason: 'nothing already shown moves');
    expect(_ids(merged).skip(3), ['u', 'c'], reason: 'new items appended');
  });

  test('no story twice, and the loading placeholder is dropped', () {
    final a = _story('a');
    final again = _story('a'); // same story, new object from the next page
    final merged = SpotlightController.appendOnly(
        [a, SpotlightItem.shimmer()], [again, _story('b')]);
    expect(_ids(merged), ['a', 'b']);
    expect(merged.where((i) => i.type == SpotlightType.shimmer), isEmpty);
  });
}
