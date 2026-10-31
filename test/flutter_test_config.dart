import 'dart:async';

import 'package:vaaradhi/core/ads/zone_ads.dart';

/// Runs before every test file. The per-screen ad zones (home_top,
/// category, ugc_feed, video_feed, article_end) make no network request in
/// tests unless a test supplies ads itself (ZoneAds.loader).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ZoneAds.loader = (_) async => const [];
  await testMain();
}
