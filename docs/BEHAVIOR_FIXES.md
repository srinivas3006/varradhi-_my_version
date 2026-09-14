# Behavior fixes — 2026-09-14

Scope: behavior and data flow within the existing Flutter screens. Layouts,
colors, typography, assets and navigation-bar design were retained. The supplied
behavior document refers to a different screen/provider architecture; this is
not a claim that every screen in that reference has been implemented.

## Implemented

- Search: invalidate old responses immediately on edits; cancel pending debounce
  on submit; use content language; persist real recent queries; surface errors.
- Spotlight: eliminate cumulative-page duplicates; order loaded stories newest
  first; count stories for poster spacing; clear cursors on filter resets and
  terminal pages; reject obsolete loads and late callbacks after disposal.
- Story cards: render media from fetched article detail, deduplicate simultaneous
  detail requests, and avoid requesting article detail for UGC/live projections.
- Home, Local, Spotlight and category feeds: react to location/content-language
  changes. Local results are visible even without a saved location. Refreshes
  retain existing content where updated.
- Video list: separate Shorts/video cursors and exhaustion flags; prevent concurrent
  pagination; reject obsolete refresh responses; reset first-page deduplication.
- Saved: read all cursor pages; expose load failures; remove optimistically and
  restore on failure; guard disposed screens; wire the existing Share action.
- Authentication: registration returns through sign-in to the originating flow;
  duplicate submits are ignored; optional device sync cannot turn a successful
  registration into an apparent failure.
- Startup: a failed health check stops navigation and offers Retry; navigation is
  guarded against duplicate transitions. Existing animation/layout is retained.
- Shell: Home also mounts lazily when launched on another tab.
- Ad booking: invalidate stale quotes; require a current quote before submitting;
  prevent duplicate booking requests.
- Wallet: replace fabricated balances/totals and exchange rate with wallet API
  values; load payout history; pass server balance/minimum/rate to payout; reload
  after submission. Validate UPI syntax and prevent duplicate payout requests.

## Validation

- `dart tool/check_flow_state.dart`: eight dependency-free checks passed, covering
  feed cursor clearing/content retention, API cursors/errors, Spotlight filter
  state and server wallet values.
- Dart formatter parse check passed for changed Dart files (without writing
  unrelated formatting changes).
- `git diff --check`: passed.
- Flutter regressions were added/strengthened for terminal-page cursor clearing
  and Spotlight filter resets.
- `flutter test` could not resolve existing dependencies: installed Flutter 3.24 /
  Dart 3.5 cannot satisfy `image_picker 1.2.3`, which requires Dart 3.10+.
  No dependency or SDK version was changed. Full analysis, widget tests and
  device/backend integration checks remain unverified.

## Reference requirements beyond this patch

The supplied document additionally describes a dedicated Shorts reel/controller
pool, poll composition in Spotlight, offline article storage with TTL, a poster
caption/tone studio, and a staged startup checklist. Those are not implemented by
this patch. Several would introduce UI elements absent from the current design.
The full permission, ads, UGC, admin and notification flows have not been certified
against every reference scenario. Validate them with a compatible SDK and test
accounts before treating the reference document as an acceptance checklist.
