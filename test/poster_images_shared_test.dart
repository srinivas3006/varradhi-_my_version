import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/poster_images.dart';
import 'package:way2news_clone/models/spotlight_item.dart';

/// Verbatim from GET /api/v1/posters/ — cover and gallery entry differ.
const _real = {
  'id': '2b34de4f-c14a-4093-a76e-ffd788da019e',
  'title': 'ఉపాధ్యాయ దినోత్సవం',
  'image_url':
      'https://d397c5ueqnsgjy.cloudfront.net/posters/2026/09/WhatsApp_Image_2026-09-05_at_2.56.03_PM.jpeg',
  'thumbnail_url': '',
  'images': [
    {
      'image_url':
          'https://d397c5ueqnsgjy.cloudfront.net/posters/2026/09/WhatsApp_Image_2026-09-05_at_2.56.03_PM_y0ATOMl.jpeg',
      'sort_order': 1,
    },
  ],
};

void main() {
  test('totalImages = 1 + images.length', () {
    final urls = posterImageUrls(Map.from(_real));
    expect(urls, hasLength(2));
    expect(urls[0], endsWith('2.56.03_PM.jpeg'), reason: 'cover is slide 1');
    expect(urls[1], endsWith('_y0ATOMl.jpeg'));
  });

  test('the feed shows the same 2 slides, counter reads 1/2', () {
    final page = SpotlightItem.posterPages(Map.from(_real)).single;
    expect(page.imageUrls, posterImageUrls(Map.from(_real)));
    expect(page.posterPageCount, 2);
  });

  test('gallery follows the cover in sort_order', () {
    final urls = posterImageUrls({
      'id': 'p',
      'image_url': 'https://cdn.example.com/cover.jpg',
      'images': [
        {'image_url': 'https://cdn.example.com/c.jpg', 'sort_order': 3},
        {'image_url': 'https://cdn.example.com/a.jpg', 'sort_order': 1},
        {'image_url': 'https://cdn.example.com/b.jpg', 'sort_order': '2'},
      ],
    });
    expect(urls.map((u) => u.split('/').last),
        ['cover.jpg', 'a.jpg', 'b.jpg', 'c.jpg']);
  });

  test('an exact repeat is still one slide', () {
    final urls = posterImageUrls({
      'id': 'p',
      'image_url': 'https://cdn.example.com/same.jpg',
      'images': [
        {'image_url': 'https://cdn.example.com/same.jpg', 'sort_order': 1},
      ],
    });
    expect(urls, hasLength(1));
  });

  test('cover-only poster is one slide, no counter', () {
    final urls = posterImageUrls(
        {'id': 'p', 'image_url': 'https://cdn.example.com/only.jpg'});
    expect(urls, hasLength(1));
  });

  test('empty cover falls back to thumbnail_url', () {
    final urls = posterImageUrls({
      'id': 'p',
      'image_url': '',
      'thumbnail_url': 'https://cdn.example.com/thumb.jpg',
    });
    expect(urls.single, endsWith('thumb.jpg'));
  });

  test('nothing usable yields nothing', () {
    expect(posterImageUrls({'id': 'p', 'images': []}), isEmpty);
  });
}
