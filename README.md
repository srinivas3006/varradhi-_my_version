# DailyBuzz — Way2News-style Clone (Flutter, Frontend Only)

A frontend-only Flutter clone of the Way2News app: onboarding with language
selection, mock phone/OTP login, a vertical swipe-to-snap news feed, a
reels-style video tab, local news, notifications, search, and a
profile/rewards screen with the signature "earn coins by reading" mechanic.
All data is mocked locally — no backend, no real auth, no network calls
beyond loading placeholder images.

## App flow

```
Splash → Language select → Login (phone/OTP, or Skip) → Home
                                                            │
                                        ┌───────────────────┼───────────────────┬─────────────┬─────────┐
                                     Feed tab            Video tab         Local tab   Notifications  Profile
                                  (+ Search screen)    (reels-style)      (location)      tab       (+ rewards)
```

## Project structure

```
lib/
├── main.dart                      # App entry point → SplashScreen
├── models/
│   ├── news_article.dart          # NewsArticle data model
│   └── video_item.dart            # VideoItem data model
├── data/
│   ├── mock_news.dart             # Mock categories + articles
│   └── mock_videos.dart           # Mock video feed items
├── state/
│   └── app_state.dart             # Singleton ChangeNotifier: coins, language, login
├── theme/
│   └── app_theme.dart             # Colors & ThemeData
├── widgets/
│   ├── category_bar.dart          # Horizontal scrollable category chips
│   ├── news_feed_card.dart        # Single feed card (image, meta, actions)
│   ├── bottom_nav_bar.dart        # Bottom tab bar
│   └── coin_badge.dart            # Reusable coin-count pill (app bar)
└── screens/
    ├── splash_screen.dart         # Animated logo splash
    ├── language_screen.dart       # Onboarding: pick a language
    ├── login_screen.dart          # Mock phone + OTP flow (OTP is "1234")
    ├── home_screen.dart           # Hosts bottom nav + tab switching
    ├── news_feed_tab.dart         # Vertical PageView snapping feed
    ├── news_detail_screen.dart    # Full article view (awards +2 coins)
    ├── video_tab.dart             # Reels-style vertical video feed
    ├── local_news_tab.dart        # Location-based article list
    ├── notifications_tab.dart     # Notification list
    ├── search_screen.dart         # Search with trending/recent suggestions
    └── profile_tab.dart           # Coin wallet, settings, logout
```

## Setup

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Unzip this project, then from the project root run:

```bash
flutter pub get
flutter run
```

Pick any connected device/emulator when prompted.

## Features implemented

- **Onboarding** — splash animation → 8-language picker → mock phone/OTP
  login (enter any 10-digit number, OTP is always `1234`) with a "Skip for
  now" escape hatch.
- **Vertical snap feed** — swipe up/down through full-height news cards.
- **Category tabs** — client-side filtering against mock data.
- **Rewards system** — reading an article for the first time earns +2 coins
  (shown live via the coin badge in the app bar and on the Profile tab);
  Profile has a "Redeem" flow (mock threshold at 500 coins).
- **Video tab** — reels-style vertical feed with like/comment/share rail and
  tap-to-show play icon, matching Way2News's short-video section.
- **Local news tab** — location switcher (bottom sheet) + list-style cards.
- **Notifications tab** — mixed notification types (coins, trending, local
  alerts, redemption, digest).
- **Search** — trending searches, recent search history (deletable), live
  filtering against mock articles.
- **Profile/settings** — language shortcut, push/dark-mode toggles (dark
  mode is a UI stub), about/privacy stubs, login/logout.

## Extending this

- Swap `mock_news.dart` / `mock_videos.dart` for a real repository/API layer
  — screens already just consume `List<NewsArticle>` / `List<VideoItem>`.
- Persist `AppState` (coins, language, login) with `shared_preferences` or a
  real backend instead of the in-memory singleton.
- Wire the dark-mode switch to a second `ThemeData` and an `AnimatedBuilder`
  around `MaterialApp` (structure is already in place via `AppState`).
- Add real video playback with `video_player` in place of the static
  thumbnail + play-icon stub in `video_tab.dart`.
