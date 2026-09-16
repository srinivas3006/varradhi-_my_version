import 'news_article.dart';
import 'poster_images.dart';
import 'ad_banner.dart';
import 'poll.dart';

enum SpotlightType {
  standard,
  ugc,
  carousel,
  ad,
  poster,
  infoCard,
  shimmer,
  poll;

  /// True for cards where the app chrome is allowed to fade away.
  ///
  /// Stories are immersive by nature. Ads and posters join them because they
  /// are full-bleed media that carry their own close control inside the card
  /// — leaving the header and bottom bar pinned over them just covers the
  /// creative.
  ///
  /// Polls and info cards are the exception: their controls are the point of
  /// the card, so the chrome stays put. A reader cannot vote on, or leave, a
  /// card whose chrome has gone.
  bool get isImmersiveStory =>
      this == SpotlightType.standard ||
      this == SpotlightType.ugc ||
      this == SpotlightType.carousel ||
      this == SpotlightType.ad ||
      this == SpotlightType.poster;
}

class SpotlightItem {
  final String id;
  final SpotlightType type;

  // For standard news
  final NewsArticle? article;

  // For carousel news
  final List<String>? imageUrls;

  /// 1-based position of this page within its parent poster, and how many
  /// pages that poster produced. Lets a page say "2 / 5" without needing to
  /// know about its siblings.
  final int posterPageIndex;
  final int posterPageCount;
  final String? title;

  // For poster / infoCard / ad
  final String? mediaUrl;
  final AdBanner? adBanner;
  final Poll? poll;

  const SpotlightItem({
    required this.id,
    required this.type,
    this.article,
    this.imageUrls,
    this.posterPageIndex = 1,
    this.posterPageCount = 1,
    this.title,
    this.mediaUrl,
    this.adBanner,
    this.poll,
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

  /// Parses `GET /api/v1/posters/` via the shared [posterImageUrls].
  factory SpotlightItem.posterRecord(Map<String, dynamic> json) {
    final urls = posterImageUrls(json);
    return SpotlightItem(
        id: json['id']?.toString() ?? '',
        type: SpotlightType.poster,
        mediaUrl: urls.isEmpty ? '' : urls.first,
        imageUrls: urls,
        title: json['title']?.toString());
  }

  /// One page per poster, carrying all of its images.
  ///
  /// A poster record can hold several designs of the same poster. They belong
  /// on one page, swiped horizontally with a counter and dots — splitting
  /// them across separate vertical pages made a six-image poster feel like
  /// six unrelated items in the feed.
  static List<SpotlightItem> posterPages(Map<String, dynamic> json) {
    final record = SpotlightItem.posterRecord(json);
    final urls = record.imageUrls ?? const <String>[];
    if (record.id.isEmpty || urls.isEmpty) return const <SpotlightItem>[];
    return <SpotlightItem>[
      SpotlightItem(
        id: record.id,
        type: SpotlightType.poster,
        mediaUrl: urls.first,
        imageUrls: urls,
        title: record.title,
        posterPageIndex: 1,
        posterPageCount: urls.length,
      ),
    ];
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

  factory SpotlightItem.poll(Poll poll) {
    return SpotlightItem(
      id: poll.id,
      type: SpotlightType.poll,
      poll: poll,
    );
  }
}
