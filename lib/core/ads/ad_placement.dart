/// Maps presentation names to the backend's four placement zones.
class AdPlacement {
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
}
