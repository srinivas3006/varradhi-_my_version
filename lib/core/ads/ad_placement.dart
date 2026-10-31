import '../../models/ad_banner.dart';
import 'ad_type_resolver.dart';

/// Maps presentation names to the backend's placement zones.
///
/// The four original zones (feed, article, splash, search) keep their old
/// aliases. The five zones added later (ad placement confirmation) are sent
/// exactly as named and never folded into an older zone.
class AdPlacement {
  static const homeTop = 'home_top';
  static const category = 'category';
  static const ugcFeed = 'ugc_feed';
  static const videoFeed = 'video_feed';
  static const articleEnd = 'article_end';

  static String canonical(String zone) {
    switch (zone.trim().toLowerCase()) {
      case 'article':
      case 'article_detail':
      case 'article_bottom':
        return 'article';
      case 'splash':
        return 'splash';
      case 'search':
        return 'search';
      case homeTop:
        return homeTop;
      case category:
        return category;
      case ugcFeed:
        return ugcFeed;
      case videoFeed:
        return videoFeed;
      case articleEnd:
        return articleEnd;
      case 'feed':
      case 'spotlight':
      case 'interstitial':
      case 'banner':
      case 'bottom_sticky':
      case 'home_bottom':
      case 'home_banner':
      case 'video_bottom':
      case 'category_feed':
      case 'strip':
      case 'local':
        return 'feed';
      default:
        throw ArgumentError.value(zone, 'zone', 'Unsupported ad placement');
    }
  }

  /// The formats each new zone renders. The original zones are not limited
  /// here: their screens choose formats as before.
  static const Map<String, Set<AdPresentationType>> _formats = {
    homeTop: {AdPresentationType.banner, AdPresentationType.breakingStrip},
    category: {
      AdPresentationType.banner,
      AdPresentationType.box,
      AdPresentationType.nativeCard,
      AdPresentationType.videoCard,
    },
    ugcFeed: {
      AdPresentationType.nativeCard,
      AdPresentationType.banner,
      AdPresentationType.box,
    },
    videoFeed: {AdPresentationType.videoCard, AdPresentationType.banner},
    articleEnd: {
      AdPresentationType.banner,
      AdPresentationType.box,
      AdPresentationType.nativeCard,
    },
  };

  /// Whether [ad] can render in [zone]. An ad_type the zone does not take is
  /// skipped, never forced into another layout.
  static bool supports(String zone, AdBanner ad) {
    final type = AdTypeResolver.resolve(ad);
    if (type == AdPresentationType.unsupported) return false;
    final allowed = _formats[canonical(zone)];
    return allowed == null || allowed.contains(type);
  }
}
