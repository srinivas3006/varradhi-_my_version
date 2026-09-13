# Varradhi (DailyBuzz) — Mobile Application

A production-grade, full-featured Telugu & English news aggregation and citizen journalism platform built with Flutter. Wired to live REST APIs with realistic fallbacks, offline caching, and responsive interactions.

---

## 📱 Spotlight Reading Experience (Core Architecture)

The Spotlight screen is designed for a distraction-free, immersive reading experience:

### 1. Navigation Rule (Strict)
- **"Read More" Exclusive Navigation**: Tapping the news card or preview text will **NEVER** navigate away. Full article screen opens **ONLY** when the user taps the dedicated **"Read More"** (`'ఇంకా చదవండి' : 'Read More'`) button.
- **Preview Text**: Strict 300-character preview truncation with clean word-boundary cuts.

### 2. Overlays & Auto-Hide Behavior
- **Screen Tap Interaction**: Tapping anywhere on the screen toggles overlay visibility on/off.
- **Auto-Hide Logic**: Floating overlays automatically fade out after 3–4 seconds of inactivity.
- **Interactivity Reset**: Touching any overlay control resets the 4-second auto-hide countdown.

### 3. Top Floating Overlay
- **Profile Icon**: Quick-access button opening profile, bookmarks, and account settings.
- **Main / Local News Toggle**: Sliding animated pill switching between Main and Local feeds.
- **Dynamic Location Chip**: Interactive chip displaying current district/city with a location picker bottom sheet.
- **Post (+) Button**: Instant shortcut to citizen journalism / UGC post creation flow.

### 4. Bottom Floating Overlay
- Compact frosted-glass pill floating above the bottom edge.
- **Back Button**: Exits spotlight reading and smoothly returns to the home feed.
- **Reload Button**: Refreshes feed with haptic feedback and resets overlay timer.

### 5. In-Article Action Bar (Non-Floating, Inside Card)
All core article actions are pinned directly inside the article card:
- **Like**: Displays live count, highlights in red when liked, syncs with backend.
- **Dislike**: Dislike toggle with feedback snackbar confirmation.
- **Share**: Prominent center button triggering native Android/iOS share with deep-link generation.
- **Comment**: Displays live comment count and opens the interactive comment sheet/screen.
- **Save / Bookmark**: Toggles bookmark status with instant API synchronization.
- **TTS Audio Chip & Speed Control**: Sentence-level chunking engine (350-400 chars) ensuring zero audio cut-offs on long articles, smooth continuous playback with error auto-recovery, and speed control (1.0x, 1.25x, 1.5x).

---

## 🛠️ Complete 27-Screen Matrix (from `appcode.md`)

| # | Screen | Description & Connected APIs |
|---|---|---|
| **01** | `SplashScreen` | Health check, guest device registration, auth check (`/api/v1/auth/me/`) |
| **02** | `LoginScreen` | Phone & Password / OTP login (`/api/v1/auth/login/`) |
| **03** | `RegisterScreen` | New user account creation with language selection (`/api/v1/auth/register/`) |
| **04** | `ForgotPasswordScreen` | Password reset request with phone/email verification (`/api/v1/password/reset/request/`) |
| **05** | `ResetPasswordTokenScreen`| OTP verification step for password recovery (`/api/v1/password/reset/verify/`) |
| **06** | `ResetPasswordConfirmScreen`| Set new password and redirect to login (`/api/v1/password/reset/confirm/`) |
| **07** | `HomeScreen` | Main app shell hosting category tabs, reels, local news, notifications, and profile |
| **08** | `CategoryScreen` | Filtered articles by category (`/api/v1/articles/feed/`) |
| **09** | `ArticleDetailScreen` | Full article view with web view, related articles, comments, and TTS |
| **10** | `SpotlightScreen` | Vertical flip feed with auto-hide overlays, 300-char preview, and in-article actions |
| **11** | `LocationPromptSheet` | Location permission, district/mandal selector, and reverse geocoding |
| **12** | `LocalNewsScreen` | Location-targeted feed with mandal/district chips |
| **13** | `VideoFeedScreen` | Fullscreen vertical reels/shorts video feed (`/api/v1/shorts/feed/`) |
| **14** | `SearchScreen` | Real-time search with trending tags and recent search history |
| **15** | `CreatePostScreen` | Citizen journalism UGC posting with image upload, category, and location |
| **16** | `MyPostsScreen` | Reporter's personal post list with status badges (Pending, Approved, Rejected) |
| **17** | `AdminUgcModerationScreen`| Admin review queue for reviewing, approving, and rejecting citizen reports |
| **18** | `CommentsScreen` | Nested comments bottom sheet with posting and like toggles |
| **19** | `PollsListScreen` | Community opinion polls with real-time percentage graphs |
| **20** | `PreferencesScreen` | Topic and category preference personalization (`/api/v1/users/preferences/`) |
| **21** | `NotificationsScreen` | Inbox notifications with deep-links, thumbnail preview, and mark-as-read |
| **22** | `NotificationSettingsScreen`| Granular push notification preferences (Breaking, Live, Quiet Hours) |
| **23** | `BookmarksScreen` | Saved articles collection with offline cache and undo unbookmarking |
| **24** | `ProfileScreen` | User profile, reporter status, coins balance, admin moderation entry point |
| **25** | `SettingsScreen` | App settings (Theme mode, Font-size slider, Language, CMS links) |
| **26** | `RewardsScreen` | Signature red gradient wallet card (5549 coins), ₹ cash estimate, UPI withdrawal |
| **27** | `CMSPageScreen` | Dynamic legal & information pages (`/api/v1/cms/{slug}/`) |

---

## 🎨 UI & Design Highlights

- **Aesthetic**: Premium modern design with dark mode, frosted glassmorphism blur effects (`ImageFilter.blur`), smooth curve animations, and tailored color palette.
- **Haptic Feedback**: Integrated haptic feedback on likes, tab toggles, reload, and button presses.
- **Admin Privileges**: Automatic role detection—admin accounts receive the UGC Moderation panel while suppressing the reporter onboarding card.
- **Reporter Wallet**: High-fidelity Red Gradient reward card with yellow progress bar and coins-to-rupees conversion rate.
- **Live Broadcast Strict 3-State Logic**: Clean separation between (1) Active Live card with red pulse, (2) Upcoming Live banner with scheduled countdown, and (3) Complete section hiding when no live stream exists (zero random YouTube fallbacks).

---

## 🚀 Running the Project

```bash
# Get dependencies
flutter pub get

# Run static analysis
dart analyze

# Run on connected device or emulator
flutter run

# Build release APK
powershell -ExecutionPolicy Bypass -File .\build_release.ps1
```
