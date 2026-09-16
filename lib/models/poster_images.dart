import '../core/utils/url_normalizer.dart';

/// Every displayable image on a poster: the cover, then the gallery.
///
/// `totalImages = 1 + images.length` — the top-level `image_url` is itself a
/// design, not just a thumbnail, so it is slide 1 and `images[]` follows in
/// `sort_order`.
///
/// One parser for every surface (spotlight feed, gallery grid, detail view);
/// they each had their own and disagreed on order, normalisation and dupes.
List<String> posterImageUrls(Map<String, dynamic> json) {
  final urls = <String>[];
  final seen = <String>{};

  void add(Object? raw) {
    final url = UrlNormalizer.normalize(raw?.toString());
    // Exact repeats only: a poster whose cover is re-uploaded into images[]
    // has two different URLs and stays two slides, by design.
    if (url.isNotEmpty && seen.add(url)) urls.add(url);
  }

  add(json['image_url']);

  final raw = json['images'] ?? json['media_items'];
  if (raw is List) {
    final entries = raw.whereType<Object>().toList()
      ..sort((a, b) => posterSortOrder(a is Map ? a['sort_order'] : null)
          .compareTo(posterSortOrder(b is Map ? b['sort_order'] : null)));
    for (final image in entries) {
      add(image is Map
          ? (image['image_url'] ?? image['url'] ?? image['media_url'])
          : image);
    }
  }

  if (urls.isEmpty) add(json['thumbnail_url']);
  return urls;
}

/// `sort_order` arrives as an int or a numeric string; anything else sorts
/// first rather than throwing.
int posterSortOrder(Object? raw) {
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
