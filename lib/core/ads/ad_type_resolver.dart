import '../../models/ad_banner.dart';

/// Presentation types supported by the Flutter client.
enum AdPresentationType {
  /// Responsive banner strip (16:5 or 16:4, 90-120dp)
  banner,

  /// Square/box ad (1:1)
  box,

  /// Premium 3D interactive promotional ad (4:3 or 1:1, tilt/parallax)
  threeD,

  /// Full-screen transition ad (between pages)
  interstitial,

  /// Native card matching article card style (16:9 media)
  nativeCard,

  /// Video player card (16:9 video source with poster)
  videoCard,

  /// Poster-style creative (4:5 or 9:16)
  poster,

  /// Sponsored card matching article card style
  sponsoredCard,

  /// Compact top ticker/strip (36-48dp)
  breakingStrip,

  /// Local business listing card (flexible layout for local sections)
  localListing,

  /// Full screen ad (similar to interstitial)
  fullScreen,

  /// Sticky bottom banner (56-80dp, fixed above bottom nav)
  bottomSticky,

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
      case 'banner':
        return AdPresentationType.banner;

      case 'box':
        return AdPresentationType.box;

      case 'three_d':
      case '3d':
        return AdPresentationType.threeD;

      case 'interstitial':
        return AdPresentationType.interstitial;

      case 'native':
        return AdPresentationType.nativeCard;

      case 'video':
        return AdPresentationType.videoCard;

      case 'poster':
        return AdPresentationType.poster;

      case 'sponsored_card':
        return AdPresentationType.sponsoredCard;

      case 'breaking_strip':
        return AdPresentationType.breakingStrip;

      case 'local_listing':
        return AdPresentationType.localListing;

      case 'full_screen':
        return AdPresentationType.fullScreen;

      case 'bottom_sticky':
        return AdPresentationType.bottomSticky;

      default:
        return AdPresentationType.unsupported;
    }
  }

  /// Recommended fixed aspect ratio for each ad type (width / height).
  /// Null if sizing is defined by fixed height or full screen.
  static double? getFixedAspectRatio(String adType) {
    final presentation = resolveType(adType);
    switch (presentation) {
      case AdPresentationType.banner:
        return 16 / 5; // 16:5 (or 16:4)
      case AdPresentationType.box:
        return 1.0; // 1:1
      case AdPresentationType.threeD:
        return 4 / 3; // 4:3 (or 1:1)
      case AdPresentationType.nativeCard:
      case AdPresentationType.sponsoredCard:
        return 16 / 9; // Same as article card
      case AdPresentationType.videoCard:
        return 16 / 9; // 16:9
      case AdPresentationType.poster:
        return 4 / 5; // 4:5 (or 9:16)
      case AdPresentationType.localListing:
        return 16 / 7; // Flexible card layout
      case AdPresentationType.interstitial:
      case AdPresentationType.fullScreen:
      case AdPresentationType.breakingStrip:
      case AdPresentationType.bottomSticky:
      case AdPresentationType.unsupported:
        return null;
    }
  }

  /// Recommended fixed height for strip and sticky banners in dp.
  static double? getFixedHeight(String adType) {
    final presentation = resolveType(adType);
    switch (presentation) {
      case AdPresentationType.breakingStrip:
        return 42.0; // 36-48dp
      case AdPresentationType.bottomSticky:
        return 64.0; // 56-80dp
      default:
        return null;
    }
  }

  /// Returns true if the ad type is supported by current APK widgets.
  static bool isSupported(AdBanner ad) {
    return resolve(ad) != AdPresentationType.unsupported;
  }
}
