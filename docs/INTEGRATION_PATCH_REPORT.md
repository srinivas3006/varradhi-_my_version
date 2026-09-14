# Ads, Spotlight, Media and Location Integration Patch

## 1. Root cause

Home and Spotlight used different paths for ads. Home used the existing ad manager/widgets; Spotlight queried a UI placement alias (`spotlight`), loaded/injected ads through separate logic, and tied insertion to swipe dwell rather than completed parent-content intervals. The legacy feed engine also imposed its own spacing. Several anchored slots selected unrelated ad types as fallbacks. A nonempty video URL overrode the explicit ad type in the renderer.

The ad model did not read the canonical `display_duration_seconds` field and invented a nonzero default. Session impression counts were treated as daily eligibility. Visibility and exposure handling differed between presentations; nested video detectors could also share a registry key. These layers now share canonical requests, typed presentation, insertion, and exposure tracking.

Article media was reordered during parsing, and the UGC adapter discarded the full media collection. Detail and Spotlight followed separate image/video branches; Spotlight lacked a dedicated UGC parent type, and poster selection could omit independent posters. The patch retains one typed content record and pages media inside it.

Location-dependent auxiliary requests could finish after the selected location changed. The local state/global sections shared pagination data. Current-context guards, immediate clearing and independent cursors address those failure paths.

## 2. Files changed

The following files changed during this integration patch, compared with the snapshot taken before it. Earlier behavior fixes already present in the workspace are preserved; the user-edited API document was not modified by this patch.

| File | Purpose |
| --- | --- |
| [lib/core/ads/ad_event_queue.dart](../lib/core/ads/ad_event_queue.dart) | Canonical event zones and generation-safe queue reset/processing. |
| [lib/core/ads/ad_insertion.dart](../lib/core/ads/ad_insertion.dart) | Reusable deterministic rotation with each ad’s own parent-card interval and stable placement keys. |
| [lib/core/ads/ad_placement.dart](../lib/core/ads/ad_placement.dart) | Map existing UI placement aliases to backend-supported zones. |
| [lib/core/ads/ad_type_resolver.dart](../lib/core/ads/ad_type_resolver.dart) | Use explicit ad_type; a video URL cannot override fullscreen/native presentation type. |
| [lib/core/feed/feed_engine.dart](../lib/core/feed/feed_engine.dart) | Reuse the same ad insertion helper instead of a separate global-frequency algorithm. |
| [lib/core/network/dio_client.dart](../lib/core/network/dio_client.dart) | Send the existing stable device ID and session ID through the shared interceptor. |
| [lib/models/ad_banner.dart](../lib/models/ad_banner.dart) | Parse and serialize display_duration_seconds; preserve zero duration and backend cap metadata. |
| [lib/models/news_article.dart](../lib/models/news_article.dart) | Preserve backend media order and cache serialization; distinguish actual video sources from images. |
| [lib/models/spotlight_item.dart](../lib/models/spotlight_item.dart) | Represent UGC explicitly and keep each poster record as one parent with its own media list. |
| [lib/models/unified_feed_item.dart](../lib/models/unified_feed_item.dart) | Retain UGC media metadata and project explicit parent type and location into the existing article model. |
| [lib/repositories/ad_repository.dart](../lib/repositories/ad_repository.dart) | Canonical feed-zone requests, selected-location/language targeting, zone filtering and existing caching. |
| [lib/repositories/ugc_repository.dart](../lib/repositories/ugc_repository.dart) | Reuse the lossless UnifiedFeedItem projection instead of discarding media metadata. |
| [lib/repositories/video_repository.dart](../lib/repositories/video_repository.dart) | Include selected location in video requests and request-deduplication identity. |
| [lib/screens/home_screen.dart](../lib/screens/home_screen.dart) | Select only eligible bottom-sticky ads from feed and clear/reload them when location changes. |
| [lib/screens/local_news_tab.dart](../lib/screens/local_news_tab.dart) | Retain village/mandal/district/state/global sections, give global its own cursor, reject stale responses and insert ads by parent count. |
| [lib/screens/news_detail_screen.dart](../lib/screens/news_detail_screen.dart) | Reuse the media carousel in the existing hero area while retaining article-detail loading and UGC actions. |
| [lib/screens/news_feed_tab.dart](../lib/screens/news_feed_tab.dart) | Clear old-context section data, guard auxiliary responses, and use deterministic ad insertion without an extra uncounted banner. |
| [lib/screens/ugc_feed_screen.dart](../lib/screens/ugc_feed_screen.dart) | Preserve mixed media within each UGC card and guard refresh/pagination against location changes. |
| [lib/screens/video_tab.dart](../lib/screens/video_tab.dart) | Refresh videos and sticky ads on location/language changes; preserve existing video/shorts pagination. |
| [lib/services/ad_manager.dart](../lib/services/ad_manager.dart) | Delegate parent-card insertion to one helper; trust backend daily eligibility; deduplicate exposure events. |
| [lib/services/api_service.dart](../lib/services/api_service.dart) | Reuse the ad repository, canonicalize event zones, and preserve UGC mixed-media metadata. |
| [lib/spotlight/spotlight_controller.dart](../lib/spotlight/spotlight_controller.dart) | Compose articles, UGC, independent posters and ads; use separate article/UGC cursors and reject stale location responses. |
| [lib/spotlight/spotlight_screen.dart](../lib/spotlight/spotlight_screen.dart) | Render typed parents with internal media and existing ad widgets; remove swipe-time ad insertion. |
| [lib/widgets/ads/ad_viewability_detector.dart](../lib/widgets/ads/ad_viewability_detector.dart) | Require continuous foreground visibility for one second; propagate active-page state and deduplicate exposures. |
| [lib/widgets/ads/banner_ad_slot.dart](../lib/widgets/ads/banner_ad_slot.dart) | Request canonical zones, select actual banners and reload safely after location changes. |
| [lib/widgets/ads/bottom_sticky_ad_banner.dart](../lib/widgets/ads/bottom_sticky_ad_banner.dart) | Collapse on failed image loading while retaining the existing sticky presentation. |
| [lib/widgets/ads/interstitial_ad_overlay.dart](../lib/widgets/ads/interstitial_ad_overlay.dart) | Select actual timed ad types; use backend duration, pause in background, render video sources and track canonical events. |
| [lib/widgets/ads/sponsored_spotlight_ad_card.dart](../lib/widgets/ads/sponsored_spotlight_ad_card.dart) | Use backend timed durations only for fullscreen/interstitial; pause inactive timers and send proper hide/dismiss events. |
| [lib/widgets/ads/unified_ad_widget.dart](../lib/widgets/ads/unified_ad_widget.dart) | Propagate active-page state through the existing renderer and skip unsupported types. |
| [lib/widgets/ads/video_ad_card.dart](../lib/widgets/ads/video_ad_card.dart) | Lazy-load visible video_url media, coordinate exclusive playback, dispose safely and constrain video to 16:9. |
| [lib/widgets/article_media_carousel.dart](../lib/widgets/article_media_carousel.dart) | Share the existing image/video presentation inside a single parent with independent horizontal pagination. |
| [lib/widgets/news_article_video_player.dart](../lib/widgets/news_article_video_player.dart) | Play the selected media URL, stop inactive/background playback and guard controller initialization/disposal. |
| [lib/widgets/parallax_page_flip.dart](../lib/widgets/parallax_page_flip.dart) | Clamp navigation when a dismissed ad reduces the page count. |
| [lib/widgets/poster_card.dart](../lib/widgets/poster_card.dart) | Keep a poster’s images in its horizontal pager; remove the invented default countdown. |
| [lib/widgets/spotlight/spotlight_news_card.dart](../lib/widgets/spotlight/spotlight_news_card.dart) | Reuse article-detail/media handling within the existing Spotlight card. |
| [test/ad_manager_test.dart](../test/ad_manager_test.dart) | Update frequency boundary and backend-controlled daily-cap expectations. |
| [test/ad_model_test.dart](../test/ad_model_test.dart) | Assert explicit type takes precedence over a video URL. |
| [test/ad_repository_test.dart](../test/ad_repository_test.dart) | Exercise network failure using a supported backend zone. |
| [test/ad_system_specification_test.dart](../test/ad_system_specification_test.dart) | Assert backend eligibility controls caps rather than session-local counts. |
| [test/feed_engine_architecture_test.dart](../test/feed_engine_architecture_test.dart) | Assert backend ad frequency overrides legacy engine spacing configuration. |
| [test/integration_patch_contract_test.dart](../test/integration_patch_contract_test.dart) | Expose the shared model/insertion contract cases to flutter test. |
| [test/integration_patch_widgets_test.dart](../test/integration_patch_widgets_test.dart) | Test real visibility dwell, event headers, rebuild deduplication, clicks, foreground timing and media-vs-parent gestures. |
| [test/news_detail_ugc_test.dart](../test/news_detail_ugc_test.dart) | Verify the body through the existing decorative drop-cap rich text. |
| [test/spotlight_integration_patch_test.dart](../test/spotlight_integration_patch_test.dart) | Exercise actual controller composition and an intentionally delayed old-location response. |
| [test/spotlight_primary_feed_test.dart](../test/spotlight_primary_feed_test.dart) | Return article fixtures only for the article endpoint, not UGC/poster/ad endpoints. |
| [test/support/integration_contract_cases.dart](../test/support/integration_contract_cases.dart) | 24 reusable cases for ad metadata, rotation, parent/media identity, posters, ratios and independent cursors. |
| [test/widget_test.dart](../test/widget_test.dart) | Drain startup requests and unmount the app to avoid pending timers in the smoke test. |
| [tool/check_integration_patch.dart](../tool/check_integration_patch.dart) | Standalone runner for the 24 pure contract checks. |
| [pubspec.lock](../pubspec.lock) | Four Flutter-SDK-pinned transitive packages resolved for the verification SDK: matcher, meta, test_api and vector_math. No direct dependency or pubspec change. |
| [docs/INTEGRATION_PATCH_REPORT.md](INTEGRATION_PATCH_REPORT.md) | This implementation and verification report. |

## 3. Ad implementation

`GET /api/v1/ads/?zone=feed` uses the existing shared API client, repository cache and selected targeting context. Legacy UI aliases map to a supported backend zone. Requests and queued events use the existing installation device identity and optional session ID. Returned eligibility is authoritative; zero daily cap remains backend-default metadata, and session counters do not filter eligible ads. Impression recording invalidates the ad cache for subsequent requests.

Insertion counts parent records only. The next ad’s own positive frequency is the number of content cards required since the previous insertion. Thus A=4, B=6, C=3 gives placements after cards 4, 10 and 13; equal frequency 4 gives 4, 8, 12, rotating A/B/C/A. Only one ad is inserted at a point. Duplicate ad IDs, wrong-zone ads, unsupported types and sticky types are excluded from the inline stream. Timed ads are allowed in Spotlight’s fullscreen presentation. Nonpositive frequency retains the existing safe fallback interval of five cards.

The existing specialized widgets render each explicit ad type. Images use the existing cached-image components and controlled geometry; video uses video_url with image_url as poster. Video ads use 16:9 and join the existing media coordinator so they do not compete with another active video/TTS session. Sticky ads remain above existing bottom navigation. Failed images collapse or use the existing fallback.

Only positive fullscreen/interstitial durations create timers; inactive/background time is paused. Duration zero creates no timer. Normal feed advertisements remain in the feed. Expiry sends hide; user close sends dismiss; the interstitial skip action sends skip. An impression and viewability event require at least 50% visibility continuously for approximately one foreground second. Stable placement/exposure identities prevent rebuild duplicates. Clicking queues the click event and opens the returned destination URL through the existing launcher.

## 4. Media implementation

Articles and UGC remain one parent each regardless of media count. Backend media order is preserved, including mixed image/video lists. The shared horizontal carousel uses existing cached images and the existing article video player. Only the active visible media can play; inactive/background players stop and controllers are disposed. Horizontal media gestures remain independent of Spotlight’s vertical page navigation.

UGC’s explicit parent type survives repository conversion. Article detail still retrieves full details by slug; UGC retains its supported existing detail behavior. Each poster backend record becomes one standalone Spotlight page, with its own images paged internally. Independent poster records are never merged. Ads remain separate parent items.

## 5. Location implementation

The existing persisted AppState location remains the source of truth; no second SelectedLocation store was introduced. The existing location API picker is retained. Home’s section architecture is preserved. Local sections use village, mandal, district, state and global queries and filter their corresponding coverage levels. Sparse village results are not filled with unrelated broader news. Each article section owns its cursor and loading state; global no longer consumes the state cursor.

Location/language changes clear old-context content and refresh feed sections, UGC, videos and ads. Request generation/query identity checks discard stale results; section pagination cannot run against a refresh in progress. Spotlight has independent article and UGC cursors. Shorts are refreshed on location changes through their existing endpoint; that endpoint is not assigned undocumented location parameters.

## 6. Tests and commands

The installed global Flutter SDK was too old for the existing dependencies. Verification used an isolated, checksum-verified Flutter 3.47.4 / Dart 3.13.3 SDK under `/tmp/varadhi-sdk`; the global SDK was not replaced.

```sh
/tmp/varadhi-sdk/flutter/bin/flutter pub get
/tmp/varadhi-sdk/flutter/bin/flutter test --no-pub --concurrency=2
/tmp/varadhi-sdk/flutter/bin/flutter test --no-pub test/spotlight_integration_patch_test.dart
/tmp/varadhi-sdk/flutter/bin/flutter analyze --no-pub
```

- Dependency resolution succeeded. The SDK required four transitive lockfile updates listed above.
- Full regression suite: **239 passed, zero failed** (36 seconds).
- Subsequently added controller integration tests: **2 passed, zero failed**. They test four typed parents plus an ad, and rejecting a delayed old-location response after immediate clearing.
- Total verified tests across those runs: **241 passed**.
- The full suite includes the 24 new model/insertion cases and six new widget tests, as well as existing ads, media/player lifecycle, Home startup/navigation, repository, authentication and feed tests.
- Analysis: **zero errors, one warning, 45 informational lints**. The warning is the existing unused `_buildGuestCommentPrompt` in `comments_screen.dart`; informational findings include brace style and existing async-context/tool-runner lints. Analysis is not reported as a clean lint pass.
- Changed Dart files were formatted. No backend API or production mock data was introduced.

## 7. Regression check

Existing themes, colors, typography, main layout, navigation and authentication architecture were preserved. Article/UGC media now shares implementation inside the existing media areas. Ad geometry changes are limited to the requested type/media behavior. Home remains lazily mounted; its existing startup and notification navigation tests pass. Existing detail, UGC, video, network, repository and feed tests pass with the documented contract/fixture corrections.

These automated checks do not establish pixel-identical rendering on every device. No physical-device visual pass, real campaign delivery, destination-app launch or native codec playback was performed in this environment.

## 8. Remaining issues / backend dependencies

No backend contract change was required for the implemented patch. Live backend enforcement of eligibility, targeting and daily caps still needs deployment verification with real campaigns and device identities. The frontend cannot supply missing media records, missing coverage metadata or invent server pagination. It does not claim a local daily cap guarantee while offline. Physical-device checks of mixed native video playback, fullscreen transitions and sticky placement remain release validation tasks.
