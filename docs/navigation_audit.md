# Navigation Audit — Vaaradhi Flutter Application

**Date:** 2026-09-11  
**Project:** Vaaradhi (Flutter Android Client)  
**Audit Purpose:** Comprehensive assessment of navigation hierarchy, route stacks, Android back button handling, predictive back compatibility, modal priority, and lifecycle state management prior to Step 5 implementation.

---

## 1. Current Navigation Architecture Overview

The Vaaradhi mobile application currently uses a **hybrid navigation architecture**:
- **Root Container:** A top-level `MaterialApp` with `navigatorKey` and `home: const SplashScreen()`.
- **Primary Shell:** `HomeScreen` hosting a 5-tab `IndexedStack` (`NewsFeedTab`, `LocalNewsTab`, `CreatePostScreen`, `VideoTab`, `ProfileTab`) with custom `BottomNavBar`.
- **Secondary Routes:** Pushed onto the root `Navigator` using direct `MaterialPageRoute` or custom `PageRouteBuilder` transitions.
- **Modals & Overlays:** Displayed via `showDialog`, `showModalBottomSheet`, and fullscreen `PageRoute` instances.

---

## 2. Exhaustive Audit of Navigation Sites

### 2.1 Pushes (`Navigator.push` / `Navigator.of(context).push`)
| File & Line | Target Route | Invocation Trigger | Issue Identified |
|---|---|---|---|
| `splash_screen.dart:79` | `SpotlightScreen()` | Splash bootstrap finished (`pushReplacement`) | Spotlight pushed as root instead of `HomeScreen` |
| `news_feed_tab.dart:499` | `SpotlightScreen()` | App bar Spotlight icon tap | Navigates to Spotlight; closing it recreates `HomeScreen` |
| `news_feed_tab.dart:533, 821` | `NewsDetailScreen()` | Card tap / Trending rail tap | Vulnerable to rapid-tap duplicate pushes |
| `trending_rail_card.dart:48` | `NewsDetailScreen()` | Trending item tap | Vulnerable to rapid-tap duplicate pushes |
| `local_news_tab.dart:142` | `LocationSelectionScreen()` | Location chip tap | `await push<bool>` correctly consumes boolean result |
| `local_news_tab.dart:234` | `UgcFeedScreen()` | Citizen journalism banner tap | Direct push |
| `local_news_tab.dart:349` | `NewsDetailScreen()` | Local article card tap | Direct push |
| `news_detail_screen.dart:624` | `CommentsScreen()` | Comments metric pill tap | Stacked route; pops cleanly to article |
| `news_article_video_player.dart:120` | `VideoPlayerScreen()` | Fullscreen video button tap | Standalone video route |
| `profile_tab.dart:227` | `SettingsScreen()` | Profile settings tile tap | Direct push |
| `home_screen.dart:44` | `AccountLoginScreen()` | Bottom nav tap on Create (tab 2) when unauthenticated | Missing callback to switch to tab 2 upon successful login |
| `settings_screen.dart:162` | `PreferencesScreen()` | Category preferences tile | Direct push |
| `settings_screen.dart:174` | `NotificationSettingsScreen()` | Notifications settings tile | Direct push |
| `notification_service.dart:194, 223, 244` | `NewsDetailScreen()` / `PosterDetailScreen()` | Notification click payload | Pushes to root navigator |
| `interstitial_ad_overlay.dart:32` | Ad overlay route | Interstitial ad display | Transparent fullscreen route |

### 2.2 Replacements (`Navigator.pushReplacement` & `Navigator.pushAndRemoveUntil`)
| File & Line | Target Route | Context / Flow | Flaw Analysis |
|---|---|---|---|
| `spotlight_screen.dart:145` | `HomeScreen()` | `_closeSpotlight()` called | **CRITICAL BUG**: When Spotlight is opened from `HomeScreen`, closing it replaces Spotlight with a *new* `HomeScreen`, creating duplicate stacked `HomeScreen` instances (`[HomeScreen, HomeScreen]`). |
| `account_login_screen.dart:91` | `SpotlightScreen()` | Login success when `!canPop()` | Pushes `SpotlightScreen` instead of `HomeScreen`, leading to another `HomeScreen` re-instantiation. |
| `account_signup_screen.dart:118` | `SpotlightScreen()` | Signup success (`pushAndRemoveUntil`) | Resets root to `SpotlightScreen` instead of `HomeScreen`. |
| `location_selection_screen.dart:95, 175, 195` | `SpotlightScreen()` | Location selected/skipped when `!canPop()` | Drops to `SpotlightScreen` instead of `HomeScreen`. |
| `language_screen.dart:232, 254` | `SpotlightScreen()` | Language chosen/skipped when `!canPop()` | Drops to `SpotlightScreen` instead of `HomeScreen`. |
| `reset_password_confirm_screen.dart:61` | `AccountLoginScreen()` | Password reset completed | Uses `pushAndRemoveUntil((route) => route.isFirst)`. |

### 2.3 Android Back & PopScope Inspection
| Location | Current Back Handling | Evaluation |
|---|---|---|
| `home_screen.dart` | **None** (No `PopScope` or back handler) | **CRITICAL BUG**: Pressing Android back when on Tab 1, 2, 3, or 4 instantly terminates the application instead of switching to Tab 0 (News). Pressing back on Tab 0 exits immediately without double-back confirmation. |
| `spotlight_screen.dart:673` | `PopScope(canPop: false, onPopInvokedWithResult: ...)` | Calls `_closeSpotlight()` which calls `pushReplacement(HomeScreen())`. Breaks predictive back because `canPop: false`. |
| `create_post_screen.dart` | `AppBar(leading: close icon)` calling `Navigator.pop(context)` | No `PopScope` guarding unsaved user input. If the user drafts an article and presses system back, content is discarded without confirmation. |
| Other secondary screens | Flutter default `ModalRoute` pop | Works for standard single pops, but lacks duplicate tap protection and predictive back manifest opt-in. |

### 2.4 Modals & Sheets (`showDialog` & `showModalBottomSheet`)
| Component | Usage | Back Priority Verification |
|---|---|---|
| `spotlight_screen.dart` | `LocationPromptSheet` (`showModalBottomSheet`) | Native `PopupRoute` gets first back priority. Handled safely. |
| `comments_screen.dart` | Comment options & report dialogs (`showDialog`, `showModalBottomSheet`) | Native `PopupRoute` gets first back priority. Handled safely. |
| `settings_screen.dart` | Logout confirmation dialog (`showDialog`) | Native `PopupRoute` gets first back priority. Handled safely. |
| `profile_tab.dart` | Logout confirmation & Avatar picker sheet | Native `PopupRoute` gets first back priority. Handled safely. |
| `interstitial_ad_overlay.dart` | Interstitial route | Closed with `Navigator.pop()`. Handled safely. |

---

## 3. Core Problems & Root Causes

### 3.1 The Spotlight ↔ Home Stack Duplication Loop
The root navigation flow was circular:
```
Splash -> pushReplacement(Spotlight) -> Close -> pushReplacement(Home)
NewsFeedTab -> push(Spotlight) -> Close -> pushReplacement(Home)  ==> [Home, Home] stack!
```
Every time a user opened Spotlight from the news feed and closed it, a new `HomeScreen` was pushed while the previous one remained in memory. Repeated 5 times, there would be 5 instances of `HomeScreen` and 5 active feeds running in the background.

### 3.2 Accidental Application Termination on Root Back
`HomeScreen` has 5 tabs in an `IndexedStack`. Because `HomeScreen` lacked a `PopScope`:
1. If a user browsed `LocalNewsTab`, `VideoTab`, or `ProfileTab` and pressed Android system back, the OS exited the app instead of navigating back to `NewsFeedTab`.
2. If a user was on `NewsFeedTab` and accidentally touched back, the app exited instantly with no confirmation.

### 3.3 Predictive Back Disabled on Android 13+/14+
`android:enableOnBackInvokedCallback="true"` was missing from `android/app/src/main/AndroidManifest.xml`. As a result, the OS predictive back gesture (revealing the underlying screen during an edge swipe) was disabled by Android.

### 3.4 Rapid Tap / Route Duplication
Rapid consecutive taps on news cards, trending items, or settings tiles pushed multiple identical instances of `NewsDetailScreen` or `SettingsScreen`, causing users to press back multiple times to leave a single article.

### 3.5 Unsaved UGC Content Loss
In `CreatePostScreen`, if a user typed a title and description or attached media and pressed system back, the screen popped immediately without confirmation, discarding user work.

---

## 4. Target Architecture for Step 5

```
+-------------------------------------------------------------+
|                        MaterialApp                          |
|             navigatorKey + AppNavigatorObserver             |
+-------------------------------------------------------------+
                              |
                              v
                      [ SplashScreen ]
                      (bootstraps APIs)
                              |  (pushReplacement)
                              v
                      [ HomeScreen ]  <--- SINGLE ROOT SHELL
             (PopScope: tab back -> double-back exit)
             +--------------------------------------+
             |  IndexedStack:                       |
             |  Tab 0: NewsFeedTab (Primary)        |
             |  Tab 1: LocalNewsTab                 |
             |  Tab 2: CreatePostScreen             |
             |  Tab 3: VideoTab (paused when hidden)|
             |  Tab 4: ProfileTab                   |
             +--------------------------------------+
                     /                  \
   (Modal / Child Push)                (Child Push)
            v                                  v
   [ SpotlightScreen ]               [ NewsDetailScreen ]
   (PopScope: stops TTS,                     |
    pops to root HomeScreen)                 v
                                      [ CommentsScreen ]
```

### Deterministic Back Button Priority Algorithm
When Android back is pressed:
1. **Active Dialog / Modal Bottom Sheet**: Pops first via Flutter's top-level route stack.
2. **Top Secondary Route (`NewsDetailScreen`, `CommentsScreen`, `SettingsScreen`, `VideoPlayerScreen`)**: Pops back to parent route.
3. **Active Form with Unsaved Changes (`CreatePostScreen`)**: Intercepted by form `PopScope` to show discard confirmation.
4. **Child Feature View (`SpotlightScreen`)**: Stops TTS and pops cleanly back to existing `HomeScreen`.
5. **Non-Primary Tab (`Local`, `Create`, `Video`, `Profile`)**: Intercepted by `HomeScreen`'s `PopScope`, smoothly switching active tab to Tab 0 (`News`).
6. **Root Primary Tab (`News`)**: First back triggers a floating "Press back again to exit" snackbar with a 2-second timestamp window. Second back within 2 seconds calls `SystemNavigator.pop()` to exit.

---

## 5. Audit Conclusion

The navigation layer requires zero invasive framework replacements. By standardizing on:
1. One strict root shell (`HomeScreen`),
2. Fixing `SpotlightScreen` and onboarding flows to pop or replace cleanly,
3. Implementing root and tab-switching `PopScope` on `HomeScreen`,
4. Opting into Android 13+/14+ predictive back via `AndroidManifest.xml`,
5. Introducing an `AppNavigator` guard against rapid-tap route stacking, and
6. Pausing `VideoTab` playback when inactive,
the navigation system will become 100% deterministic, safe, fast, and production-ready.
