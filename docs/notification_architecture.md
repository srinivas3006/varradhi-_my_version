# VARADHI Notification & Deep-Link Architecture — Step 8

## 1. System Overview
Step 8 delivers an enterprise-grade Firebase Cloud Messaging (FCM), push notification handling, and deep-link routing architecture for the Vaaradhi Flutter mobile app.

The architecture integrates seamlessly with the STEP 5 navigation stack, enforces event-based navigation readiness during cold launch, centralizes all deep-link parsing into a robust resolver, and prevents route duplication or intent loss across app lifecycles.

---

## 2. Architecture & Control Flow

```text
[Triggers]
  FCM Foreground Push   │   FCM Background Push Tap   │   Terminated Launch Tap   │   External Deep Link (varadhi://)
          │                                  │                                │                        │
          ▼                                  ▼                                ▼                        ▼
   onMessage (In-app)               onMessageOpenedApp                getInitialMessage            Android Intent Filter
          │                                  │                                │                        │
          └──────────────────────────────────┴────────────────────────────────┴────────────────────────┘
                                             │
                                             ▼
                             NotificationDeepLinkResolver
                                             │
                                             ▼
                                     NotificationTarget
                   (article, category, poster, ugc, screen, unknown)
                                             │
                                             ▼
                                NotificationNavigationGate
                                (waits for HomeScreen readiness)
                                             │
                                             ▼
                                AppNavigator.pushSafe
                                             │
                                             ▼
                                 Root HomeScreen Shell
                           (always preserved underneath)
                                             │
                                             ▼
                     [NewsDetailScreen / CategoryScreen / PosterDetailScreen /
                      MyPostsScreen / BookmarksScreen / NotificationsScreen]
```

---

## 3. Deep-Link Specifications & Schemes

All deep links are resolved via the centralized `NotificationDeepLinkResolver`:

| Scheme / Pattern | Target Type | Identifier / Parameters | Example Destination Screen |
| :--- | :--- | :--- | :--- |
| `varadhi://category/{slug}` | `category` | `slug` (e.g. `education`, `politics`) | `CategoryScreen` |
| `varadhi:///category/{slug}` | `category` | Triple-slash fallback handled | `CategoryScreen` |
| `varadhi://article/{slug}` | `article` | `slug` or UUID | `NewsDetailScreen` |
| `article://{slug}` | `article` | `slug` or UUID | `NewsDetailScreen` |
| `/article/{slug}` | `article` | Relative path fallback | `NewsDetailScreen` |
| `varadhi://poster/{id}` | `poster` | `id` or UUID | `PosterDetailScreen` |
| `varadhi://ugc/reporter/dashboard`| `ugc` | `action: dashboard` (requires auth) | `MyPostsScreen` |
| `varadhi://ugc/submit` | `ugc` | `action: submit` (requires auth) | `CreatePostScreen` |
| `varadhi://ugc/{id}` | `ugc` | `id` | `NewsDetailScreen` |
| `screen://bookmarks` | `screen` | `bookmarks` (requires auth) | `BookmarksScreen` |
| `screen://notifications` | `screen` | `notifications` | `NotificationsScreen` |
| `screen://settings` | `screen` | `settings` | `NotificationSettingsScreen` |
| `screen://profile` | `screen` | `profile` (requires auth) | Profile / Settings |
| Malformed / Unknown | `unknown` | Gracefully ignored without crash | Safe no-op or root Home |

---

## 4. App Lifecycles & State Handling

### 4.1 Foreground State (`FirebaseMessaging.onMessage`)
- Messages are intercepted without launching system tray notifications.
- The app checks for duplicates using `_seenNotificationIds`.
- A floating in-app notification banner (`SnackBar`) displays `title` and `body`.
- Tapping the banner dismisses the banner and routes through `NotificationService.navigateToTarget`.

### 4.2 Background State (`FirebaseMessaging.onMessageOpenedApp`)
- Triggered when the user taps a system tray notification while the app is in the background or minimized.
- `message.data` is resolved into `NotificationTarget`.
- Target is pushed onto the existing navigation stack over `HomeScreen` via `AppNavigator.pushSafe`.

### 4.3 Terminated State (`FirebaseMessaging.instance.getInitialMessage()`)
- **The Problem**: If the app cold boots, navigating in `main()` or early postFrameCallback pushes the target screen over `SplashScreen`, only for `SplashScreen` to replace it with `HomeScreen` 600ms later, destroying the notification intent.
- **The Solution (`NotificationNavigationGate`)**:
  1. `initEarly()` checks `getInitialMessage()`.
  2. If present, it resolves the target and stores it in `NotificationNavigationGate.instance.setPendingTarget(target)`.
  3. `SplashScreen` runs its animation and pushes `HomeScreen`.
  4. In `HomeScreen.initState()`, it calls `NotificationService.instance.onNavigationReady(context)`.
  5. The gate dispatches the pending target on the next frame over the established `HomeScreen`.
  6. Back navigation from the target returns cleanly to `HomeScreen`.

---

## 5. FCM Token Management & Device Registration

- **Guest Registration**: If the user is unauthenticated, `ApiService.registerGuestDevice()` registers the device ID, location preferences, and FCM token at `POST /api/v1/notifications/guest-device/`.
- **Logged-in Registration**: When logged in, `ApiService.handoffDeviceToken()` registers the FCM token against the authenticated session at `POST /api/v1/notifications/device-token/`.
- **Token Refresh**: `messaging.onTokenRefresh` listens for token changes and updates the backend via `ApiService.updateFcmToken()`.
- **Security**: Raw tokens are never logged to debug output or exposed to users.

---

## 6. Auth-Protected Notifications

- When a target specifies `requiresAuth: true` (e.g. `varadhi://ugc/reporter/dashboard` or `screen://bookmarks`):
  1. If `AppState.instance.isLoggedIn == true`, navigation proceeds directly.
  2. If the user is a guest, `AppNavigator.pushSafe` opens `AccountLoginScreen`.
  3. If authentication succeeds, the original requested target is executed immediately.
  4. If the user dismisses the login screen, the intent is cancelled without redirecting away from `HomeScreen`.

---

## 7. Android Native Configuration

### 7.1 AndroidManifest.xml
- Added `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` for Android 13+ (API 33+) support.
- Added custom scheme intent filter:
  ```xml
  <intent-filter>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="varadhi" />
  </intent-filter>
  ```

---

## 8. Testing Matrix

| Test Suite | Scenarios Verified | Result |
| :--- | :--- | :--- |
| **Deep Link Resolution** | `varadhi://category/education`, query parameters, triple slashes, `article://`, relative `/article/`, `poster://`, `ugc://`, `screen://`, malformed URIs, unknown schemes | **PASS** (11 tests) |
| **FCM Payload Parsing** | Payload with explicit `deep_link`, payload with `content_type` and slug, payload with poster, AppNotification model conversion | **PASS** (4 tests) |
| **Navigation Readiness Gate** | Pending target storage during cold boot, exactly-once consumption, widget frame dispatch | **PASS** (2 tests) |
| **Full Regression Suite** | 155 total unit and widget tests covering all subsystems | **PASS** (155 tests) |
| **Static Analysis** | `flutter analyze` | **PASS** (0 issues) |
| **Build Verification** | Debug and Release APK builds | **PASS** |
