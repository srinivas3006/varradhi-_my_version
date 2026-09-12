# VARADHI Notification & Deep-Link Architecture Audit — Step 8

## Executive Summary
This audit inspects the existing Firebase Cloud Messaging (FCM), push notification handling, device token registration, notification inbox synchronization, deep-link parsing, and navigation routing in the Vaaradhi Flutter application prior to implementing Step 8.

---

## 1. Codebase Inventory & Search Audit

A complete search was performed across the project for Firebase and notification-related keywords:

| Search Term | Occurrences | Key Locations | Current Status |
| :--- | :--- | :--- | :--- |
| `firebase_core` | `pubspec.yaml` | `pubspec.yaml:27` | Installed (`^4.11.0`). |
| `firebase_messaging` | `pubspec.yaml` | `pubspec.yaml:28` | Installed (`^16.4.1`). |
| `Firebase.initializeApp` | 2 locations | `notification_service.dart:16, 44` | Initialized in `initEarly` and background handler. |
| `FirebaseMessaging` | 6 locations | `notification_service.dart` | Used for `onMessage`, `onMessageOpenedApp`, `onBackgroundMessage`, `getInitialMessage`, `onTokenRefresh`. |
| `getToken` | 1 location | `notification_service.dart:139` | Called during deferred permission request. |
| `onTokenRefresh` | 1 location | `notification_service.dart:50` | Listens to token refreshes and calls `ApiService.instance.updateFcmToken`. |
| `onMessage` | 1 location | `notification_service.dart:56` | Listens to foreground messages and displays floating SnackBar. |
| `onBackgroundMessage` | 1 location | `notification_service.dart:45` | Registers top-level `firebaseMessagingBackgroundHandler`. |
| `getInitialMessage` | 1 location | `notification_service.dart:111` | Calls `getInitialMessage()` on early init, but uses raw `postFrameCallback` before `HomeScreen` is mounted. |
| `onMessageOpenedApp` | 1 location | `notification_service.dart:105` | Listens for system tray taps when app is in background. |
| `RemoteMessage` | 4 locations | `notification_service.dart` | Message payload type. |
| `deep_link` / `deepLink` | 10+ locations | `notification_service.dart`, `notifications_screen.dart`, `app_notification.dart`, backend docs | Parsed manually via ad-hoc string checks. |
| `Uri` | 0 locations | None | No structured URI parsing currently used; string slicing used instead. |
| `app_links` / `uni_links` | 0 locations | None | Not installed; default Flutter deep linking / custom scheme to be used. |
| `varadhi://` | Multiple docs | `appcode.md`, `swagger.json`, `fullprojectapidocument.md` | Specified in backend contract as the primary custom scheme (`varadhi://category/education`, etc.). |
| `notification` | 50+ locations | `notification_service.dart`, `api_service.dart`, `notifications_screen.dart`, `notification_settings_screen.dart` | Inbox, preferences, guest device registration. |

---

## 2. Firebase & Android Native Configuration Audit

### 2.1 Android Configuration Files
- `android/app/google-services.json`: **Present and verified**.
  - Project ID: `vaaradhi-8e964`
  - Package name: `com.vaaradhi.vaaradhi`
- `android/settings.gradle.kts`: **Present and verified**.
  - `id("com.google.gms.google-services") version "4.4.2" apply false`
- `android/app/build.gradle.kts`: **Present and verified**.
  - `id("com.google.gms.google-services")` is applied.
  - `applicationId`: `com.vaaradhi.vaaradhi`
  - `minSdk = flutter.minSdkVersion` (21+)
  - `targetSdk = flutter.targetSdkVersion` (34+)
- `android/app/src/main/AndroidManifest.xml`:
  - **Missing**: `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` for Android 13+ (API 33+).
  - **Missing**: Intent filter for `varadhi://` custom URI scheme.

---

## 3. Component-by-Component Audit

### 3.1 `main.dart` & Application Bootstrap
- `main()` calls:
  1. `WidgetsFlutterBinding.ensureInitialized()`
  2. `SystemChrome.setPreferredOrientations(...)`
  3. `NotificationService.instance.initEarly(messengerKey: ..., navigatorKey: ...)`
  4. `AppState.instance.init()`
  5. `runApp(const Way2NewsCloneApp())`
- **Current Issue**: In `initEarly`, `getInitialMessage()` is checked and uses `WidgetsBinding.instance.addPostFrameCallback((_) { handleNotificationPayload(initialMessage.data); });`.
  - At this exact moment, `SplashScreen` is being pushed as `home`.
  - The postFrameCallback executes while `SplashScreen` is animating, pushing `NewsDetailScreen` over the splash screen.
  - When `SplashScreen` finishes 600ms later, it calls `Navigator.of(context).pushReplacement(HomeScreen())`, completely blowing away or duplicating the route!
  - **Solution Required**: Implement an explicit `NavigationReadiness` gate. When opened from terminated state, store `pendingTarget`. When `HomeScreen` mounts and signals readiness, consume the initial target exactly once.

### 3.2 `notification_service.dart`
- **Background Handler**:
  - `firebaseMessagingBackgroundHandler` is annotated with `@pragma('vm:entry-point')`.
  - Safe for release builds; does not perform UI navigation.
- **Foreground Handler**:
  - Shows an in-app floating `SnackBar` banner with title and body.
  - Deduplicates via `_seenNotificationIds`.
- **Background Tap Handler**:
  - `onMessageOpenedApp` calls `handleNotificationPayload(message.data)`.
- **Payload Parsing (Deficiency)**:
  - Ad-hoc `if/else` string checks on `contentType` and `deepLink`.
  - Does not support `varadhi://category/...` scheme.
  - Does not support `varadhi://article/...`, `varadhi://poster/...`, `varadhi://ugc/...`, or `screen://...`.
  - No structured `NotificationTarget` model.
  - Does not mark notifications as read when tapped from push payload.

### 3.3 Deep Link Routing & STEP 5 Navigation Architecture
- STEP 5 introduced `AppNavigator.pushSafe`, debouncing rapid taps and enforcing root `HomeScreen` stability.
- Currently, `NotificationService` calls `Navigator.push(...)` directly using `MaterialPageRoute`, bypassing `AppNavigator.pushSafe` and risking duplicate screens on rapid taps.
- In `notifications_screen.dart`, tap handlers also duplicate manual navigation instead of delegating to a centralized resolver.

### 3.4 Device Registration (`ApiService`)
- `registerGuestDevice`: `POST /api/v1/notifications/guest-device/` with device info, location, preferences, and FCM token. Handles 403 / installation upgrade cleanly.
- `handoffDeviceToken`: `POST /api/v1/notifications/device-token/` for logged-in users.
- `updateFcmToken`: Centrally routes between guest and logged-in device token registration.
- **Contract is stable and production-ready**.

### 3.5 Notification Inbox (`notifications_screen.dart` & `app_state.dart`)
- `GET /api/v1/notifications/inbox/`
- `GET /api/v1/notifications/inbox/unread-count/`
- `POST /api/v1/notifications/inbox/{id}/read/`
- Functions properly with `AppState.instance.notifications` and unread counters.

---

## 4. Gap Analysis & Required Solutions for Step 8

| # | Identified Defect / Gap | Impact | Step 8 Resolution |
| :--- | :--- | :--- | :--- |
| 1 | `AndroidManifest.xml` missing `POST_NOTIFICATIONS` | Push notifications fail silently on Android 13+ (API 33+) | Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`. |
| 2 | `AndroidManifest.xml` missing custom scheme intent filter | External `varadhi://` links fail to open the application | Add `<intent-filter>` with `ACTION_VIEW`, `BROWSABLE`, scheme `varadhi`. |
| 3 | Terminated state race with `SplashScreen` | Push notification screen gets replaced by `HomeScreen` | Add `NotificationNavigationGate` / `navigationReady` signal from `HomeScreen`. |
| 4 | Fragmented deep-link parsing | Duplicate, fragile string replacement in multiple files | Create `NotificationDeepLinkResolver` producing typed `NotificationTarget`. |
| 5 | Unhandled `varadhi://category/...` links | Category notifications fail or open wrong screen | Parse category slug and route to `CategoryScreen` on top of `HomeScreen`. |
| 6 | Unhandled `screen://...` links | Screen shortcuts fail | Resolve `screen://bookmarks`, `screen://notifications`, `screen://profile`, etc. |
| 7 | Direct `Navigator.push` without debouncing | Double tapping notification creates duplicate screens | Use `AppNavigator.pushSafe` for all notification destinations. |
| 8 | Auth-protected notification drops intent | User logs in, but is redirected to Home, losing intent | Store `pendingIntent` during auth challenge, restore upon successful login. |
| 9 | Notification not marked as read on push tap | Notification remains marked unread in inbox | Call `ApiService.instance.markNotificationRead` asynchronously on tap. |

---

## 5. Media & Packages Verification
- `firebase_core: ^4.11.0` and `firebase_messaging: ^16.4.1` are verified in `pubspec.yaml` and `pubspec.lock`.
- No new external packages (e.g. `go_router`, `uni_links`) are needed. Built-in Uri parsing and existing navigation architecture will be used.
