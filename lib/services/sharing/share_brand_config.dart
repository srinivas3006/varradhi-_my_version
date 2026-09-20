import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One place for the branding that appears in shared text and generated
/// images, so a template never hard-codes its own name, domain or colour.
class ShareBrandConfig {
  const ShareBrandConfig._();

  static const String appName = 'Vaaradhi News';
  static const String appNameTelugu = 'వారధి న్యూస్';

  /// Play Store listing — the URL that actually travels in a share.
  ///
  /// Play serves its own Open Graph metadata, so a recipient gets a real
  /// preview. The site has no per-item og: tags yet, so sharing a
  /// vaaradhinews.com link produced a blank preview and a page that may not
  /// resolve. Package is com.varadhi: the old com.vaaradhi.vaaradhi id was
  /// stale and its listing link was dead.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.varadhi';

  /// Public site. Used for canonical/deep-link URLs only — never the API
  /// host, which is a different domain and must never be shared.
  static const String website = 'https://vaaradhinews.com';

  /// Shown on generated assets without the scheme.
  static String get displayDomain =>
      website.replaceFirst(RegExp(r'^https?://'), '');

  /// Host used for Android App Links / iOS Universal Links verification.
  static String get linkHost => displayDomain;

  static const String logoAsset = 'assets/images/logo.png';

  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = Color(0xFF101014);

  /// Trailing attribution line on every share.
  static String get sharedVia => 'Shared via $appName';
}
