import '../../models/ad_banner.dart';

/// Presentation types supported by the Flutter client.
enum AdPresentationType {
  /// Native feed or list item card matching content card style
  nativeCard,

  /// Responsive banner strip (e.g. In articles or utility screens)
  banner,

  /// Video player card with poster, play-on-scroll, and audio controls
  videoCard,

  /// Full-screen or modal interstitial overlay shown at natural breaks
  interstitial,

  /// Unsupported or unknown ad type to be skipped gracefully
  unsupported,
}

/// Central mapping that resolves raw backend ad types into typed client presentations.
class AdTypeResolver {
  const AdTypeResolver._();

  /// Resolves the presentation type from an [AdBanner] or raw string [adType].
  static AdPresentationType resolve(dynamic adOrType) {
    if (adOrType == null) return AdPresentationType.unsupported;

    if (adOrType is AdBanner) {
      if (adOrType.isVideo) {
        return AdPresentationType.videoCard;
      }
      return resolveType(adOrType.adType);
    }

    if (adOrType is String) {
      return resolveType(adOrType);
    }

    return AdPresentationType.unsupported;
  }

  /// Resolves raw [adType] string to [AdPresentationType].
  static AdPresentationType resolveType(String adType) {
    final normalized = adType.trim().toLowerCase();
    switch (normalized) {
      case 'video':
        return AdPresentationType.videoCard;

      case 'native':
      case 'sponsored_card':
      case 'poster':
      case 'box':
      case 'three_d':
        return AdPresentationType.nativeCard;

      case 'banner':
      case 'bottom_sticky':
      case 'breaking_strip':
      case 'local_listing':
        return AdPresentationType.banner;

      case 'interstitial':
      case 'full_screen':
        return AdPresentationType.interstitial;

      default:
        // Graceful fallback for unexpected backend types
        return AdPresentationType.unsupported;
    }
  }

  /// Returns true if the ad type is supported by current APK widgets.
  static bool isSupported(AdBanner ad) {
    return resolve(ad) != AdPresentationType.unsupported;
  }
}
