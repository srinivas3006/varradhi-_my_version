# Step 10 — Production Release, Security, Observability & Store Readiness Audit

**Audit Date**: September 11, 2026  
**Project**: VARADHI Flutter Mobile Application  
**Package / App ID**: `com.vaaradhi.vaaradhi`  
**Package Name in pubspec**: `way2news_clone`  
**Version**: `1.0.0+1` (Version Name: `1.0.0`, Version Code: `1`)  

---

## 1. Project Configuration & Build System Inspection

### 1.1 Pubspec Configuration
- **Dart SDK**: `sdk: '>=3.0.0 <4.0.0'`
- **Target Platform**: Android (SDK 24+ through Android 15 / API 35)
- **External Dependencies**:
  - `firebase_core`: `^4.11.0`
  - `firebase_messaging`: `^16.4.1`
  - `flutter_secure_storage`: `^10.3.1`
  - `dio`: `^5.10.0`
  - `shared_preferences`: `^2.5.5`
  - `video_player`: `^2.12.0`
  - `visibility_detector`: `^0.4.0+2`
  - `geolocator`: `^14.0.3`
  - `geocoding`: `^5.0.0`
  - `image_picker`: `^1.2.3`
  - `url_launcher`: `^6.3.2`
  - `cached_network_image`: `^3.4.1`
  - No extraneous or speculative libraries added.

### 1.2 Android Gradle Configuration
- **Application ID / Namespace**: `com.vaaradhi.vaaradhi`
- **Compile SDK**: Flutter default (API 35 / Android 15)
- **Target SDK**: Flutter default (API 34/35)
- **Min SDK**: API 24 (Android 7.0 Nougat)
- **Java / JVM Target**: Java 17 (`JavaVersion.VERSION_17`, `JvmTarget.JVM_17`)
- **Build Types**:
  - `debug`: Standard Flutter debug profile
  - `release`: `signingConfig` uses debug keys as fallback; `isMinifyEnabled = false`
- **Gradle Wrapper**: 8.x with Kotlin DSL (`build.gradle.kts`, `settings.gradle.kts`)

### 1.3 Firebase Project Verification
- **Project ID**: `vaaradhi-8e964` (Verified production Firebase project)
- **Project Number**: `730020121705`
- **Storage Bucket**: `vaaradhi-8e964.firebasestorage.app`
- **Mobile App ID**: `1:730020121705:android:d4973c1dadadb21be626f8`
- **Client Package**: `com.vaaradhi.vaaradhi` (Matches `applicationId` exactly)
- **Google Services Plugin**: `com.google.gms.google-services` applied cleanly in `android/app/build.gradle.kts`

---

## 2. Production Environment & String Audit

A complete grep search across all Dart and configuration files yielded:
- **`localhost`**: 0 occurrences in `lib/`
- **`127.0.0.1`**: 0 occurrences in `lib/`
- **`10.0.2.2`**: 0 occurrences in `lib/`
- **`192.168.`**: 0 occurrences in `lib/`
- **`example.com`**: 1 occurrence in `url_normalizer.dart` (purely in doc comment: `// Handle protocol-relative URLs (e.g. "//cdn.example.com/image.jpg")`)
- **`staging`**: Only defined as an enum variant in `AppConfig.environment`
- **`mock`**: 1 occurrence in `app_state.dart` doc comment explaining that login *never* falls back to mock states
- **`dummy`**: 1 occurrence in `banner_ad_slot.dart` doc comment
- **`fake`**: Occurs only in admin rejection reason string (`'Fake or unverifiable content.'`) and location verification comment in `ugc_controller.dart`

**Conclusion**: Zero test, mock, dummy, or local development URLs exist in runtime execution paths.

---

## 3. Production API Configuration

- **Base URL**: `https://incite-backend.onrender.com` (Strict HTTPS)
- **Timeouts**:
  - `connectTimeout`: 35 seconds
  - `sendTimeout`: 35 seconds
  - `receiveTimeout`: 35 seconds
- **Max Retries**: 3 with exponential backoff on idempotency-safe requests
- **Logging**: `NetworkLoggerInterceptor` is wrapped in `if (!kDebugMode) return;` across `onRequest`, `onResponse`, and `onError`. In release mode, network logging is completely suppressed.
- **Certificate Validation**: Standard system CA validation used. No `badCertificateCallback`, no `TrustManager` bypass, no insecure hostname verifiers.

---

## 4. Secret & Credential Audit

- **Hardcoded API Keys**: None in Dart source code.
- **Firebase Private Keys**: None committed. Only standard public client identifiers in `google-services.json`.
- **Signing Credentials**: No `key.properties`, `.jks`, or `.keystore` files committed to repository.
- **Tokens**: `authToken`, `refreshToken`, and `installationSecret` are dynamically acquired from the backend and stored in hardware-backed `FlutterSecureStorage`.
- **Sensitive Key Redaction**: `NetworkLoggerInterceptor` explicitly redacts keys matching `password`, `token`, `access`, `refresh`, `otp`, `secret`, `installation_secret`, and `authorization`.

---

## 5. Android Manifest & Permission Minimization

Declared Permissions in `android/app/src/main/AndroidManifest.xml`:
1. `android.permission.INTERNET`: Core networking (Feed, Articles, Media, Ads, UGC, Notifications).
2. `android.permission.ACCESS_NETWORK_STATE`: Connectivity monitoring for offline cache fallback.
3. `android.permission.ACCESS_FINE_LOCATION`: UGC Citizen Reporter location tagging (requested at runtime).
4. `android.permission.ACCESS_COARSE_LOCATION`: UGC Citizen Reporter coarse location fallback.
5. `android.permission.POST_NOTIFICATIONS`: Android 13+ (API 33+) push notification permission.

**Audit Assessment**: Every declared permission has a direct, active runtime purpose. Zero unnecessary permissions (such as `READ_EXTERNAL_STORAGE` or `WRITE_EXTERNAL_STORAGE`) are present.

### Security Enhancements Identified:
- `android:usesCleartextTraffic="true"` is currently enabled. Because the production backend and all media assets utilize HTTPS, this must be removed/disabled to prevent cleartext HTTP transmission on Android 9+.
- `android:label` is currently `"Vaaradhi"`. Should be updated to `"VARADHI"` for consistent store branding.

---

## 6. Deep-Link & Intent Filter Security

- **Custom Scheme**: `varadhi://` declared in `AndroidManifest.xml` with `android.intent.action.VIEW`, `DEFAULT`, `BROWSABLE`.
- **Resolver Hardening**: `NotificationDeepLinkResolver` strictly parses URI path segments (`article`, `category`, `poster`, `ugc`, `screen`).
- **Validation**: Rejects malformed URIs, unknown schemes, and empty paths without exceptions.
- **Authentication**: Protected destinations (e.g., `varadhi://ugc/submit`, `screen://bookmarks`) require authenticated session; unauthenticated guests are routed to `AccountLoginScreen` before forwarding.
- **Executable Code**: No deep link parameter can execute code or inject scripts.

---

## 7. External URL & WebView Audit

- **WebView**: Zero WebView widgets or plugins exist in the codebase.
- **External URL Launching**: Handled via `url_launcher`:
  - Ad clicks launch externally via `LaunchMode.externalApplication` (system browser).
  - Ad booking screen uses `tel:` and WhatsApp `https://wa.me/` via `LaunchMode.externalApplication`.
  - No arbitrary JavaScript execution or in-app WebViews exist.

---

## 8. UGC Privacy & Media Security

- **Local Storage**: UGC drafts are saved in private application storage (`.varadhi_ugc_draft.json`).
- **Media Handling**: Captured photos/videos use paths from system `image_picker` stored in private app cache.
- **Draft Preservation**: Incomplete or failed uploads preserve local drafts for user retry without data loss.
- **Path Traversal Protection**: Media filenames are not used as file system traversal paths.

---

## 9. Logging & Observability Audit

- `NetworkLoggerInterceptor`: Strips all sensitive headers, bodies, passwords, and tokens. Completely disabled in release builds (`!kDebugMode`).
- `debugPrint`: Development logging uses `debugPrint`, stripped or suppressed in release execution.
- **Crash Reporting**: `CRASH REPORTING: NOT CURRENTLY CONFIGURED`. No Firebase Crashlytics or Sentry plugin is installed. Global framework and platform dispatcher error handling must be added in `main.dart` for graceful UI error fallback.

---

## 10. Signing & Play Store Readiness

- **Production Signing**: `PRODUCTION SIGNING: NOT CONFIGURED`. Release builds currently sign with debug keys as a fallback for local evaluation. Production deployment requires a client-managed Keystore file and `key.properties`.
- **Play Store Requirements**: Requires privacy policy URL, store screenshots, and Data Safety form completion by the app owner.
