# Production Advertisement Engine Documentation

This document describes the architecture, backend contract, targeting, placement rules, frequency management, event lifecycle, and resilience strategies for the advertisement engine in the VARADHI Flutter application.

---

## 1. Architecture Overview

```
AdWidget (NativeAdCard, BannerAdSlot, VideoAdCard, InterstitialAdOverlay)
   │
   ▼
AdViewabilityDetector (Visibility dwell qualification + exposure key deduplication)
   │
   ▼
AdManager (Client session rules, cooldowns, frequency resolution, rotation, event dispatch)
   │
   ▼
AdRepository (Targeting params, caching with TTL, in-flight deduplication)
   │
   ▼
ApiClient (DioClient / ApiService)
   │
   ▼
Backend (/api/v1/ads/, /api/v1/ads/event/)
```

### Layer Separation:
1. **Presentation Layer (`AdWidget`, `AdViewabilityDetector`)**:
   Renders creatives (images, videos), manages visibility dwell time (500ms for impression, 2000ms for viewability), and isolates UI from network and state concerns.
2. **Session & Business Logic (`AdManager`)**:
   Coordinates client session rules (cooldowns, cold-launch suppression, active-video suppression, recent creative rotation) and derives the feed presentation sequence without mutating underlying content items.
3. **Data Layer (`AdRepository`)**:
   Fetches active ads (`GET /api/v1/ads/`), manages short-lived TTL caching (5 minutes), prevents concurrent duplicate in-flight requests, and handles location-based invalidation.
4. **Network & Dispatcher (`AdEventQueue`, `DioClient`)**:
   Dispatches events (`POST /api/v1/ads/event/`) asynchronously with exponential backoff and retry, ensuring analytics delivery never blocks the UI or impacts user experience.

---

## 2. Backend Contract

### Ad Retrieval (`GET /api/v1/ads/`)

Supported query parameters:
* `placement_zone`: Placement context (`feed`, `article`, `splash`, `search`, `banner`)
* `zone`: Synonym for placement_zone
* `scope`: Target scope (`global`, `state`, `local`)
* `area_id`: Granular area identifier
* `state`: State name (e.g. `Telangana`, `Andhra Pradesh`)
* `district`: District name (e.g. `Hyderabad`, `Suryapet`)
* `city`: City / Town name
* `subdistrict`: Mandal / Tehsil
* `village`: Village / Local ward
* `lang`: Language code (default `te`)

Response attributes:
* `id`: Unique ad record ID
* `image_url`: Primary creative or video thumbnail/poster
* `video_url`: Playable video stream or MP4 asset (for video ads)
* `destination_url`: External target URL launched on user click
* `ad_type`: Creative format (`native`, `banner`, `video`, `interstitial`, `sponsored_card`, etc.)
* `placement_zone`: Intended placement zone
* `target_scope`: Geographic reach (`global`, `state`, `local`)
* `area` / `area_id`: Targeted area metadata
* `display_frequency`: Frequency spacing interval (e.g. 4 means insert after 4 items)
* `daily_max_impressions_per_user`: Client-side daily exposure cap
* `ctr`: Click-through-rate metric

---

## 3. Event Contract & Lifecycle (`POST /api/v1/ads/event/`)

Supported event types:
* `impression`: Emitted once when creative is >= 50% visible for >= 500ms
* `viewability`: Emitted once when creative is >= 50% visible for >= 2000ms
* `click`: Emitted when user taps the ad (triggers `url_launcher`)
* `dismiss`: Emitted when user explicitly closes an ad (e.g. Spotlight or interstitial close button)
* `skip`: Emitted when an ad timer expires or user skips after countdown
* `hide`: Emitted if user chooses to hide or report an ad

Payload:
```json
{
  "ad_id": "ad_101",
  "event_type": "viewability",
  "placement_zone": "feed"
}
```

---

## 4. Viewability & Deduplication Policy

### Dwell Qualification
* **Impression**: Fired when `visibleFraction >= 0.5` continuously for at least 500ms.
* **Viewability**: Fired when `visibleFraction >= 0.5` continuously for at least 2000ms.
* **Fast-Swipe Suppression**: Quick scrolling through the feed (< 500ms) cancels active timers and emits zero network events.

### Exposure Key Deduplication
To prevent duplicate network events across widget rebuilds, scroll cycles, and screen transitions, each exposure is identified by:
```
exposureKey = "${ad.id}_${placementZone}_${eventType}_${contextKey}"
```
The `AdManager` maintains a set of emitted event keys. Once an impression or viewability event is recorded for an exposure key in the current session, subsequent notifications are ignored.

---

## 5. Frequency & Placement Rules

### Server-Driven vs Client-Driven Rules
* **Backend Rules**:
  * `display_frequency`: Controls content spacing (e.g., insert ad after every N content items).
  * `daily_max_impressions_per_user`: Enforces user-level daily impression limits.
  * Targeting parameters: Restricts eligible inventory to the active user's location and language.
* **Client-Side UX Rules**:
  * **No Launch Interstitials**: Interstitials are suppressed during cold launch until the session age exceeds 5 minutes and at least 3 content interactions occur.
  * **Cooldown**: A 5-minute cooldown is enforced between disruptive interstitial appearances.
  * **Active Video Protection**: Interstitials are strictly suppressed if video is actively playing anywhere in the app.
  * **First-Two Protection**: In feeds, ads are never inserted before the first 2 content items.
  * **Anti-Repetition**: `AdManager` tracks recently shown ad IDs (circular buffer of 5) to rotate creatives rather than showing the same ad back-to-back.

### Feed Presentation Calculation
The feed presentation is calculated non-destructively:
```dart
final presentationItems = AdManager.instance.buildFeedPresentation<NewsArticle>(
  contentItems: remainingArticles,
  adsPool: _feedAds,
);
```
The underlying `_articles` list is never mutated. Stable keys (`content_$index` and `ad_${ad.id}_slot_$slot`) preserve scroll position during pagination and refresh.

---

## 6. Video Ads Architecture

* **Type Resolution**: `AdTypeResolver.resolve` maps `ad_type == 'video'` or non-empty `video_url` to `AdPresentationType.videoCard`.
* **Poster**: Displays `image_url` as high-resolution poster while video buffers or initializes.
* **STEP 3 Media Reuse**: Reuses `MediaResolver` and `NetworkVideoPlaybackController` directly without spawning redundant video engines.
* **Scroll Lifecycle**: Automatically plays muted when >= 70% visible; pauses when scrolled out of view; disposes all player resources when unmounted.
* **Active Video Registration**: Registers with `AdManager.registerActiveVideo()` while playing so interstitials are suppressed.

---

## 7. Caching & Fault Tolerance

* **Short-Lived Cache**: Active ads are cached per targeting query for 5 minutes (`cacheTtl`).
* **In-Flight Request Deduplication**: Simultaneous identical calls share a single underlying `Future`.
* **Location Invalidation**: Updating state/district/city via `AppState.setLocation` automatically clears `AdRepository` cache.
* **Offline / Error Resilience**:
  * Ad network failures return empty fallback lists without throwing or blocking feed loading.
  * `AdEventQueue` buffers failed event deliveries and retries up to 3 times with exponential backoff before safely dropping.

---

## 8. Verification & Testing Strategy

1. `test/ad_model_test.dart`: Serialization, dirty types, nullables, and `AdTypeResolver`.
2. `test/ad_repository_test.dart`: Targeting query construction, cache hit/miss/expiry, and in-flight deduplication.
3. `test/ad_manager_test.dart`: Cold launch suppression, cooldowns, video suppression, rotation, daily caps, and event deduplication.
4. `test/ad_event_queue_test.dart`: Offline event queuing, retry backoff, and queue reset.
5. `test/feed_ad_placement_test.dart`: Feed presentation generation, pagination, and list immutability.
