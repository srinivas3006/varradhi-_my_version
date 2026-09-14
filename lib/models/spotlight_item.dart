import 'news_article.dart';
import '../core/utils/url_normalizer.dart';
import 'ad_banner.dart';

enum SpotlightType {
  standard,
  ugc,
  carousel,
  promo,
  ad,
  poster,
  infoCard,
  shimmer,
}

class SpotlightItem {
  final String id;
  final SpotlightType type;

  // For standard news
  final NewsArticle? article;

  // For carousel news
  final List<String>? imageUrls;
  final String? title;

  // For promo / poster / infoCard / ad
  final String? promoImageUrl;
  final String? mediaUrl;
  final AdBanner? adBanner;

  const SpotlightItem({
    required this.id,
    required this.type,
    this.article,
    this.imageUrls,
    this.title,
    this.promoImageUrl,
    this.mediaUrl,
    this.adBanner,
  });

  factory SpotlightItem.standard(NewsArticle article) {
    return SpotlightItem(
      id: article.id,
      type: article.isUgc ? SpotlightType.ugc : SpotlightType.standard,
      article: article,
    );
  }

  factory SpotlightItem.carousel({
    required String id,
    required List<String> imageUrls,
    required String title,
    required NewsArticle baseArticle, // to share/comment on
  }) {
    return SpotlightItem(
      id: id,
      type: SpotlightType.carousel,
      imageUrls: imageUrls,
      title: title,
      article: baseArticle,
    );
  }

  factory SpotlightItem.promo({
    required String id,
    required String imageUrl,
  }) {
    return SpotlightItem(
      id: id,
      type: SpotlightType.promo,
      promoImageUrl: imageUrl,
    );
  }

  factory SpotlightItem.poster(String id, String mediaUrl) {
    return SpotlightItem(
      id: id,
      type: SpotlightType.poster,
      mediaUrl: mediaUrl,
    );
  }

  factory SpotlightItem.posterRecord(Map<String, dynamic> json) {
    final urls = <String>[];
    final raw = json['images'] ?? json['media_items'];
    if (raw is List) {
      for (final image in raw) {
        final url = UrlNormalizer.normalize(image is Map
            ? (image['image_url'] ?? image['url'] ?? image['media_url'])
                ?.toString()
            : image?.toString());
        if (url.isNotEmpty) urls.add(url);
      }
    }
    if (urls.isEmpty) {
      final url = UrlNormalizer.normalize(
          (json['image_url'] ?? json['thumbnail_url'])?.toString());
      if (url.isNotEmpty) urls.add(url);
    }
    return SpotlightItem(
        id: json['id']?.toString() ?? '',
        type: SpotlightType.poster,
        mediaUrl: urls.isEmpty ? '' : urls.first,
        imageUrls: urls,
        title: json['title']?.toString());
  }

  factory SpotlightItem.infoCard(String id, String title) {
    return SpotlightItem(
      id: id,
      type: SpotlightType.infoCard,
      title: title,
    );
  }

  factory SpotlightItem.ad(AdBanner ad) {
    return SpotlightItem(
      id: ad.id,
      type: SpotlightType.ad,
      adBanner: ad,
    );
  }

  factory SpotlightItem.shimmer() {
    return SpotlightItem(
      id: 'shimmer_${DateTime.now().millisecondsSinceEpoch}',
      type: SpotlightType.shimmer,
    );
  }
}
