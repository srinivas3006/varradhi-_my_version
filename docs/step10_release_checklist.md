# Step 10 Final Release Checklist

**Application**: VARADHI  
**Package**: `com.vaaradhi.vaaradhi`  
**Version**: `1.0.0+1` (`versionName = 1.0.0`, `versionCode = 1`)  

---

## 1. Release Item Verification Checklist

| Domain | Verification Item | Specification / Requirement | Audit Verification | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Code** | Flutter Analyze | 0 errors, 0 warnings, 0 lints | Validated via `flutter analyze` | **PASS** |
| **Code** | Automated Test Suite | All tests passing across all suites | Validated via `flutter test` (169/169 tests) | **PASS** |
| **API** | Production Base URL | Strict HTTPS (`https://incite-backend.onrender.com`) | Verified in `AppConfig` and `NetworkConfig` | **PASS** |
| **API** | Localhost / Test URLs | Zero localhost, 127.0.0.1, or 10.0.2.2 in runtime | Verified via full codebase grep | **PASS** |
| **Firebase** | Production Project | `vaaradhi-8e964` matching package `com.vaaradhi.vaaradhi` | Verified in `google-services.json` | **PASS** |
| **Firebase** | FCM Configuration | Background and foreground messaging handlers configured | Verified in `NotificationService` | **PASS** |
| **Security** | Cleartext Traffic | `android:usesCleartextTraffic="false"` (Enforce TLS) | Configured in `AndroidManifest.xml` | **PASS** |
| **Security** | Secrets & Keys | No API keys, passwords, or service account JSON committed | Verified via repository secret audit | **PASS** |
| **Security** | Token Storage | Tokens stored in hardware-backed `FlutterSecureStorage` | Verified in `AppState` with KeyStore recovery | **PASS** |
| **Permissions** | Permission Minimization | Only 5 active permissions declared in Manifest | Verified: INTERNET, NETWORK_STATE, 2x LOCATION, NOTIFICATIONS | **PASS** |
| **Deep Links** | Scheme & Intent Filter | `varadhi://` declared with standard browsable intent filter | Verified in `AndroidManifest.xml` | **PASS** |
| **Deep Links** | Deep Link Resolver | Type-safe resolution with invalid/empty fallback | Verified in `NotificationDeepLinkResolver` | **PASS** |
| **Notifications** | Cold-Start Deep Linking | Terminated notification dispatch deferred until Home mounts | Verified in `NotificationNavigationGate` | **PASS** |
| **Notifications** | Android 13+ Compliance | One-time gentle permission request persisted in prefs | Verified in `NotificationService` | **PASS** |
| **UGC** | Multipart Upload & Progress | Two-stage submission (metadata then media upload) | Verified in `UgcRepository` | **PASS** |
| **UGC** | Cancellation & Retry | Fast cancellation via `CancelToken`; recoverable draft | Verified in `UgcController` | **PASS** |
| **Video** | Background Handling | Video pauses immediately when scrolled away or backgrounded | Verified in `VideoPlaybackController` | **PASS** |
| **Ads** | Frequency & Capping | Daily caps, anti-repetition rotation, session limits | Verified in `AdManager` | **PASS** |
| **Ads** | Offline Queue Safety | Capped at 50 events max with FIFO eviction | Verified in `AdEventQueue` | **PASS** |
| **Navigation** | Android Back & Predictive | Deterministic tab pop, root exit prompt, no stack drift | Verified in `HomeScreen` & `AppNavigator` | **PASS** |
| **Performance** | Memory & Leaks | Controllers disposed; images bounded; no zombie timers | Verified in `comments_screen`, `profile_tab` | **PASS** |
| **Logging** | Production Sanitization | Sensitive headers/tokens redacted; network logging off in release | Verified in `NetworkLoggerInterceptor` | **PASS** |
| **Observability** | Global Error Boundaries | Framework & platform dispatcher handlers configured | Configured in `main.dart` | **PASS** |
| **Versioning** | Version Name & Code | `versionName: 1.0.0`, `versionCode: 1` | Verified in `pubspec.yaml` & Gradle | **PASS** |
| **Branding** | App Label & Title | `android:label="VARADHI"`, `MaterialApp.title = "VARADHI"` | Verified in `AndroidManifest.xml` & `main.dart` | **PASS** |
| **Build** | Debug APK Build | `flutter build apk --debug` builds cleanly | Verified (Build succeeded) | **PASS** |
| **Build** | Release APK Build | `flutter build apk --release` builds cleanly | Verified (70.2MB Release APK generated) | **PASS** |
| **Build** | Release App Bundle (AAB) | `flutter build appbundle --release` builds cleanly | Verified (66.3MB Release AAB generated) | **PASS** |
| **Signing** | Production Release Keystore | Hardware signing key configured for Google Play Console | `PRODUCTION SIGNING: NOT CONFIGURED` (Debug key fallback) | **BLOCKED (OWNER INPUT)** |
| **Store** | Privacy Policy URL | Publicly accessible privacy policy hosted online | Required for Google Play Console submission | **NEEDS OWNER INPUT** |
| **Store** | Store Listing Assets | Feature graphic (1024x500), screenshots, icon | Required for Google Play Console submission | **NEEDS OWNER INPUT** |
| **Store** | Data Safety Declaration | App permissions and data collection declarations | Ready to map from audited permissions | **NEEDS OWNER INPUT** |
