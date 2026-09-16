import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/spotlight_item.dart';

Map<String, dynamic> _poster(String id, List<String> urls) => {
      'id': id,
      'title': 'Poster $id',
      'images': [for (final u in urls) {'image_url': u}],
    };

void main() {
  group('a poster is one page carrying all its designs', () {
    test('a three-image poster is a single page, not three feed items', () {
      final pages = SpotlightItem.posterPages(
          _poster('p1', ['a.jpg', 'b.jpg', 'c.jpg']));
      expect(pages, hasLength(1),
          reason: 'splitting them made one poster read as three unrelated items');
    });

    test('every image is kept, so the carousel has something to page through', () {
      final pages = SpotlightItem.posterPages(
          _poster('p2', ['a.jpg', 'b.jpg', 'c.jpg']));
      final urls = pages.single.imageUrls!;
      expect(urls, hasLength(3));
      expect(urls[0], endsWith('a.jpg'));
      expect(urls[1], endsWith('b.jpg'));
      expect(urls[2], endsWith('c.jpg'));
    });

    test('the count drives the "1/3" counter and the dots', () {
      final pages = SpotlightItem.posterPages(
          _poster('p3', ['a.jpg', 'b.jpg', 'c.jpg']));
      expect(pages.single.posterPageCount, 3);
      expect(pages.single.posterPageIndex, 1);
    });

    test('mediaUrl is the first design, for share and preview', () {
      final pages =
          SpotlightItem.posterPages(_poster('p4', ['first.jpg', 'second.jpg']));
      expect(pages.single.mediaUrl, endsWith('first.jpg'));
    });

    test('a single-image poster shows no counter', () {
      final pages = SpotlightItem.posterPages(_poster('p5', ['only.jpg']));
      expect(pages.single.posterPageCount, 1);
      expect(pages.single.imageUrls, hasLength(1));
    });

    test('the id is preserved, so feed dedupe still works', () {
      final pages = SpotlightItem.posterPages(_poster('p6', ['a.jpg', 'b.jpg']));
      expect(pages.single.id, 'p6');
      expect(pages.single.type, SpotlightType.poster);
      expect(pages.single.title, 'Poster p6');
    });

    test('a record with no usable image yields no pages', () {
      expect(SpotlightItem.posterPages({'id': 'p7', 'images': []}), isEmpty);
      expect(SpotlightItem.posterPages({'id': '', 'images': []}), isEmpty);
    });

    test('falls back to a flat image_url payload', () {
      final pages =
          SpotlightItem.posterPages({'id': 'p8', 'image_url': 'flat.jpg'});
      expect(pages, hasLength(1));
      expect(pages.single.mediaUrl, endsWith('flat.jpg'));
    });
  });
}
