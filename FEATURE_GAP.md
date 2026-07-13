# Remaining Feature/Screen Gap — Toward an Exact Way2News Clone

## Building now (this round)
1. **Direct-open on repeat launches** — skip Splash → Language → Location →
   Login every time; remember the user already onboarded and land straight
   on the feed.
2. **Card-flip swipe transition** — replace the plain vertical `PageView`
   slide with a "closing magazine page" effect: the current card folds
   upward around its top edge as you swipe, revealing the next one — not a
   flat slide.

## Still missing after this round (roughly priority order)

**Interaction fidelity**
- Double-tap-to-like on the card image (currently only the heart icon works)
- Swipe left/right *within* a card to browse a multi-image gallery for one
  story (Way2News stories can have several images)
- Haptic feedback (`HapticFeedback.lightImpact()`) on swipe/like/bookmark
- Pull-to-refresh at the top of the feed
- Infinite scroll / pagination (currently the mock list just ends)

**Screens/flows not built yet**
- **Comments screen** — full comment thread per article (list, post, report/block), not just a count
- **Exit-confirmation dialog** — "Press back again to exit" pattern most Indian news apps use, often paired with an exit interstitial ad
- **Interview/Special Coverage section** — the video-interview format Way2News highlights separately from regular reels
- **Election/Live Results tracker** — seat-wise live tracker during election cycles
- **Referral / Invite Friends** screen (common growth loop in this app category)
- **Rate Us / App Update prompt** dialogs

**Feed/content polish**
- Breaking news ticker or banner pinned above the feed
- "Top Buzz" horizontal trending rail above/within the main feed (distinct from the vertical stack)
- Image preloading/caching so swiping feels instant (currently `Image.network` reloads if scrolled back)
- Persisted state — likes/bookmarks/coins currently reset on app restart; needs local storage (`shared_preferences` or `sqflite`)

**Ad system**
- Real ad SDK integration (`google_mobile_ads`) in place of the mock banner/native/interstitial widgets
- Rewarded video ads (optional bonus coins) — common in this app category, not confirmed as an actual Way2News mechanic

**Non-functional**
- Actual dark mode theme (currently a UI toggle stub)
- Offline/no-connectivity state handling
- Real backend + real auth (still mock OTP)
- Real per-language content pipeline for articles (UI translation is done; content translation is not — see earlier note)

---
This list will keep shrinking each round — happy to keep working down it in whatever order matters most to you.
