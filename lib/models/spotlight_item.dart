import 'news_article.dart';
import 'ad_banner.dart';

enum SpotlightType {
  standard,
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
      type: SpotlightType.standard,
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
