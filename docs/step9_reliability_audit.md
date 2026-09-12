# Step 9 — Production Reliability & Runtime Boundary Audit

**Application**: VARADHI APK  
**Stage**: STEP 9 — Reliability Engineering, Failure Testing & Release Hardening  
**Baseline Verified**: 155/155 tests passing, `flutter analyze` 0 issues, Debug & Release APK builds passing.  
**Auditor**: Production Reliability Engineering (Step 9)

---

## 1. Executive Summary & Audit Scope

This audit systematically evaluates every major runtime subsystem of the VARADHI Flutter application:
1. Startup & Application Bootstrap (`main.dart`, `splash_screen.dart`, `app_state.dart`)
2. Network & API Failure Resilience (`dio_client.dart`, `api_service.dart`, `api_response.dart`)
3. Authentication Lifecycle & Token Refresh Synchronization
4. Feeds, Pagination, Caching & Content Deduplication (`feed_repository.dart`, `news_feed_tab.dart`, `local_news_tab.dart`)
5. Video & Media Engine (`video_playback_controller.dart`, `video_player_widget.dart`, `video_tab.dart`)
6. Advertisement Engine & Event Queue (`ad_manager.dart`, `ad_event_queue.dart`, `ad_repository.dart`)
7. Citizen Reporter (UGC) Upload & Draft Persistence (`ugc_controller.dart`, `ugc_repository.dart`, `ugc_draft_repository.dart`)
8. Push Notifications, Deep Linking & Android 13+ Permissions (`notification_service.dart`, `notification_deep_link_resolver.dart`, `notification_navigation_gate.dart`)
9. Navigation Stack Safety, Android Predictive Back & Debounce (`home_screen.dart`, `app_navigator.dart`)
10. Resource Cleanup, Memory Leak Prevention & Lifecycle Transitions

---

## 2. Findings Classification Matrix

Findings are classified into 4 strict severity tiers:
- **P0**: Crash / Data Loss / Navigation Lock / Security Critical
- **P1**: Major User-Facing Failure / Inability to complete a primary workflow
- **P2**: Degraded UX / Suboptimal Performance / Unbounded resource accumulation
- **P3**: Cleanup / Noncritical Diagnostic Logging

---

## 3. Detailed Audit Findings

### [P0-01] UGC Multipart Media Upload DioException Swallowed in UgcRepository
- **Location**: `lib/repositories/ugc_repository.dart` (lines 109-123 & 135-149)
- **Subsystem**: Citizen Reporter / UGC Media Upload Pipeline
- **Description**: In `UgcRepository.uploadMedia` and `uploadMediaBatch`, the method wraps `ApiService.instance.uploadMedia(...)` with:
  ```dart
  try {
    return await ApiService.instance.uploadMedia(...);
  } on AppException {
    rethrow;
  } catch (e) {
    throw ApiException('మీడియాను అప్‌లోడ్ చేయడం విఫలమైంది.');
  }
  ```
  `ApiService` uses `_dio.post` which throws `DioException`. Because `DioException` is NOT an `AppException`, `UgcRepository` catches it in `catch (e)` and re-throws a generic `ApiException`.
  However, `UgcController.submitNews` specifically listens for `on DioException catch (dioErr)` to:
  1. Detect cancellation: `if (CancelToken.isCancel(dioErr))` -> set status to `cancelled`.
  2. Differentiate 4xx (non-retryable client error) vs 5xx / socket timeout (retryable).
  3. Perform bounded exponential backoff retries.
- **Impact**: Because `DioException` was converted into `ApiException`, user cancellation was reported as an upload failure (`status = failed`), transient socket retries never triggered, and non-retryable 4xx errors caused confusing generic error messages.
- **Remediation**: In `UgcRepository`, add `on DioException { rethrow; }` so that `UgcController` receives the raw cancellation and HTTP status codes directly.

---

### [P0-02] Unhandled Secure Storage PlatformException on Cold Startup / Keystore Invalidation
- **Location**: `lib/state/app_state.dart` (lines 201-209 in `init()`)
- **Subsystem**: State Persistence & App Startup
- **Description**: During `AppState.instance.init()`, auth tokens and installation secrets are read directly from `_secureStorage.read(...)` without a `try/catch` guard:
  ```dart
  authToken = await _secureStorage.read(key: _authTokenKey);
  refreshToken = await _secureStorage.read(key: _refreshTokenKey);
  installationSecret = await _secureStorage.read(key: _installationSecretKey);
  sessionId = await _secureStorage.read(key: _sessionIdKey);
  ```
  On Android, when app data is restored from Google Backup, the device hardware keystore is reset, or the OS is upgraded, `FlutterSecureStorage` throws `PlatformException(KeyStoreException)`. Because this runs before `runApp()`, an unhandled exception causes the APK to crash on launch.
- **Impact**: Crash on cold launch for users with restored backups or reset Keystores.
- **Remediation**: Wrap `_secureStorage.read` calls in a defensive `try/catch`. If an error occurs, safely wipe corrupted keys with `_secureStorage.deleteAll()`, log diagnostic info, and initialize as a guest session without crashing.

---

### [P1-01] Non-Persistent Android 13+ Notification Permission State & Repeated Prompts
- **Location**: `lib/services/notification_service.dart` (lines 37, 136-150)
- **Subsystem**: Push Notifications & Android 13+ System Integration
- **Description**: `_permissionRequested` was stored solely as an in-memory boolean field in `NotificationService`. Every time the user terminates and relaunches the application, `_permissionRequested` resets to `false`. When `NewsFeedTab` finishes loading articles, `requestPermissionAfterArticlesLoaded()` was called, triggering a permission prompt check on every cold start.
- **Impact**: Violates Android 13+ permission guidelines and Section 12 requirements ("Do not show a permission request repeatedly. Persist any local 'request already explained/requested' state").
- **Remediation**: Check existing system permission status via `FirebaseMessaging.instance.getNotificationSettings()`. Store a persistent boolean `hasRequestedNotificationPermission` in `SharedPreferences` after the first prompt, and skip subsequent prompts if already requested or determined.

---

### [P1-02] Unsafe Type Cast on Malformed or HTML Response Body in FeedRepository
- **Location**: `lib/repositories/feed_repository.dart` (lines 463-475)
- **Subsystem**: Network Data Layer & Feed Caching
- **Description**: In `FeedRepository._fetchFromNetwork`, the code parsed the response as:
  ```dart
  response.data is Map<String, dynamic>
      ? response.data as Map<String, dynamic>
      : Map<String, dynamic>.from(response.data as Map)
  ```
  If a reverse proxy, CDN, or Cloudflare returns a 502/503 HTML error page or empty string, `response.data as Map` throws a `TypeError: type 'String' is not a subtype of type 'Map'`.
- **Impact**: Unhandled `TypeError` instead of a structured `ApiResponse.error()` or `AppException`, crashing the repository flow.
- **Remediation**: Explicitly verify `if (response.data is Map<String, dynamic>)` / `else if (response.data is Map)`, and gracefully return `ApiResponse.error(message: 'చెల్లని సర్వర్ సమాధానం.', statusCode: response.statusCode)` if `response.data` is not a map.

---

### [P1-03] AppNavigator Missing `context.mounted` Verification
- **Location**: `lib/core/navigation/app_navigator.dart` (lines 19-72)
- **Subsystem**: Navigation Architecture
- **Description**: `AppNavigator.pushSafe`, `pushReplacementSafe`, and `popSafe` called `Navigator.of(context)` without checking `context.mounted`. When called after asynchronous operations (such as token refresh, network fetch, or dialog result), an unmounted context throws `FlutterError: Looking up a deactivated widget's Ancestor is unsafe`.
- **Impact**: Potential crash or red-screen error on rapid user back-navigation during async calls.
- **Remediation**: Guard each method with `if (!context.mounted) return null;` before accessing the navigator.

---

### [P2-01] Unbounded Ad Event Queue and Duplicate Pending Events
- **Location**: `lib/core/ads/ad_event_queue.dart` (lines 59-74)
- **Subsystem**: Advertisement Engine
- **Description**: `AdEventQueue.enqueue` pushed events to `_queue` without a capacity cap and without checking if an identical event (`adId` + `eventType` + `placementZone`) was already pending in the queue. Under prolonged offline operation, hundreds of duplicate impression events could accumulate in RAM.
- **Impact**: Memory bloat and burst HTTP traffic upon reconnection.
- **Remediation**: Deduplicate pending events and enforce a bounded queue size (`maxQueueSize = 50`), discarding the oldest items if the capacity is exceeded.

---

### [P2-02] Un-disposed TextEditingControllers in Modal Dialogs and Bottom Sheets
- **Location**: `lib/screens/comments_screen.dart` (line 228) and `lib/screens/profile_tab.dart` (line 721)
- **Subsystem**: Memory & Resource Management
- **Description**: `_showEditDialog` in `comments_screen.dart` created `final editController = TextEditingController(...)` inside a method, but did not call `editController.dispose()` when `showDialog` completed. Similarly, `_showEditProfilePopup` in `profile_tab.dart` instantiated `nameController` without disposing it upon sheet dismissal.
- **Impact**: Memory leak of `TextEditingController` instances and associated listeners upon opening edit dialogs.
- **Remediation**: Chain `.whenComplete(() => controller.dispose())` to the dialog/sheet futures.

---

### [P2-03] Redundant Logout Triggered for Guest Users on 401
- **Location**: `lib/core/network/dio_client.dart` (lines 98-101)
- **Subsystem**: Authentication & Error Interceptor
- **Description**: In `ApiClient`, when an endpoint returned 401 and no refresh token existed, it unconditionally invoked `await AppState.instance.logout()`. If a guest user encountered a 401 on an unauthenticated or protected endpoint, `logout()` was executed, which redundantly re-registered as a guest and notified all listeners.
- **Impact**: Unnecessary UI rebuilds and redundant guest registration network calls.
- **Remediation**: Check `if (AppState.instance.isLoggedIn) await AppState.instance.logout();` so guest sessions are untouched.

---

### [P3-01] Verbose Diagnostic Logging of Payloads in Debug Mode
- **Location**: `lib/services/api_service.dart` (line 477) and `lib/services/notification_service.dart` (line 117)
- **Subsystem**: Observability & Security
- **Description**: Raw article detail payloads and raw notification data were output via `debugPrint`. While stripped in release builds, in debug mode large payload dumps clutter the console.
- **Impact**: Console noise; risk of accidental exposure during local screen recordings.
- **Remediation**: Trim logs to output only IDs, status codes, and target types.

---

## 4. Summary of Findings Count

| Severity | Description | Count |
| :--- | :--- | :---: |
| **P0** | Crash / Data-Loss / Navigation-Lock / Security Critical | 2 |
| **P1** | Major User-Facing Failure / Inability to Complete Flow | 3 |
| **P2** | Degraded UX / Performance / Resource Leak | 3 |
| **P3** | Cleanup / Noncritical Diagnostic Logging | 1 |
| **Total** | | **9** |

---

## 5. Next Steps for Step 9

1. Prepare and submit `implementation_plan.md` for user approval with proposed targeted fixes.
2. Implement targeted hardening patches for all 9 findings without architectural changes or regressions to Steps 1–8.
3. Add end-to-end failure resilience tests (`test/production_reliability_test.dart`).
4. Validate with `flutter analyze`, `flutter test`, debug APK build, and release APK build.
5. Generate `docs/step9_test_matrix.md` and `docs/step9_release_readiness.md`.
