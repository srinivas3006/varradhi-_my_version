# VARADHI Backend API and Flutter APK Integration Handoff

Last verified from backend source: 2026-09-04

Production base URL:

```text
https://api.vaaradhinews.com
```

This document is the implementation contract for the Flutter APK. It documents the current backend as implemented in this repository. It does not document planned APIs as if they already exist.

## 1. Global API Contract

All API responses are wrapped by the backend renderer.

Success response:

```json
{
  "data": {},
  "meta": {},
  "errors": null
}
```

List response without pagination:

```json
{
  "data": [],
  "meta": {},
  "errors": null
}
```

Paginated response:

```json
{
  "data": [],
  "meta": {
    "count": 20,
    "next": "https://api.vaaradhinews.com/api/v1/articles/feed/?cursor=...",
    "previous": null
  },
  "errors": null
}
```

Error response:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Search keyword is required.",
    "details": {
      "q": "Search keyword is required."
    }
  }
}
```

Important frontend rule:

- Always read real payload from `data`.
- Always read pagination from `meta.next` and `meta.previous`.
- Always show API errors from `errors.message`.
- Use `errors.details` only for field-level form errors.
- Do not expect a top-level `success` field. The backend does not return it.

## 2. Headers

JSON request:

```http
Content-Type: application/json
Accept: application/json
```

Authenticated request:

```http
Authorization: Bearer <access_token>
```

Guest personalization and reactions:

```http
X-Device-ID: <stable_install_device_id>
X-Session-ID: <guest_session_id>
X-Device-Type: android
```

Use a stable `device_id` generated once per app install. Store it locally. Do not regenerate it on every launch.

## 3. Authentication Lifecycle

Backend auth uses JWT with stateful device sessions.

Default token behavior:

- Access token lifetime: 15 minutes.
- Refresh token lifetime: 7 days.
- Refresh token rotation: enabled.
- Old refresh token is blacklisted after refresh.
- Refresh requires the same `device_id` used at login/register.
- Password change and password reset invalidate active device sessions.

Flutter auth flow:

```text
App launch
  -> load access token, refresh token, device_id
  -> if no token: continue as guest or show login when user opens protected action
  -> if access token exists: call protected API or GET /api/v1/auth/me/
  -> if 401: call POST /api/v1/auth/token/refresh/
  -> if refresh succeeds: store new access and refresh, retry original request once
  -> if refresh fails: clear tokens, keep guest device_id, send user to login
```

Token storage:

- Store access token and refresh token in secure storage.
- Store `device_id` in persistent local storage.
- Store user profile and preferences in local cache for fast startup.
- Never store admin credentials in the APK.

## 4. API Inventory

| Area | Method | Endpoint | Auth | APK Use |
| --- | --- | --- | --- | --- |
| System | GET | `/api/v1/health/` | No | Yes |
| Auth | POST | `/api/v1/auth/register/` | No | Yes |
| Auth | POST | `/api/v1/auth/login/` | No | Yes |
| Auth | POST | `/api/v1/auth/token/refresh/` | No | Yes |
| Auth | POST | `/api/v1/auth/logout/` | Yes | Yes |
| Auth | POST | `/api/v1/auth/password/change/` | Yes | Yes |
| Auth | POST | `/api/v1/auth/password/reset/request/` | No | Yes |
| Auth | POST | `/api/v1/auth/password/reset/verify/` | No | Yes |
| Auth | POST | `/api/v1/auth/password/reset/confirm/` | No | Yes |
| Auth | GET/PATCH | `/api/v1/auth/me/` | Yes | Yes |
| Auth | GET | `/api/v1/auth/sessions/` | Yes | Yes |
| Auth | DELETE | `/api/v1/auth/sessions/{session_id}/` | Yes | Yes |
| User | POST | `/api/v1/user/location/` | Yes | Yes |
| User | PATCH | `/api/v1/users/me/preferences/` | Yes | Yes |
| User Locations | GET/PATCH | `/api/v1/auth/locations/profile/` | Yes | Yes |
| User Locations | GET/POST | `/api/v1/auth/locations/followed/` | Yes | Yes |
| User Locations | DELETE | `/api/v1/auth/locations/followed/{location_id}/` | Yes | Yes |
| User Locations | GET | `/api/v1/auth/locations/recent/` | Yes | Yes |
| Guest Location | GET/PATCH | `/api/v1/auth/locations/guest/` | No | Yes |
| Locations | GET | `/api/v1/locations/states/` | No | Yes |
| Locations | GET | `/api/v1/locations/districts/` | No | Yes |
| Locations | GET | `/api/v1/locations/subdistricts/` | No | Yes |
| Locations | GET | `/api/v1/locations/villages/` | No | Yes |
| Locations | GET | `/api/v1/locations/search/` | No | Yes |
| Home | GET | `/api/v1/feed/` | No | Yes |
| Articles | GET | `/api/v1/articles/feed/` | No | Yes |
| Articles | GET | `/api/v1/articles/featured/` | No | Yes |
| Articles | GET | `/api/v1/articles/recommendations/` | No | Yes |
| Articles | GET | `/api/v1/articles/{slug}/` | No | Yes |
| Articles | POST | `/api/v1/articles/` | Contributor/Admin | APK only if contributor feature is enabled |
| Reactions | PUT/DELETE | `/api/v1/articles/{article_id}/reaction/` | No or Yes | Yes |
| Comments | GET/POST | `/api/v1/articles/{article_id}/comments/` | GET no, POST yes | Yes |
| Comments | PATCH/DELETE | `/api/v1/articles/comments/{comment_id}/` | Yes | Yes |
| Comments | POST | `/api/v1/articles/comments/{comment_id}/report/` | Yes | Yes |
| Blogs | GET | `/api/v1/articles/blogs/` | No | Optional |
| Live | GET | `/api/v1/articles/live/` | No | Yes |
| Videos | GET | `/api/v1/articles/video-feed/` | No | Yes |
| Shorts | GET | `/api/v1/articles/shorts-feed/` | No | Yes |
| E-Paper | GET | `/api/v1/articles/epapers/` | No | Optional |
| TTS | POST | `/api/v1/articles/tts/` | No | Optional |
| TTS | GET | `/api/v1/articles/tts/status/{task_id}/` | No | Optional |
| UGC | POST | `/api/v1/ugc/send-otp/` | No | Yes |
| UGC | POST | `/api/v1/ugc/verify-otp/` | No | Yes |
| UGC | POST | `/api/v1/ugc/submit/` | Yes | Yes |
| UGC | POST | `/api/v1/ugc/upload-media/` | Yes | Yes |
| UGC | POST | `/api/v1/ugc/report/` | Yes | Yes |
| UGC | GET | `/api/v1/ugc/feed/` | No | Yes |
| UGC Reporter | GET | `/api/v1/ugc/reporter/dashboard/` | Yes | Yes |
| UGC Reporter | GET | `/api/v1/ugc/reporter/submissions/` | Yes | Yes |
| Categories | GET | `/api/v1/categories/` | No | Yes |
| Search | GET | `/api/v1/search/` | No | Yes |
| Search | GET | `/api/v1/search/trending/` | No | Optional |
| Ads | GET | `/api/v1/ads/` | No | Yes |
| Ads | POST | `/api/v1/ads/event/` | No | Yes |
| Ads | GET | `/api/v1/ads/areas/` | No | Yes |
| Ads | GET | `/api/v1/ads/pricing/` | No | Yes |
| Ads | POST | `/api/v1/ads/bookings/` | No | Yes |
| Posters | GET | `/api/v1/posters/` | No | Yes |
| Polls | GET | `/api/v1/polls/` | No | Yes |
| Polls | GET | `/api/v1/polls/{poll_id}/` | No | Yes |
| Polls | POST | `/api/v1/polls/{poll_id}/vote/` | No | Yes |
| Bookmarks | GET | `/api/v1/bookmarks/` | Yes | Yes |
| Bookmarks | POST | `/api/v1/bookmarks/` | Yes | Yes |
| Bookmarks | DELETE | `/api/v1/bookmarks/{bookmark_id}/` | Yes | Yes |
| Bookmarks | POST | `/api/v1/bookmarks/toggle/` | Yes | Yes |
| Notifications | POST | `/api/v1/notifications/guest-device/` | No | Yes |
| Notifications | GET/PATCH | `/api/v1/notifications/preferences/` | Yes | Yes |
| Notifications | GET/POST | `/api/v1/notifications/subscriptions/` | Yes | Yes |
| Notifications | DELETE | `/api/v1/notifications/subscriptions/{subscription_id}/` | Yes | Yes |
| Notifications | GET | `/api/v1/notifications/statistics/` | Yes | Yes |
| Notifications | GET | `/api/v1/notifications/inbox/` | Yes | Yes |
| Notifications | GET | `/api/v1/notifications/inbox/unread-count/` | Yes | Yes |
| Notifications | GET | `/api/v1/notifications/inbox/{user_notification_id}/` | Yes | Yes |
| Notifications | POST | `/api/v1/notifications/inbox/{user_notification_id}/read/` | Yes | Yes |
| Analytics | POST | `/api/v1/analytics/events/` | No | Yes |
| Quotes | GET | `/api/v1/quotes/random/` | No | Optional |
| CMS | GET | `/api/v1/cms/{slug}/` | No | Yes |
| Rewards | GET | `/api/v1/rewards/wallet/` | Yes | Yes |
| Rewards | GET | `/api/v1/rewards/transactions/` | Yes | Yes |
| Rewards | GET/POST | `/api/v1/rewards/payouts/` | Yes | Yes |
| Rewards | GET | `/api/v1/rewards/payouts/{payout_id}/` | Yes | Yes |

Admin-only endpoints mounted under `/api/v1/...` or `/admin/api/...` must not be used by the public APK unless the APK is an admin/contributor app.

## 4A. Admin API Inventory

These endpoints require admin/staff permission unless a specific view states otherwise. They are included here so the backend contract is complete, but the public Flutter APK must not call them. A separate admin Flutter/web client can use them after admin login/JWT.

| Area | Endpoint Pattern | Purpose |
| --- | --- | --- |
| Dashboard | `GET /admin/api/dashboard/summary/` | Admin dashboard summary |
| Dashboard | `GET /admin/api/dashboard/queues/` | Queue counters |
| System | `GET /admin/api/system/health/` | System health |
| System | `GET /admin/api/system/readiness/` | Readiness checks |
| System | `GET /admin/api/system/release-audit/` | Release audit |
| Articles | `GET /admin/api/articles/` | Article editorial list |
| Articles | `GET/PATCH/DELETE /admin/api/articles/{article_id}/` | Article detail/update/delete |
| Articles | `POST /admin/api/articles/{article_id}/approve/` | Approve article |
| Articles | `POST /admin/api/articles/{article_id}/reject/` | Reject article |
| Articles | `POST /admin/api/articles/{article_id}/publish/` | Publish article |
| Articles | `POST /admin/api/articles/{article_id}/archive/` | Archive article |
| Articles | `POST /admin/api/articles/{article_id}/media/` | Upload article media |
| Articles | `POST /admin/api/articles/thumbnail-upload-url/` | Pre-signed thumbnail upload URL |
| Articles | `GET /admin/api/articles/workflow-logs/` | Article workflow logs |
| Articles | `GET /admin/api/articles/reading-history/` | Reading history |
| Articles | `GET /admin/api/articles/reactions/` | Article reactions |
| Articles | `GET/DELETE /admin/api/articles/reactions/{reaction_id}/` | Reaction detail/delete |
| Article Comments | `GET /admin/api/articles/comments/` | Comment moderation list |
| Article Comments | `GET/PATCH /admin/api/articles/comments/{comment_id}/` | Comment detail/update |
| Article Comments | `POST /admin/api/articles/comments/{comment_id}/publish/` | Publish comment |
| Article Comments | `POST /admin/api/articles/comments/{comment_id}/hold/` | Hold comment |
| Article Comments | `POST /admin/api/articles/comments/{comment_id}/reject/` | Reject comment |
| Article Comments | `POST /admin/api/articles/comments/{comment_id}/hide/` | Hide comment |
| Article Comments | `POST /admin/api/articles/comments/{comment_id}/restore/` | Restore comment |
| Article Comments | `GET /admin/api/articles/comments/reports/` | Comment reports |
| Article Comments | `GET /admin/api/articles/comments/moderation-logs/` | Comment moderation logs |
| Blogs | `GET/POST /admin/api/articles/blogs/` | Blog list/create |
| Blogs | `GET/PATCH/DELETE /admin/api/articles/blogs/{blog_id}/` | Blog detail/update/delete |
| Videos | `GET/POST /admin/api/articles/videos/` | News video list/create |
| Videos | `GET/PATCH/DELETE /admin/api/articles/videos/{video_id}/` | News video detail/update/delete |
| Live News | `GET/POST /admin/api/articles/live-news/` | Live news list/create |
| Live News | `GET/PATCH/DELETE /admin/api/articles/live-news/{live_news_id}/` | Live news detail/update/delete |
| TTS | `GET /admin/api/articles/tts-cache/` | TTS cache list |
| TTS | `GET/DELETE /admin/api/articles/tts-cache/{tts_id}/` | TTS cache detail/delete |
| TTS | `GET /admin/api/articles/tts-metrics/` | TTS metrics |
| TTS | `GET /admin/api/articles/tts-metrics/{metric_id}/` | TTS metric detail |
| Recommendations | `GET /admin/api/articles/recommendation-stats/` | Recommendation stats |
| UGC | `GET /admin/api/ugc/queue/` | Moderation queue |
| UGC | `GET /admin/api/ugc/otp-deliveries/` | OTP delivery logs |
| UGC | `GET /admin/api/ugc/reports/` | UGC reports |
| UGC | `POST /admin/api/ugc/reports/{report_id}/review/` | Review report |
| UGC | `POST /admin/api/ugc/reports/{report_id}/dismiss/` | Dismiss report |
| UGC | `GET /admin/api/ugc/moderation-logs/` | Moderation logs |
| UGC | `GET /admin/api/ugc/reporters/{user_id}/` | Reporter profile |
| UGC | `POST /admin/api/ugc/submissions/bulk-action/` | Bulk moderation action |
| UGC | `GET/PATCH /admin/api/ugc/submissions/{submission_id}/` | Submission detail/update |
| UGC | `POST /admin/api/ugc/submissions/{submission_id}/approve/` | Approve submission |
| UGC | `POST /admin/api/ugc/submissions/{submission_id}/reject/` | Reject submission |
| UGC | `POST /admin/api/ugc/submissions/{submission_id}/flag/` | Flag submission |
| UGC | `POST /admin/api/ugc/submissions/{submission_id}/block-uploader/` | Block uploader |
| UGC | `POST /admin/api/ugc/submissions/{submission_id}/unblock-uploader/` | Unblock uploader |
| UGC | `POST /admin/api/ugc/submissions/{submission_id}/increase-trust/` | Increase reporter trust |
| UGC | `POST /admin/api/ugc/submissions/{submission_id}/decrease-trust/` | Decrease reporter trust |
| Users | `GET /admin/api/users/` | User list |
| Users | `GET/PATCH /admin/api/users/{user_id}/` | User detail/update |
| Users | `POST /admin/api/users/{user_id}/activate/` | Activate user |
| Users | `POST /admin/api/users/{user_id}/deactivate/` | Deactivate user |
| Users | `GET /admin/api/users/sessions/` | All sessions |
| Users | `GET /admin/api/users/{user_id}/sessions/` | User sessions |
| Users | `POST /admin/api/users/{user_id}/sessions/{session_id}/revoke/` | Revoke session |
| Users | `POST /admin/api/users/{user_id}/force-logout/` | Force logout |
| Users | `GET /admin/api/users/password-reset-audits/` | Password reset audit logs |
| Users | `GET /admin/api/users/{user_id}/locations/followed/` | User followed locations |
| Users | `GET /admin/api/users/{user_id}/locations/recent/` | User recent locations |
| Analytics | `/admin/api/analytics/editorial/*` | Editorial overview, locations, categories, trends, feed, search, ranking debug |
| Analytics | `GET /admin/api/analytics/dashboard/` | Analytics dashboard |
| Analytics | `GET /admin/api/analytics/content/` | Content analytics |
| Analytics | `GET /admin/api/analytics/ugc/` | UGC analytics |
| Analytics | `GET /admin/api/analytics/search/` | Search analytics |
| Analytics | `GET /admin/api/analytics/notifications/` | Notification analytics |
| Search | `GET /admin/api/search/logs/` | Search logs |
| Search | `POST /admin/api/search/logs/anonymize/` | Anonymize logs |
| Search | `GET /admin/api/search/trending/` | Trending searches |
| Search | `GET /admin/api/search/zero-results/` | Zero-result searches |
| Notifications | `GET /admin/api/notifications/` | Notification list |
| Notifications | `POST /admin/api/notifications/send/` | Send notification |
| Notifications | `POST /admin/api/notifications/target-preview/` | Preview target audience |
| Notifications | `GET /admin/api/notifications/logs/` | Delivery logs |
| Notifications | `GET /admin/api/notifications/preferences/` | User notification preferences |
| Notifications | `GET /admin/api/notifications/subscriptions/` | Notification subscriptions |
| Notifications | `GET/PATCH/DELETE /admin/api/notifications/subscriptions/{subscription_id}/` | Subscription detail/update/delete |
| Notifications | `GET /admin/api/notifications/user-notifications/` | User inbox records |
| Notifications | `GET/PATCH/DELETE /admin/api/notifications/user-notifications/{user_notification_id}/` | User notification detail |
| Notifications | `GET /admin/api/notifications/{notification_id}/` | Notification detail |
| Notifications | `POST /admin/api/notifications/{notification_id}/retry-failed/` | Retry failed sends |
| Polls | `GET/POST /admin/api/polls/` | Poll list/create |
| Polls | `GET/PATCH/DELETE /admin/api/polls/{poll_id}/` | Poll detail/update/delete |
| Polls | `POST /admin/api/polls/{poll_id}/close/` | Close poll |
| Polls | `GET /admin/api/polls/{poll_id}/results/` | Poll results |
| Polls | `GET /admin/api/polls/votes/` | Poll votes |
| Polls | `GET/DELETE /admin/api/polls/votes/{vote_id}/` | Poll vote detail/delete |
| Bookmarks | `GET /admin/api/bookmarks/` | Bookmark list |
| Bookmarks | `GET/DELETE /admin/api/bookmarks/{bookmark_id}/` | Bookmark detail/delete |
| Categories | `GET/POST /admin/api/categories/` | Category list/create |
| Categories | `PATCH/DELETE /admin/api/categories/{slug}/` | Category update/delete |
| Ads | `GET/POST /admin/api/ads/` | Ad list/create |
| Ads | `GET/PATCH/DELETE /admin/api/ads/{ad_id}/` | Ad detail/update/delete |
| Ads | `GET /admin/api/ads/intelligence/` | Campaign health |
| Ads | `GET/POST /admin/api/ads/areas/` | Ad areas list/create |
| Ads | `GET/PATCH/DELETE /admin/api/ads/areas/{area_id}/` | Ad area detail/update/delete |
| Ads | `GET/POST /admin/api/ads/pricing/` | Pricing list/create |
| Ads | `GET/PATCH/DELETE /admin/api/ads/pricing/{pricing_id}/` | Pricing detail/update/delete |
| Ads | `GET /admin/api/ads/bookings/` | Booking list |
| Ads | `GET/PATCH /admin/api/ads/bookings/{booking_id}/` | Booking detail/update |
| Posters | `GET/POST /admin/api/posters/` | Poster list/create |
| Posters | `GET/PATCH/DELETE /admin/api/posters/{poster_id}/` | Poster detail/update/delete |
| Posters | `POST /admin/api/posters/{poster_id}/images/` | Add poster image |
| Posters | `GET/PATCH/DELETE /admin/api/posters/{poster_id}/images/{image_id}/` | Poster image detail/update/delete |
| E-Papers | `GET/POST /admin/api/epapers/` | E-paper list/create |
| E-Papers | `GET/PATCH/DELETE /admin/api/epapers/{epaper_id}/` | E-paper detail/update/delete |
| Locations | `/admin/api/locations/states/*` | State CRUD, bulk, enable/disable |
| Locations | `/admin/api/locations/districts/*` | District CRUD, bulk, enable/disable |
| Locations | `/admin/api/locations/subdistricts/*` | Subdistrict CRUD, bulk, enable/disable |
| Locations | `/admin/api/locations/villages/*` | Village CRUD, bulk, enable/disable |
| Locations | `/admin/api/locations/aliases/*` | Alias CRUD, bulk, enable/disable |
| Locations | `/admin/api/locations/imports/*` | Validate/import/history |
| CMS | `/admin/api/cms/` | CMS page ModelViewSet |
| Quotes | `/admin/api/quotes/` | Quote ModelViewSet |
| Rewards | `GET /admin/api/rewards/dashboard/` | Reward dashboard |
| Rewards | `GET /admin/api/rewards/wallets/` | Wallet list |
| Rewards | `GET /admin/api/rewards/wallets/{user_id}/` | Wallet detail |
| Rewards | `POST /admin/api/rewards/wallets/{user_id}/adjust/` | Wallet adjustment |
| Rewards | `GET /admin/api/rewards/transactions/` | Reward transactions |
| Rewards | `GET /admin/api/rewards/payouts/` | Payout list |
| Rewards | `GET /admin/api/rewards/payouts/{payout_id}/` | Payout detail |
| Rewards | `POST /admin/api/rewards/payouts/{payout_id}/mark-paid/` | Mark payout paid |
| Rewards | `POST /admin/api/rewards/payouts/{payout_id}/reject/` | Reject payout |
| Rewards | `GET/PATCH /admin/api/rewards/settings/` | Reward settings |

## 5. Common Models

### Category

```json
{
  "id": "uuid",
  "name": "Business",
  "slug": "business",
  "display_name": "Business",
  "icon_url": "",
  "color_hex": "#7B1FA2",
  "sort_order": 5
}
```

### Article Card

```json
{
  "id": "uuid",
  "title": "Bill Gates Proposes Global Tax on AI and Automation",
  "slug": "bill-gates-proposes-global-tax-on-ai-and-automation",
  "summary": "Short preview text.",
  "thumbnail_url": "https://cdn.example.com/thumb.png",
  "media_type": "image",
  "video_url": "",
  "video_duration_seconds": 0,
  "category": {},
  "author_name": "John",
  "media_items": [],
  "source_name": "VARADHI Desk",
  "language": "en",
  "is_featured": false,
  "is_breaking": true,
  "is_bookmarked": false,
  "share_url": null,
  "read_time_minutes": 1,
  "view_count": 0,
  "like_count": 0,
  "dislike_count": 0,
  "comment_count": 0,
  "my_reaction": null,
  "published_at": "2026-08-31T14:38:48.442253+05:30",
  "state": "Telangana",
  "district": "Mahabubabad",
  "village": "Mahabubabad (Ct)",
  "subdistrict": "Mahabubabad",
  "is_regional": true,
  "priority_score": 10.0,
  "location_tags": ["Telangana", "Mahabubabad"]
}
```

Article `media_type` values: `image`, `video`.

### Media Item

Article media item:

```json
{
  "id": "uuid",
  "media_type": "image",
  "url": "https://cdn.example.com/image.jpg",
  "thumbnail_url": "https://cdn.example.com/thumb.jpg",
  "caption": "",
  "sort_order": 0,
  "is_primary": true,
  "created_at": "2026-09-04T10:00:00+05:30"
}
```

UGC media item:

```json
{
  "id": "uuid",
  "media_type": "IMAGE",
  "media_url": "https://cdn.example.com/ugc.jpg",
  "thumbnail_url": "",
  "sort_order": 0,
  "is_primary": true,
  "upload_status": "READY",
  "validation_status": "VALID",
  "created_at": "2026-09-04T10:00:00+05:30"
}
```

UGC media values: `IMAGE`, `VIDEO`, `SHORT_VIDEO`.

## 6. Authentication APIs

### Register

Purpose: create user, create device session, return JWT tokens.

```http
POST /api/v1/auth/register/
Content-Type: application/json
```

Request:

```json
{
  "email": "user@example.com",
  "password": "StrongPass123!",
  "password_confirm": "StrongPass123!",
  "full_name": "John Doe",
  "preferred_language": "en",
  "device_id": "android-device-123",
  "device_name": "Pixel 8",
  "device_type": "android",
  "fcm_token": "firebase_fcm_token"
}
```

Fields:

- `email`: required string email.
- `password`: required string, min 8 and Django password validators.
- `password_confirm`: required string.
- `full_name`: required string max 150.
- `preferred_language`: optional enum `en`, `hi`, `te`, `ta`, `ar`, `ur`; default `en`.
- `device_id`: required string max 255.
- `device_name`: optional string.
- `device_type`: optional enum `ios`, `android`, `web`, `unknown`; default `unknown`.
- `fcm_token`: optional string.

Success 201:

```json
{
  "data": {
    "access": "<jwt_access>",
    "refresh": "<jwt_refresh>",
    "session_id": "uuid",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "full_name": "John Doe",
      "profile_image": null,
      "preferred_language": "en",
      "theme": "system",
      "font_size": 16,
      "is_contributor": false,
      "is_admin": false,
      "created_at": "2026-09-04T10:00:00+05:30"
    }
  },
  "meta": {},
  "errors": null
}
```

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "An account with this email already exists.",
    "details": {
      "email": ["An account with this email already exists."]
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Passwords do not match.",
    "details": {
      "password_confirm": ["Passwords do not match."]
    }
  }
}
```

Frontend usage: registration screen. On success store tokens, user, session_id, device_id, then navigate to HomeScreen.

### Login

```http
POST /api/v1/auth/login/
Content-Type: application/json
```

Request:

```json
{
  "email": "user@example.com",
  "password": "StrongPass123!",
  "device_id": "android-device-123",
  "device_name": "Pixel 8",
  "device_type": "android",
  "fcm_token": "firebase_fcm_token"
}
```

Success 200: same shape as register.

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 401,
    "message": "Invalid credentials.",
    "details": {
      "detail": "Invalid credentials."
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 401,
    "message": "This account has been deactivated.",
    "details": {
      "detail": "This account has been deactivated."
    }
  }
}
```

Login is rate limited. For 429 show: "Too many attempts. Please wait and try again."

### Refresh Token

```http
POST /api/v1/auth/token/refresh/
Content-Type: application/json
```

Request:

```json
{
  "refresh": "<current_refresh_token>",
  "device_id": "android-device-123"
}
```

Success 200:

```json
{
  "data": {
    "access": "<new_access_token>",
    "refresh": "<new_refresh_token>",
    "session_id": "uuid"
  },
  "meta": {},
  "errors": null
}
```

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 401,
    "message": "Session is invalid or has been revoked.",
    "details": {
      "detail": "Session is invalid or has been revoked."
    }
  }
}
```

Frontend usage: API interceptor only. Do not show this as a screen. Retry the failed original request only once.

### Logout

```http
POST /api/v1/auth/logout/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "refresh": "<refresh_token>",
  "logout_all_devices": false
}
```

Success 200:

```json
{
  "data": {
    "message": "Successfully logged out."
  },
  "meta": {},
  "errors": null
}
```

Frontend usage: clear access token, refresh token, user cache, then continue as guest or open LoginScreen.

### Change Password

```http
POST /api/v1/auth/password/change/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "current_password": "OldPass123!",
  "new_password": "NewPass456!",
  "new_password_confirm": "NewPass456!"
}
```

Success 200:

```json
{
  "data": {
    "message": "Password changed successfully. Please log in again."
  },
  "meta": {},
  "errors": null
}
```

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Current password is incorrect.",
    "details": {
      "detail": "Current password is incorrect."
    }
  }
}
```

Navigation after success: clear tokens and navigate to LoginScreen.

### Forgot Password

Step 1: request reset.

```http
POST /api/v1/auth/password/reset/request/
Content-Type: application/json
```

Request:

```json
{
  "email": "user@example.com"
}
```

Success 200:

```json
{
  "data": {
    "message": "If an account exists, password reset instructions have been sent."
  },
  "meta": {},
  "errors": null
}
```

Throttle errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 429,
    "message": "Please wait before requesting another reset.",
    "details": {
      "detail": "Please wait before requesting another reset."
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 429,
    "message": "Password reset request limit reached.",
    "details": {
      "detail": "Password reset request limit reached."
    }
  }
}
```

Step 2: verify token.

```http
POST /api/v1/auth/password/reset/verify/
Content-Type: application/json
```

Request:

```json
{
  "email": "user@example.com",
  "token": "<reset_token_from_email>"
}
```

Success 200:

```json
{
  "data": {
    "message": "Reset token verified.",
    "verified": true
  },
  "meta": {},
  "errors": null
}
```

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Invalid reset token.",
    "details": {
      "token": ["Invalid reset token."]
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Reset token is expired or already used.",
    "details": {
      "token": ["Reset token is expired or already used."]
    }
  }
}
```

Step 3: confirm new password.

```http
POST /api/v1/auth/password/reset/confirm/
Content-Type: application/json
```

Request:

```json
{
  "email": "user@example.com",
  "token": "<reset_token_from_email>",
  "new_password": "NewPass456!",
  "new_password_confirm": "NewPass456!"
}
```

Success 200:

```json
{
  "data": {
    "message": "Password reset successfully. Please log in again."
  },
  "meta": {},
  "errors": null
}
```

Navigation after success: LoginScreen.

## 7. Profile, Preferences, and Location

### Get Profile

```http
GET /api/v1/auth/me/
Authorization: Bearer <access_token>
```

Success 200: `UserProfile` object.

### Update Profile

```http
PATCH /api/v1/auth/me/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "full_name": "John Doe",
  "preferred_language": "te",
  "theme": "system",
  "font_size": 16
}
```

Allowed editable fields:

- `full_name`: optional string.
- `preferred_language`: optional enum `en`, `hi`, `te`, `ta`, `ar`, `ur`.
- `theme`: optional enum `light`, `dark`, `system`.
- `font_size`: optional integer 12 to 24.

Font size error:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Font size must be between 12 and 24.",
    "details": {
      "font_size": ["Font size must be between 12 and 24."]
    }
  }
}
```

### Category Preferences

```http
PATCH /api/v1/users/me/preferences/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "category_weights": {
    "business": 0.8,
    "technology": 0.6,
    "sports": 0.2
  }
}
```

Rules:

- `category_weights`: required non-empty object.
- Keys must be active category slugs.
- Values are floats from 0.0 to 1.0.

Success 200:

```json
{
  "data": {
    "user": "uuid",
    "category_weights": {
      "business": 0.8,
      "technology": 0.6
    },
    "top_categories": ["business", "technology"],
    "updated_at": "2026-09-04T10:00:00+05:30"
  },
  "meta": {},
  "errors": null
}
```

Error:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Invalid category keys: unknown",
    "details": {
      "category_weights": ["Invalid category keys: unknown"]
    }
  }
}
```

### Lightweight User Location

```http
POST /api/v1/user/location/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "lat": 17.385,
  "lon": 78.4867,
  "city": "Hyderabad",
  "district": "Hyderabad",
  "state": "Telangana",
  "country": "India",
  "subdistrict": "Khairatabad",
  "village": "Khairatabad"
}
```

`lat`, `lon`, `city`, `state`, and `country` are serializer fields. The backend also accepts structured raw fields `village`, `subdistrict`, and `district`.

Use this after user grants location permission or manually selects location.

### Canonical Location Profile

Authenticated:

```http
GET /api/v1/auth/locations/profile/
PATCH /api/v1/auth/locations/profile/
Authorization: Bearer <access_token>
```

Guest:

```http
GET /api/v1/auth/locations/guest/
PATCH /api/v1/auth/locations/guest/
```

Patch request:

```json
{
  "state_id": "uuid",
  "district_id": "uuid",
  "subdistrict_id": "uuid",
  "village_id": "uuid"
}
```

At least one canonical id is required.

Error:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "At least one canonical location id is required.",
    "details": {
      "non_field_errors": ["At least one canonical location id is required."]
    }
  }
}
```

Success shape:

```json
{
  "data": {
    "location_type": "village",
    "location_id": "uuid",
    "state": {},
    "district": {},
    "subdistrict": {},
    "village": {},
    "legacy": {
      "state": "Telangana",
      "district": "Hyderabad",
      "subdistrict": "Khairatabad",
      "village": "Khairatabad"
    },
    "location_updated_at": "2026-09-04T10:00:00+05:30"
  },
  "meta": {},
  "errors": null
}
```

## 8. Public Location APIs

### States

```http
GET /api/v1/locations/states/?page_size=20&cursor=<cursor>
```

Success item:

```json
{
  "id": "uuid",
  "name_en": "Telangana",
  "name_te": "",
  "slug": "telangana",
  "code": "TS",
  "sort_order": 1
}
```

### Districts

```http
GET /api/v1/locations/districts/?state=telangana
GET /api/v1/locations/districts/?state_id=<state_uuid>
```

District item:

```json
{
  "id": "uuid",
  "state": "uuid",
  "name_en": "Hyderabad",
  "name_te": "Hyderabad",
  "slug": "hyderabad",
  "code": "",
  "sort_order": 0
}
```

### Subdistricts

```http
GET /api/v1/locations/subdistricts/?district_id=<district_uuid>
GET /api/v1/locations/subdistricts/?state=telangana&district=hyderabad
```

### Villages

```http
GET /api/v1/locations/villages/?subdistrict_id=<subdistrict_uuid>
GET /api/v1/locations/villages/?state=telangana&district=hyderabad&subdistrict=khairatabad
GET /api/v1/locations/villages/?pincode=500001
```

Village item:

```json
{
  "id": "uuid",
  "subdistrict": "uuid",
  "name_en": "Khairatabad",
  "name_te": "",
  "slug": "khairatabad",
  "pincode": "",
  "latitude": null,
  "longitude": null,
  "sort_order": 0
}
```

### Location Search

```http
GET /api/v1/locations/search/?q=hyderabad&limit=10
```

`limit` default is 20, maximum is 50.

Success:

```json
{
  "data": [
    {
      "type": "district",
      "id": "uuid",
      "name_en": "Hyderabad",
      "name_te": "Hyderabad",
      "slug": "hyderabad",
      "state": "Telangana",
      "district": "Hyderabad",
      "subdistrict": "",
      "pincode": ""
    }
  ],
  "meta": {},
  "errors": null
}
```

Frontend location selection flow:

```text
LocationSelectionScreen
  -> search q after 300 ms debounce
  -> user taps result
  -> if logged in: PATCH /api/v1/auth/locations/profile/
  -> if guest: PATCH /api/v1/auth/locations/guest/
  -> refresh HomeScreen feeds with state/district/subdistrict/village query params
```

## 9. Home and Feed APIs

### Unified Home Feed

Use this as the main mixed HomeScreen feed.

```http
GET /api/v1/feed/?include=all&lang=en&scope=main&page_size=20
```

Query parameters:

- `include`: optional enum `all`, `articles`, `ugc`, `live`; default `all`. Invalid values fall back to `all`.
- `lang` or `language`: optional string; default authenticated user preference, else `en`.
- `state`, `district`, `city`, `village`, `subdistrict`: optional location filters/ranking inputs.
- `scope`: optional enum `main`, `local`; invalid values fall back to `main`.
- `category`: optional category slug.
- `cursor`: optional pagination cursor.
- `page_size`: optional integer default 20, maximum 50.

Success item:

```json
{
  "id": "uuid",
  "type": "article",
  "title": "News title",
  "summary": "Short summary",
  "thumbnail_url": "https://cdn.example.com/thumb.jpg",
  "media_url": "",
  "created_at": "2026-09-04T10:00:00+05:30",
  "district": "Hyderabad",
  "subdistrict": "Khairatabad",
  "village": "Khairatabad",
  "state": "Telangana",
  "priority_score": 10,
  "source": "VARADHI Desk",
  "trust_score": 0,
  "metadata": {
    "slug": "news-title",
    "category": "business"
  }
}
```

Frontend usage:

- Render a mixed feed.
- For `type=article`, open ArticleDetailScreen using `metadata.slug` when available.
- For `type=ugc`, open UGC detail view only if frontend builds one from available feed fields; no separate public UGC detail endpoint is currently implemented.
- For `type=live`, open LiveVideoPlayerScreen using YouTube fields from metadata if present.

### Article Feed

Use this for article-only screens and category pages.

```http
GET /api/v1/articles/feed/?page_size=20
GET /api/v1/articles/feed/?lang=te&category=business&scope=local&state=Telangana&district=Hyderabad
```

Actual language behavior:

- If `lang` is omitted, backend uses `all` and returns all article languages.
- If `lang=te`, only Telugu content is returned.
- If `lang=en`, only English content is returned.

Sorting:

- Latest published articles first.
- Ordering is `-published_at`, `-created_at`, `-id`.

Query parameters:

- `lang`: optional enum-like string. Use `en`, `te`, `hi`, `ta`; omitted means all languages.
- `category`: optional category slug.
- `breaking`: optional boolean. Accepted truthy values: `1`, `true`, `yes`, `y`.
- `scope`: `main` or `local`; local applies stricter location filtering where supported.
- `state`, `district`, `city`, `village`, `subdistrict`: optional.
- `latitude`, `longitude`: optional float.
- `cursor`, `page_size`: cursor pagination; max page_size 100.

Frontend usage:

- Home article section.
- CategoryScreen.
- LatestNewsScreen.
- LocalNewsScreen.
- BreakingNewsScreen with `breaking=true`.

### Featured Articles

```http
GET /api/v1/articles/featured/?lang=en
```

If `lang` is absent:

- Authenticated users use `preferred_language`.
- Guests use `en`.

Use for top carousel/hero content.

### Recommendations

```http
GET /api/v1/articles/recommendations/?limit=10&lang=en
```

Query parameters:

- `limit`: optional integer default 10, maximum 50.
- `lang`: optional language.
- `state`, `district`, `city`, `village`, `subdistrict`: optional.
- `category`: optional slug.

Behavior:

- Authenticated users receive personalized recommendations.
- Guests receive default/trending style recommendations.

Recommendation tracking:

```http
POST /api/v1/articles/recommendation/impression/
Content-Type: application/json
```

```json
{
  "article_id": "uuid",
  "session_id": "guest-session-1234"
}
```

Click:

```http
POST /api/v1/articles/recommendation/click/
```

Dwell:

```http
POST /api/v1/articles/recommendation/dwell/
```

```json
{
  "article_id": "uuid",
  "seconds": 18,
  "session_id": "guest-session-1234"
}
```

Errors:

```json
{"error": "session_id required"}
{"error": "invalid session_id"}
{"error": "article_id required"}
{"error": "article_id and positive seconds required"}
{"error": "rate_limited"}
{"status": "duplicate"}
```

These endpoints currently return raw response payloads before renderer wrapping may be applied. Frontend should still treat non-2xx as failure and ignore duplicate events silently.

## 10. Article Detail, Reactions, Comments

### Article Detail

```http
GET /api/v1/articles/{slug}/
X-Device-ID: <device_id>
```

Authentication optional. Send `Authorization` if logged in. Send `X-Device-ID` for guest reaction state.

Success fields: all Article Card fields plus:

```json
{
  "content": "<p>Full article body</p>",
  "source_url": "https://source.example.com/story",
  "source_logo_url": "",
  "seo_title": "",
  "seo_description": "",
  "seo_tags": [],
  "tts_url": ""
}
```

404:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 404,
    "message": "Article \"slug-here\" not found.",
    "details": {
      "detail": "Article \"slug-here\" not found."
    }
  }
}
```

Frontend rendering:

- Header image/video from `media_items` first.
- Fallback image from `thumbnail_url`.
- If `media_type=video`, show video player using `video_url`; use `thumbnail_url` as poster.
- Render HTML `content` safely.
- Show `category.display_name`, `author_name`, `source_name`, `published_at`, `read_time_minutes`.
- Show reaction and comment counters.

### Set Reaction

```http
PUT /api/v1/articles/{article_id}/reaction/
Authorization: Bearer <access_token>   # optional
X-Device-ID: <device_id>               # required for guest
Content-Type: application/json
```

Request:

```json
{
  "reaction_type": "like"
}
```

`reaction_type` values: `like`, `dislike`.

Success 200:

```json
{
  "data": {
    "article_id": "uuid",
    "reaction_type": "like",
    "my_reaction": "like",
    "like_count": 11,
    "dislike_count": 1
  },
  "meta": {},
  "errors": null
}
```

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "X-Device-ID is required for guest reactions.",
    "details": {
      "device_id": ["X-Device-ID is required for guest reactions."]
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "reaction_type must be like or dislike.",
    "details": {
      "reaction_type": ["reaction_type must be like or dislike."]
    }
  }
}
```

### Remove Reaction

```http
DELETE /api/v1/articles/{article_id}/reaction/
Authorization: Bearer <access_token>   # optional
X-Device-ID: <device_id>               # required for guest
```

Success returns same counter payload with `reaction_type` and `my_reaction` as `null`.

### List Comments

```http
GET /api/v1/articles/{article_id}/comments/?cursor=<cursor>&page_size=20
Authorization: Bearer <access_token>   # optional
```

Authentication optional for reading. Logged-in authors can see their own pending/held comments.

Comment item:

```json
{
  "id": "uuid",
  "article_id": "uuid",
  "content": "Nice update",
  "author": {
    "id": "uuid",
    "display_name": "John"
  },
  "parent_id": null,
  "status": "published",
  "visibility": "published",
  "created_at": "2026-09-04T10:00:00+05:30",
  "edited_at": null,
  "replies": []
}
```

Status values: `pending`, `published`, `held`, `rejected`, `hidden`, `deleted`.

Visibility values used by frontend:

- `published`: show normally.
- `author_only`: show only to current author with "Pending review" badge.
- `public_tombstone`: show "Comment deleted".
- `hidden`: hide from normal public UI.

### Create Comment

```http
POST /api/v1/articles/{article_id}/comments/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "content": "Nice update",
  "parent_id": null
}
```

Rules:

- `content`: required string, max 1000 chars, non-empty after trim.
- `parent_id`: optional UUID. Reply-to-reply is not supported.
- New comments are created as `pending`.

Success 201 returns Comment item.

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Comment cannot be empty.",
    "details": {
      "content": ["Comment cannot be empty."]
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Parent comment not found for this article.",
    "details": {
      "parent_id": ["Parent comment not found for this article."]
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Reply-to-reply is not supported.",
    "details": {
      "parent_id": ["Reply-to-reply is not supported."]
    }
  }
}
```

### Edit Comment

```http
PATCH /api/v1/articles/comments/{comment_id}/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "content": "Updated comment"
}
```

Rules:

- User can edit only own comment.
- Editing a published comment moves it back to pending.

Errors:

- `You can edit only your own comment.`
- `This comment cannot be edited.`
- `Comment not found.`

### Delete Comment

```http
DELETE /api/v1/articles/comments/{comment_id}/
Authorization: Bearer <access_token>
```

Success 200 returns deleted comment object.

Errors:

- `You can delete only your own comment.`
- `Comment not found.`

### Report Comment

```http
POST /api/v1/articles/comments/{comment_id}/report/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "reason": "spam",
  "notes": "Repeated promotion"
}
```

Reason values:

`spam`, `abuse`, `hate`, `harassment`, `misinformation`, `sexual_content`, `violence`, `personal_information`, `other`.

Errors:

- `Invalid report reason.`
- `Notes must be 1000 characters or shorter.`
- `You cannot report your own comment.`
- `Comment not found.`

## 11. Videos and Live News

### Live News List

```http
GET /api/v1/articles/live/
```

Success item:

```json
{
  "id": "uuid",
  "title": "Live News",
  "youtube_url": "https://www.youtube.com/watch?v=VIDEO_ID",
  "youtube_video_id": "VIDEO_ID",
  "thumbnail_url": "https://i.ytimg.com/vi/VIDEO_ID/hqdefault.jpg",
  "description": "",
  "channel_name": "VARADHI",
  "is_active": true,
  "autoplay": true,
  "sort_order": 1
}
```

### Video Feed

```http
GET /api/v1/articles/video-feed/?page_size=20
GET /api/v1/articles/video-feed/?scope=local&state=Telangana&district=Hyderabad
```

Query parameters:

- `lang`: optional, currently used in cache key.
- `scope`: `main` or `local`.
- `state`, `district`, `city`, `subdistrict`, `village`: optional local filters.
- `cursor`, `page_size`: max 50.

Sorting:

- `-video_priority`, `-published_at`, `-id`.
- First page of main scope may prepend active live streams.

Success item:

```json
{
  "id": "uuid",
  "created_at": "2026-09-04T10:00:00+05:30",
  "updated_at": "2026-09-04T10:00:00+05:30",
  "title": "Video title",
  "youtube_video_id": "VIDEO_ID",
  "youtube_url": "https://www.youtube.com/watch?v=VIDEO_ID",
  "video_url": "",
  "thumbnail_url": "https://cdn.example.com/thumb.jpg",
  "description": "",
  "channel_name": "VARADHI",
  "published_at": "2026-09-04T10:00:00+05:30",
  "is_live": false,
  "is_trending": false,
  "is_breaking": false,
  "is_short": false,
  "video_priority": 10,
  "state": "Telangana",
  "district": "Hyderabad",
  "city": "Hyderabad",
  "subdistrict": "",
  "village": "",
  "location_tags": [],
  "language": "te",
  "views_count": 0,
  "likes_count": 0,
  "concurrent_viewers": 0,
  "duration_seconds": 90
}
```

For prepended live items, some model-only fields may be omitted. Flutter must handle missing/null optional fields.

### Shorts Feed

```http
GET /api/v1/articles/shorts-feed/?page_size=20
```

Important current backend behavior:

- The queryset filters `is_short=true` and `language='te'`.
- The `lang` query parameter is currently used only in cache key, not in queryset filtering.

Success item:

```json
{
  "id": "uuid",
  "title": "Short title",
  "thumbnail_url": "https://cdn.example.com/thumb.jpg",
  "youtube_video_id": "VIDEO_ID",
  "youtube_url": "https://www.youtube.com/shorts/VIDEO_ID",
  "video_url": "",
  "is_live": false,
  "is_breaking": false,
  "is_trending": false,
  "channel_name": "VARADHI",
  "video_priority": 10,
  "is_short": true,
  "duration_seconds": 45,
  "state": "Telangana",
  "district": "Hyderabad",
  "city": "Hyderabad",
  "subdistrict": "",
  "village": "",
  "location_tags": []
}
```

## 12. Video Playback Architecture

Flutter must not treat YouTube page URLs as direct MP4 streams.

Detection:

```text
if youtube_video_id is not empty -> YouTube player
else if youtube_url contains youtube.com/watch, youtu.be, youtube.com/shorts -> extract id and use YouTube player
else if video_url ends with .m3u8 -> HLS capable player
else if video_url is http/https -> direct video player
else -> show thumbnail and unavailable state
```

YouTube URL forms to support:

```text
https://www.youtube.com/watch?v=VIDEO_ID
https://youtu.be/VIDEO_ID
https://www.youtube.com/shorts/VIDEO_ID
```

Direct video UX:

- Use a Flutter video player that supports MP4 and HLS.
- Show thumbnail until controller is initialized.
- Show buffering spinner while loading.
- Pause when navigating away.
- Dispose controller when card leaves the active window.
- Retry on network error.
- Support fullscreen and orientation switch on detail/player screens.

YouTube UX:

- Use a YouTube-compatible Flutter player/webview package.
- Initialize from `youtube_video_id` when present.
- For shorts, use the same extracted ID but render in 9:16 layout.
- Handle private/deleted/unavailable videos with a friendly unavailable card.

Shorts/Reels UX:

```text
ShortsScreen
  -> Vertical PageView
  -> one video per full screen
  -> auto-play active item
  -> pause previous item
  -> preload next item only
  -> dispose far-away controllers
```

Do not initialize all videos at once. Keep active, previous, and next controllers only.

Behavior by network:

- Wi-Fi/5G: autoplay active item after thumbnail.
- 4G: autoplay with buffering indicator.
- Slow network: show thumbnail, spinner, retry button after timeout.
- Offline: show cached thumbnails and "No internet connection".
- App background/screen locked: pause playback.
- Navigation away: pause and dispose if leaving screen.

## 13. Images and Media Handling

Article image fields:

- Card image: `thumbnail_url`.
- Multi-image/media carousel: `media_items`.
- Video poster: `thumbnail_url` or media item `thumbnail_url`.
- Direct article video: `video_url`.

UGC image/video fields:

- Primary image/video: `media_url`.
- Thumbnail: `thumbnail_url`.
- Multi-media carousel: `media_items`.

Poster image fields:

- Primary: `image_url`.
- Multi-poster carousel: `images`.
- Thumbnail: `thumbnail_url`.

Frontend image rules:

- Use cached network images.
- Use 16:9 for article feed images.
- Use 1:1 or 4:5 for poster cards.
- Use 9:16 for shorts.
- Show neutral placeholder if URL is empty.
- Show broken-image fallback if image fails.
- Lazy load images in feed.

## 14. UGC APIs

UGC upload is authenticated. OTP verification is one-time for first-time uploader/mobile verification. After the backend marks the user/mobile verified, future uploads with the same verified mobile do not need OTP again.

Production media limits currently verified:

- `MAX_IMAGE_MB`: 10
- `MAX_VIDEO_MB`: 50
- `UGC_MAX_MEDIA_ITEMS`: 10
- `ARTICLE_MAX_MEDIA_ITEMS`: 10

### Send OTP

```http
POST /api/v1/ugc/send-otp/
Content-Type: application/json
```

Request:

```json
{
  "mobile": "9876543210"
}
```

Success 200:

```json
{
  "data": {
    "message": "OTP sent."
  },
  "meta": {},
  "errors": null
}
```

Possible errors from service:

- HTTP 429 with service message, for example OTP throttle text.
- HTTP 503 if OTP provider is unavailable.
- Validation error for invalid Indian mobile number.

### Verify OTP

```http
POST /api/v1/ugc/verify-otp/
Content-Type: application/json
```

Request:

```json
{
  "mobile": "9876543210",
  "otp": "123456"
}
```

Success 200:

```json
{
  "data": {
    "message": "OTP verified.",
    "verified": true
  },
  "meta": {},
  "errors": null
}
```

Errors:

- HTTP 400 with OTP verification message.
- HTTP 429 with throttle message.
- HTTP 503 with OTP service unavailable message.

### Submit UGC News

```http
POST /api/v1/ugc/submit/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "mobile": "9876543210",
  "title": "Suryapet road repair update",
  "description": "Local road repair work started near the market area.",
  "category": "local",
  "content_type": "VIDEO",
  "media_url": "",
  "thumbnail_url": "",
  "media_items": [
    {
      "media_type": "IMAGE",
      "media_url": "https://cdn.example.com/ugc-1.jpg",
      "thumbnail_url": "",
      "sort_order": 0,
      "is_primary": true
    }
  ],
  "location_lat": "17.141500",
  "location_lon": "79.623600",
  "village": "",
  "subdistrict": "Suryapet",
  "district": "Suryapet",
  "state": "Telangana",
  "country": "India"
}
```

Fields:

- `mobile`: required Indian mobile string.
- `title`: required string max 255.
- `description`: required string.
- `category`: optional string max 100.
- `content_type`: required enum `TEXT`, `IMAGE`, `VIDEO`.
- `media_url`: optional URL.
- `thumbnail_url`: optional URL.
- `media_items`: optional array, max `UGC_MAX_MEDIA_ITEMS`.
- `location_lat`, `location_lon`: optional decimal.
- `village`, `subdistrict`, `district`, `state`, `country`: optional strings.

Success 201:

```json
{
  "data": {
    "id": "uuid",
    "title": "Suryapet road repair update",
    "description": "Local road repair work started near the market area.",
    "category": "local",
    "content_type": "VIDEO",
    "media_url": "",
    "thumbnail_url": "",
    "media_type": "",
    "media_items": [],
    "media_metadata": {},
    "upload_status": "PENDING",
    "validation_status": "VALID",
    "duplicate_score": 0,
    "duplicate_matches": [],
    "duplicate_flagged": false,
    "location_lat": "17.141500",
    "location_lon": "79.623600",
    "village": "",
    "subdistrict": "Suryapet",
    "district": "Suryapet",
    "state": "Telangana",
    "country": "India",
    "status": "PENDING_REVIEW",
    "source_type": "USER_UPLOAD",
    "mobile_verified": true,
    "created_at": "2026-09-04T10:00:00+05:30",
    "updated_at": "2026-09-04T10:00:00+05:30"
  },
  "meta": {},
  "errors": null
}
```

Errors:

- `Submitted mobile does not match verified mobile.`
- Rate-limit service reason text.
- Upload validation text.

### Upload UGC Media

Use this after creating a submission when the user selected local files.

```http
POST /api/v1/ugc/upload-media/
Authorization: Bearer <access_token>
Content-Type: multipart/form-data
```

Single file:

```text
submission_id=<submission_uuid>
mobile=9876543210
media_type=VIDEO
file=<binary>
```

Multiple files:

```text
submission_id=<submission_uuid>
mobile=9876543210
media_type=IMAGE
media_types=IMAGE,IMAGE,VIDEO
files=<binary file 1>
files=<binary file 2>
files=<binary file 3>
```

Rules:

- `media_types` count must match uploaded file count when supplied.
- If `media_types` is omitted, all files use `media_type`.
- Total existing plus new media cannot exceed `UGC_MAX_MEDIA_ITEMS`.
- Images and videos are validated by backend size/type rules from environment settings.

Success 200 returns full `UserNewsSubmission` with `media_items`.

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "media_types must match the number of uploaded files.",
    "details": {
      "detail": "media_types must match the number of uploaded files."
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Invalid media_types value.",
    "details": {
      "detail": "Invalid media_types value."
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Media validation failed.",
    "details": {
      "detail": "Media validation failed.",
      "errors": [
        {
          "filename": "video.mov",
          "errors": ["..."]
        }
      ]
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 404,
    "message": "Submission not found.",
    "details": {
      "detail": "Submission not found."
    }
  }
}
```

### UGC Feed

```http
GET /api/v1/ugc/feed/?scope=main&page_size=20
GET /api/v1/ugc/feed/?scope=local&state=Telangana&district=Suryapet
```

Query:

- `state`, `district`, `city`, `village`, `subdistrict`: optional.
- `scope`: `main` or `local`; invalid values fallback to `main`.
- `cursor`, `page_size`: page_size max 50.

Item:

```json
{
  "id": "uuid",
  "type": "ugc",
  "title": "Local update",
  "description": "User submitted news.",
  "thumbnail_url": "",
  "media_url": "https://cdn.example.com/ugc.mp4",
  "media_type": "VIDEO",
  "media_items": [],
  "district": "Suryapet",
  "state": "Telangana",
  "village": "",
  "subdistrict": "Suryapet",
  "created_at": "2026-09-04T10:00:00+05:30",
  "priority_score": 0,
  "source": "USER_UPLOAD",
  "trust_level": "NEW_USER",
  "trust_score": 0,
  "uploader": {
    "id": "uuid",
    "display_name": "user",
    "trust_level": "NEW_USER"
  }
}
```

### Reporter Dashboard

```http
GET /api/v1/ugc/reporter/dashboard/
Authorization: Bearer <access_token>
```

Success:

```json
{
  "data": {
    "total_submissions": 3,
    "pending_count": 1,
    "approved_count": 2,
    "published_count": 2,
    "rejected_count": 0,
    "trust_score": 10,
    "reporter_level": "NEW_USER",
    "recent_submissions": []
  },
  "meta": {},
  "errors": null
}
```

### Reporter Submissions

```http
GET /api/v1/ugc/reporter/submissions/?status=pending&page_size=20
Authorization: Bearer <access_token>
```

Status filter values:

- `pending`
- `approved`
- `published`
- `rejected`

Invalid filter error: `Invalid status filter.`

### Report UGC Submission

```http
POST /api/v1/ugc/report/
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "submission_id": "uuid",
  "reason": "misinformation",
  "notes": "Looks incorrect"
}
```

Errors:

- `Submission not found.`
- `Submission already reported by this user.`

## 15. Categories

```http
GET /api/v1/categories/?lang=te
```

Success:

```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Business",
      "slug": "business",
      "display_name": "Business",
      "icon_url": "",
      "color_hex": "#7B1FA2",
      "sort_order": 5
    }
  ],
  "meta": {},
  "errors": null
}
```

Use on HomeScreen top category chips and CategorySelectionScreen.

## 16. Search

```http
GET /api/v1/search/?q=ai&lang=en&category=technology
```

Query:

- `q`: required string, minimum 2 characters.
- `lang`: optional. If absent and logged in, user preferred language is used. Guests default `en`.
- `category`: optional category slug.

Success:

```json
{
  "data": {
    "keyword": "ai",
    "result_count": 3,
    "results": []
  },
  "meta": {},
  "errors": null
}
```

Errors:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Search keyword is required.",
    "details": {
      "q": "Search keyword is required."
    }
  }
}
```

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Search keyword must be at least 2 characters.",
    "details": {
      "q": "Search keyword must be at least 2 characters."
    }
  }
}
```

Frontend search flow:

```text
SearchScreen
  -> wait until q has at least 2 characters
  -> debounce 300 ms
  -> call /api/v1/search/
  -> render article cards from data.results
  -> empty state if result_count is 0
  -> tap article -> ArticleDetailScreen
```

Trending:

```http
GET /api/v1/search/trending/?days=7
```

Returns:

```json
{
  "data": [
    {
      "keyword": "hyderabad",
      "search_count": 25
    }
  ],
  "meta": {},
  "errors": null
}
```

## 17. Ads and Bookings

### Get Ads

```http
GET /api/v1/ads/?zone=feed&scope=main&lang=te
X-Device-ID: <device_id>
X-Session-ID: <session_id>
X-Device-Type: android
```

Query:

- `zone` or `placement_zone`: optional; default `feed`.
- Placement values: `feed`, `article`, `splash`, `search`.
- `state`, `district`, `city`, `subdistrict`, `village`, `area_id`: optional.
- `scope`: `main` or `local`.
- `lang` or `language`: optional.
- `category`: optional.

Ad type values:

`banner`, `interstitial`, `native`, `video`, `poster`, `sponsored_card`, `breaking_strip`, `local_listing`, `full_screen`, `bottom_sticky`.

Success item:

```json
{
  "id": "uuid",
  "image_url": "https://cdn.example.com/ad.jpg",
  "video_url": null,
  "destination_url": "https://business.example.com",
  "ad_type": "banner",
  "placement_zone": "feed",
  "target_scope": "global",
  "area": null,
  "display_frequency": 5,
  "ctr": 0.0
}
```

Frontend placement:

- `splash`: App open ad screen.
- `feed`: insert after every `display_frequency` content cards.
- `article`: show inside article body after paragraph break or at bottom.
- `search`: show between search results.

### Track Ad Event

```http
POST /api/v1/ads/event/
Content-Type: application/json
X-Device-ID: <device_id>
X-Session-ID: <session_id>
X-Device-Type: android
```

Request:

```json
{
  "ad_id": "uuid",
  "event_type": "impression",
  "placement_zone": "feed",
  "device_id": "android-device-123",
  "session_id": "guest-session-123"
}
```

`event_type`: `impression`, `viewability`, `click`, `dismiss`, `skip`, `hide`.

Success:

```json
{
  "data": {
    "recorded": true
  },
  "meta": {},
  "errors": null
}
```

### Advertisement Areas

```http
GET /api/v1/ads/areas/
```

Item:

```json
{
  "id": "uuid",
  "name": "Hyderabad",
  "state": "Telangana",
  "district": "Hyderabad",
  "city": "Hyderabad",
  "village": "",
  "subdistrict": "",
  "sort_order": 1
}
```

### Pricing Quote

```http
GET /api/v1/ads/pricing/?ad_type=local&area_id=<area_uuid>&duration_days=7
```

`ad_type`: `local` or `main`.

Success:

```json
{
  "data": {
    "ad_type": "local",
    "area": {
      "id": "uuid",
      "name": "Hyderabad"
    },
    "duration_days": 7,
    "price": "1500.00",
    "currency": "INR"
  },
  "meta": {},
  "errors": null
}
```

Errors:

- `area_id is required for local advertisements.`
- `Active advertisement area not found.`
- `Advertisement pricing not found.`

### Create Booking

```http
POST /api/v1/ads/bookings/
Content-Type: application/json
```

Request:

```json
{
  "advertiser_name": "Ravi",
  "phone": "9876543210",
  "business_name": "Ravi Mobiles",
  "ad_type": "local",
  "area_id": "uuid",
  "duration_days": 7,
  "message": "Need banner ad in Hyderabad"
}
```

Success 201:

```json
{
  "data": {
    "id": "uuid",
    "status": "pending",
    "quoted_price": "1500.00",
    "currency": "INR",
    "whatsapp_url": "https://wa.me/..."
  },
  "meta": {},
  "errors": null
}
```

Frontend flow:

```text
AdsBookingScreen
  -> load areas
  -> user chooses main/local
  -> if local, select area
  -> choose duration
  -> call pricing
  -> show quote
  -> submit booking
  -> success screen with WhatsApp contact button using whatsapp_url
```

## 18. Posters

```http
GET /api/v1/posters/?category=good_morning&lang=te&page_size=20
```

Poster categories:

`good_morning`, `devotional`, `love`, `motivational`, `festival`, `special_day`, `jyothishyam`, `panchangam`, `daily_quote`, `health_tip`, `education`, `government_update`.

Success item:

```json
{
  "id": "uuid",
  "title": "Good Morning",
  "category": "good_morning",
  "image_url": "https://cdn.example.com/poster.jpg",
  "thumbnail_url": "",
  "images": [
    {
      "id": "uuid",
      "image_url": "https://cdn.example.com/poster.jpg",
      "caption": "",
      "sort_order": 0
    }
  ],
  "language": "te",
  "festival_name": "",
  "event_date": null,
  "share_url": null,
  "created_at": "2026-09-04T10:00:00+05:30"
}
```

Frontend UX:

- Home horizontal poster strip.
- PosterCategoryScreen grid.
- PosterDetailScreen with swipe carousel using `images`.
- Download/share buttons should use image URL. Backend does not provide a poster download API.

## 19. Polls

### List Polls

```http
GET /api/v1/polls/
X-Device-ID: <device_id>
```

Returns active polls only, last 20, no pagination.

Poll item:

```json
{
  "id": "uuid",
  "question": "Who will win?",
  "option_a": "A",
  "option_b": "B",
  "vote_a_count": 10,
  "vote_b_count": 5,
  "total_votes": 15,
  "options": [
    {
      "id": "uuid",
      "label": "A",
      "sort_order": 0,
      "vote_count": 10,
      "percentage": 66.7
    }
  ],
  "percentages": {
    "a": 66.7,
    "b": 33.3
  },
  "user_vote": null,
  "user_vote_option_id": null,
  "is_active": true,
  "is_expired": false,
  "ends_at": null,
  "created_at": "2026-09-04T10:00:00+05:30"
}
```

### Vote

```http
POST /api/v1/polls/{poll_id}/vote/
Authorization: Bearer <access_token>   # optional
X-Device-ID: <device_id>               # recommended for guests
Content-Type: application/json
```

Preferred request:

```json
{
  "option_id": "uuid"
}
```

Legacy request:

```json
{
  "choice": "a"
}
```

Error if neither supplied:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Provide option_id or legacy choice.",
    "details": {
      "option_id": ["Provide option_id or legacy choice."]
    }
  }
}
```

Frontend UX:

- Show option buttons.
- After vote, replace buttons with percentage bars.
- Do not allow repeat tap while request is pending.

## 20. Bookmarks

All bookmark APIs require login.

### List

```http
GET /api/v1/bookmarks/?page_size=20
Authorization: Bearer <access_token>
```

Item:

```json
{
  "id": "uuid",
  "article": {},
  "created_at": "2026-09-04T10:00:00+05:30"
}
```

### Add

```http
POST /api/v1/bookmarks/
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "article_id": "uuid"
}
```

Success 201:

```json
{
  "data": {
    "id": "uuid",
    "message": "Bookmarked successfully."
  },
  "meta": {},
  "errors": null
}
```

Already bookmarked 200:

```json
{
  "data": {
    "message": "Article already bookmarked."
  },
  "meta": {},
  "errors": null
}
```

### Toggle

```http
POST /api/v1/bookmarks/toggle/
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "article_id": "uuid"
}
```

Success add:

```json
{
  "data": {
    "bookmarked": true,
    "message": "Bookmarked."
  },
  "meta": {},
  "errors": null
}
```

Success remove:

```json
{
  "data": {
    "bookmarked": false,
    "message": "Bookmark removed."
  },
  "meta": {},
  "errors": null
}
```

### Delete

```http
DELETE /api/v1/bookmarks/{bookmark_id}/
Authorization: Bearer <access_token>
```

Success 204: empty body.

Error: `Bookmark not found.`

## 21. Notifications

### Guest Device Registration

Use this for users who install the APK and do not log in. This lets admin broadcast/location notifications reach guest devices.

```http
POST /api/v1/notifications/guest-device/
Content-Type: application/json
```

Request:

```json
{
  "device_id": "guest-device-123",
  "device_name": "Pixel 8",
  "device_type": "android",
  "app_version": "1.0.0",
  "fcm_token": "real_firebase_fcm_token_value",
  "state": "Telangana",
  "district": "Hyderabad",
  "subdistrict": "Khairatabad",
  "village": "Khairatabad",
  "country": "India",
  "state_id": "uuid",
  "district_id": "uuid",
  "subdistrict_id": "uuid",
  "village_id": "uuid"
}
```

Required:

- `device_id`
- `fcm_token`

Optional:

- `device_name`, `device_type`, `app_version`
- text location fields
- canonical location ids

Error:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Invalid FCM token.",
    "details": {
      "fcm_token": ["Invalid FCM token."]
    }
  }
}
```

Important:

- Guest devices can receive push notifications.
- Guest notification inbox/list API is not implemented. Inbox APIs require login.
- If user later logs in, include `fcm_token` in login/register so the authenticated `DeviceSession` is updated.

### Notification Preferences

```http
GET /api/v1/notifications/preferences/
PATCH /api/v1/notifications/preferences/
Authorization: Bearer <access_token>
```

Patch request:

```json
{
  "enabled": true,
  "breaking_news": true,
  "live_news": true,
  "local_news": true,
  "sports": true,
  "politics": true,
  "entertainment": true,
  "business": true,
  "quiet_hours_start": "22:00:00",
  "quiet_hours_end": "07:00:00",
  "timezone": "Asia/Kolkata",
  "max_per_hour": 5,
  "max_per_day": 25,
  "snoozed_until": null
}
```

Errors:

- `max_per_hour`: `Must be zero or greater.`
- `max_per_day`: `Must be zero or greater.`

### Notification Subscriptions

```http
GET /api/v1/notifications/subscriptions/
POST /api/v1/notifications/subscriptions/
Authorization: Bearer <access_token>
```

Create location subscription:

```json
{
  "subscription_type": "location",
  "village_id": "uuid"
}
```

Create category subscription:

```json
{
  "subscription_type": "category",
  "category_id": "uuid"
}
```

Create breaking/live subscription:

```json
{
  "subscription_type": "breaking"
}
```

Subscription types: `location`, `category`, `breaking`, `live`.

Errors:

- `A valid active location is required.`
- `Category not found or inactive.`

Delete:

```http
DELETE /api/v1/notifications/subscriptions/{subscription_id}/
Authorization: Bearer <access_token>
```

Error: `Subscription not found.`

### Inbox

```http
GET /api/v1/notifications/inbox/?unread=true&page_size=20
Authorization: Bearer <access_token>
```

`unread=true` returns unread. `unread=false` returns read.

Item:

```json
{
  "id": "uuid",
  "notification_id": "uuid",
  "title": "Breaking update",
  "body": "News body",
  "image_url": "",
  "deep_link": "article://article-slug",
  "is_read": false,
  "read_at": null,
  "notification_created_at": "2026-09-04T10:00:00+05:30",
  "created_at": "2026-09-04T10:00:00+05:30"
}
```

Unread count:

```http
GET /api/v1/notifications/inbox/unread-count/
Authorization: Bearer <access_token>
```

Response:

```json
{
  "data": {
    "unread_count": 5
  },
  "meta": {},
  "errors": null
}
```

Mark read:

```http
POST /api/v1/notifications/inbox/{user_notification_id}/read/
Authorization: Bearer <access_token>
```

Error: `Notification not found.`

Push notification frontend flow:

```text
App start
  -> initialize Firebase Messaging
  -> ask notification permission at a good moment
  -> get FCM token
  -> if guest: POST /api/v1/notifications/guest-device/
  -> if logged in: send fcm_token during login/register
  -> on token refresh from Firebase: register again
  -> foreground message: show in-app banner
  -> background tap: parse deep_link
  -> open ArticleDetail, Category, Home, or Notifications screen
```

Deep link examples used by backend/admin:

```text
article://article-slug
screen://bookmarks
varadhi://category/education
```

Flutter should maintain a deep-link parser. If the link is unknown, open HomeScreen.

## 22. Analytics

```http
POST /api/v1/analytics/events/
Content-Type: application/json
Authorization: Bearer <access_token>   # optional
```

Request:

```json
{
  "event_type": "article_open",
  "article_id": "uuid",
  "notification_id": "uuid",
  "category_id": "uuid",
  "state_id": "uuid",
  "district_id": "uuid",
  "subdistrict_id": "uuid",
  "village_id": "uuid",
  "language": "te",
  "device_type": "android",
  "guest_id": "guest-device-123",
  "session_id": "guest-session-123",
  "dwell_seconds": 30,
  "scroll_depth": 80,
  "metadata": {
    "screen": "ArticleDetailScreen"
  }
}
```

For anonymous events, `guest_id` or `session_id` is required.

Success 202:

```json
{
  "data": {
    "status": "accepted"
  },
  "meta": {},
  "errors": null
}
```

Error:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "guest_id or session_id is required for anonymous analytics events.",
    "details": {
      "guest_id": ["guest_id or session_id is required for anonymous analytics events."]
    }
  }
}
```

Frontend rule: analytics failures must not block UI.

## 23. Rewards

All rewards APIs require login.

Wallet:

```http
GET /api/v1/rewards/wallet/
Authorization: Bearer <access_token>
```

Response:

```json
{
  "data": {
    "available_coins": 10,
    "locked_coins": 0,
    "redeemed_coins": 0,
    "lifetime_earned_coins": 10,
    "coin_value_rupees": "1.00",
    "available_value_rupees": "10.00",
    "minimum_withdrawal_coins": 100
  },
  "meta": {},
  "errors": null
}
```

Transactions:

```http
GET /api/v1/rewards/transactions/?page_size=20
Authorization: Bearer <access_token>
```

Transaction item:

```json
{
  "id": "uuid",
  "transaction_type": "earned",
  "coins": 5,
  "value_rupees": "5.00",
  "status": "completed",
  "source_app": "ugc",
  "source_model": "UserNewsSubmission",
  "source_object_id": "uuid",
  "metadata": {},
  "created_at": "2026-09-04T10:00:00+05:30"
}
```

Create payout:

```http
POST /api/v1/rewards/payouts/
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "coins_requested": 100,
  "payout_method": "PHONEPE",
  "payout_mobile": "9876543210",
  "payout_upi_id": "user@upi",
  "payout_account_name": "John Doe",
  "user_notes": "Please send to PhonePe"
}
```

At least one of `payout_mobile`, `payout_upi_id`, or `payout_account_name` is required.

Error:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Provide payout mobile, UPI ID, or account name.",
    "details": {
      "non_field_errors": ["Provide payout mobile, UPI ID, or account name."]
    }
  }
}
```

Payout detail:

```http
GET /api/v1/rewards/payouts/{payout_id}/
Authorization: Bearer <access_token>
```

Error: `Payout request not found.`

## 24. CMS, Quotes, Blogs, E-Paper, TTS

CMS page:

```http
GET /api/v1/cms/{slug}/
```

Response:

```json
{
  "data": {
    "title": "Privacy Policy",
    "slug": "privacy-policy",
    "content": "<p>...</p>"
  },
  "meta": {},
  "errors": null
}
```

Use for About, Privacy Policy, Terms, Contact if pages are configured.

Random quote:

```http
GET /api/v1/quotes/random/
```

Response:

```json
{
  "data": {
    "text": "Quote text",
    "author": "Author"
  },
  "meta": {},
  "errors": null
}
```

Error: `No active quote found.`

Blogs:

```http
GET /api/v1/articles/blogs/
```

Blog fields: `id`, `title`, `slug`, `content`, `thumbnail_url`, `author_name`, `category`, `seo_title`, `seo_description`, `seo_tags`, `published_at`, `view_count`.

E-Papers:

```http
GET /api/v1/articles/epapers/?lang=en
```

E-Paper fields: `id`, `title`, `pdf_url`, `thumbnail_url`, `edition_date`, `publisher_name`, `language`, `page_count`.

TTS:

```http
POST /api/v1/articles/tts/
Content-Type: application/json
```

Request:

```json
{
  "content": "Text to read",
  "language": "te",
  "object_type": "article",
  "object_id": "uuid",
  "force_regenerate": false
}
```

Rules:

- `content` max 5000 characters.
- `object_type`: optional `article` or `blog`.

Content error: `Content length must be <= 5000 characters.`

## 25. Language Architecture

There are two different language concepts.

### APK/UI Language

This controls static Flutter strings:

- Buttons
- Menus
- Navigation labels
- Error display text
- Settings labels

This is owned by Flutter localization. Backend does not translate APK UI strings.

### Content Language

This controls backend content:

- Article language
- Category display names
- Poster language
- Search language
- Featured/recommendation language

Backend behavior:

- `/api/v1/articles/feed/` returns all languages if `lang` is omitted.
- `/api/v1/articles/feed/?lang=te` filters Telugu.
- `/api/v1/feed/` defaults to authenticated user `preferred_language`, else `en`.
- `/api/v1/articles/featured/` defaults to authenticated user `preferred_language`, else `en`.
- `/api/v1/search/` defaults to authenticated user `preferred_language`, else `en`.
- `/api/v1/posters/` filters by `lang` only when `lang` is sent.
- `/api/v1/articles/shorts-feed/` currently returns Telugu shorts only from queryset.

Frontend rule:

- Changing APK/UI language must not automatically change content language unless product wants that.
- Store `uiLanguage` separately from `contentLanguage`.
- Send `contentLanguage` as `lang` to content APIs.
- Save backend `preferred_language` only when the user explicitly changes content preference or profile language.

## 26. Pagination and Infinite Scroll

Backend pagination types:

- Standard cursor pagination: articles, bookmarks, notifications, posters, rewards, UGC.
- Offset-based cursor wrapper: unified feed and locations internally encode offsets as base64 `o:<offset>`.
- Some endpoints are non-paginated: categories, polls, live list, blogs, ads areas.

Flutter pagination flow:

```text
Initial load
  -> request without cursor
  -> render data
  -> store meta.next
  -> when user reaches 80 percent scroll
  -> call meta.next exactly, or extract cursor and call same endpoint
  -> append items by id
  -> stop when meta.next is null
```

Rules:

- Prevent duplicate requests while one page is loading.
- De-duplicate by `id`.
- Pull-to-refresh clears list and cursor, then reloads first page.
- If refresh fails, keep old list and show a non-blocking error.

## 27. Flutter Page Architecture

### Master Page to API Mapping

| Page | Purpose | APIs | When Called | Auth |
| --- | --- | --- | --- | --- |
| SplashScreen | Bootstrap app | health, guest-device, auth/me if token | App launch | Mixed |
| LoginScreen | Sign in | POST auth/login | Submit | No |
| RegisterScreen | Create account | POST auth/register | Submit | No |
| ForgotPasswordScreen | Request reset | password/reset/request | Submit email | No |
| ResetPasswordTokenScreen | Verify token | password/reset/verify | Submit token | No |
| ResetPasswordConfirmScreen | Set password | password/reset/confirm | Submit password | No |
| HomeScreen | Main content | feed, categories, featured, ads, posters, polls | Page load/refresh | No |
| ArticleListScreen | Latest/category/local | articles/feed | Page load/paginate | No |
| ArticleDetailScreen | Full article | article detail, comments, reactions, bookmarks, TTS | Open article | Mixed |
| SearchScreen | Search news | search, trending | Query | No |
| VideoFeedScreen | Video list | articles/video-feed | Page load/paginate | No |
| VideoPlayerScreen | Play selected video | selected video payload | Open video | No |
| ShortsScreen | Vertical reels | articles/shorts-feed | Page load/paginate | No |
| UGCFeedScreen | User news feed | ugc/feed | Page load/paginate | No |
| UGCSubmitScreen | Upload user news | ugc OTP, submit, upload-media | Submit flow | Yes |
| UGCReporterDashboard | My UGC status | reporter/dashboard, reporter/submissions | Open page | Yes |
| LocationSelectionScreen | Pick location | locations/search/list, auth locations | Search/select | Mixed |
| PostersScreen | Poster categories | posters | Page load/filter | No |
| PosterDetailScreen | View/share poster | selected poster payload | Open poster | No |
| AdsBookingScreen | Book advertisement | areas, pricing, bookings | Form flow | No |
| NotificationsScreen | Inbox | inbox, unread-count, mark-read | Open page | Yes |
| NotificationSettingsScreen | Push settings | preferences, subscriptions | Open/save | Yes |
| BookmarksScreen | Saved articles | bookmarks | Open/paginate | Yes |
| ProfileScreen | User profile | auth/me, rewards/wallet | Open | Yes |
| SettingsScreen | App settings | auth/me patch, CMS pages | Open/save | Mixed |
| RewardsScreen | Wallet and payouts | rewards APIs | Open | Yes |
| CMSPageScreen | Static pages | cms/{slug} | Open page | No |

### Complete Navigation Flow

```text
SplashScreen
  -> guest bootstrap
  -> token check
  -> HomeScreen

HomeScreen
  -> ArticleDetailScreen
  -> VideoPlayerScreen
  -> ShortsScreen
  -> SearchScreen
  -> CategoryScreen
  -> UGCFeedScreen
  -> PostersScreen
  -> AdsBookingScreen
  -> NotificationsScreen
  -> ProfileScreen

Protected action without login
  -> LoginPromptBottomSheet
  -> LoginScreen/RegisterScreen
  -> return to original action after success

ArticleDetailScreen
  -> comments sheet
  -> login prompt for comment/bookmark if guest
  -> video fullscreen if article has video

UGCSubmitScreen
  -> if user mobile not verified: SendOTP -> VerifyOTP
  -> Submit UGC metadata
  -> Upload media files if selected
  -> ReporterDashboard
```

## 28. Home Page UI/UX Direction

Use Way2News as a reference for fast local-news scanning, but do not clone it.

Recommended HomeScreen hierarchy:

1. Header
   - VARADHI logo.
   - Current content location: district/village chip.
   - Notification bell with unread badge for logged-in users.
   - Search icon.

2. Category chips
   - Horizontal chips from `/api/v1/categories/`.
   - Use `display_name`, `icon_url`, `color_hex`.
   - First chip: "All".

3. Breaking strip
   - Use `/api/v1/articles/feed/?breaking=true&page_size=5`.
   - Compact horizontal headline ticker.

4. Featured carousel
   - Use `/api/v1/articles/featured/`.
   - Large image, title, category, time.

5. Mixed feed
   - Use `/api/v1/feed/?include=all`.
   - Render article, UGC, and live cards by `type`.

6. Videos section
   - Use `/api/v1/articles/video-feed/?page_size=5`.
   - Horizontal video cards with play icon.

7. Shorts section
   - Use `/api/v1/articles/shorts-feed/?page_size=10`.
   - 9:16 vertical thumbnails.

8. Posters section
   - Use `/api/v1/posters/?lang=<contentLanguage>&page_size=10`.
   - Swipable poster cards.

9. Poll card
   - Use `/api/v1/polls/`.
   - Show first active poll.

10. Ads
   - Use `/api/v1/ads/?zone=feed`.
   - Insert according to `display_frequency`.

Bottom navigation:

- Home
- Videos
- Shorts
- UGC
- Profile

Loading state:

- Header skeleton.
- Category chip skeleton.
- Feed card skeletons with fixed dimensions.
- Do not shift layout when images load.

Empty state:

- "No news found for this location."
- Button: change location.
- Button: refresh.

Error state:

- Keep cached content if available.
- Show snackbar with retry.
- Full-page error only when no cached content exists.

## 29. Screen Design Details

### Article Card

Display fields:

- Image: `thumbnail_url` or first `media_items[].url`.
- Category: `category.display_name`.
- Title: `title`.
- Summary: `summary`.
- Time: `published_at`.
- Location: `district`, `village`.
- Source: `source_name`.
- Badges: `is_breaking`, `is_featured`.
- Counts: `like_count`, `comment_count`.
- Bookmark: `is_bookmarked`.

Actions:

- Tap card: ArticleDetailScreen.
- Tap bookmark: login required, then `/api/v1/bookmarks/toggle/`.
- Tap like/dislike: reaction endpoint; guest allowed with `X-Device-ID`.
- Tap share: use `share_url` if non-null, else build app/web share link if product has one.

### UGC Card

Display fields:

- Image/video: `thumbnail_url`, `media_url`, `media_items`.
- Title: `title`.
- Description: `description`.
- Location: `district`, `village`, `subdistrict`.
- Trust badge: `trust_level`, `trust_score`.
- Uploader: `uploader.display_name`.

Actions:

- Tap video/image: media viewer.
- Report: login required, `/api/v1/ugc/report/`.

### Video Card

Display fields:

- Thumbnail: `thumbnail_url`.
- Play badge if `youtube_video_id`, `youtube_url`, or `video_url` exists.
- Live badge if `is_live`.
- Breaking badge if `is_breaking`.
- Title and channel.

Actions:

- Tap: VideoPlayerScreen.

### Poster Card

Display fields:

- `image_url` or first `images[].image_url`.
- `title`.
- `category`.
- `festival_name` and `event_date` when present.

Actions:

- Open detail carousel.
- Share/download image through Flutter.

## 30. Error Handling Strategy

| Status | Backend Shape | Flutter Handling |
| --- | --- | --- |
| 400 | Envelope with validation details | Show field errors on forms; snackbar for non-form actions |
| 401 | Envelope with auth detail | Try refresh once; if refresh fails, clear tokens and login prompt |
| 403 | Envelope with permission detail | Show "You do not have permission" |
| 404 | Envelope with not found detail | Show not-found state or remove stale item |
| 429 | Envelope/detail throttle | Show wait message; do not retry immediately |
| 500 | `Internal server error. Our team has been notified.` | Show generic retry |
| 502/503 | May be HTML from nginx or envelope from app | Show service unavailable and retry |
| Timeout | No backend body | Show retry/offline banner |
| No internet | No backend body | Use cache and show offline state |

Central API client behavior:

- Parse JSON envelope when `Content-Type` is JSON.
- If response is HTML/plain text, map to network/server error.
- Extract message from `errors.message`.
- For forms, map `errors.details` keys to inputs.
- For background analytics/ad events, fail silently with log only.

## 31. Flutter API Client Architecture

Recommended structure:

```text
lib/
  core/
    network/
      api_client.dart
      auth_interceptor.dart
      api_envelope.dart
      api_error.dart
    storage/
      secure_token_store.dart
      device_id_store.dart
      cache_store.dart
    routing/
      app_router.dart
      deep_link_router.dart
    localization/
      ui_language_controller.dart
    config/
      app_config.dart
  features/
    auth/
    home/
    articles/
    videos/
    shorts/
    ugc/
    search/
    locations/
    ads/
    posters/
    polls/
    notifications/
    bookmarks/
    profile/
    rewards/
    cms/
```

Repository rule:

- UI widgets must not call HTTP client directly.
- Repositories call APIs.
- Controllers/blocs/providers call repositories.
- Models parse `data`, never the full response blindly.

Suggested base envelope:

```dart
class ApiEnvelope<T> {
  final T? data;
  final Map<String, dynamic> meta;
  final ApiError? errors;
}
```

Important models:

- `User`
- `AuthResponse`
- `Category`
- `Article`
- `ArticleMedia`
- `ArticleComment`
- `NewsVideo`
- `UGCSubmission`
- `UGCMediaItem`
- `AdBanner`
- `Poster`
- `Poll`
- `NotificationInboxItem`
- `LocationSearchResult`
- `RewardWallet`

## 32. Backend to Flutter Contract

Backend owns:

- API routes and response shape.
- Authentication and token validity.
- Permissions.
- Business validation.
- Content status and moderation.
- Article/UGC ranking.
- Media upload validation.
- Notification targeting and delivery.
- Pagination.
- Search.
- Location canonical data.

Flutter owns:

- UI rendering.
- Navigation.
- Local state.
- Token storage.
- Local cache.
- Retry/offline UX.
- Video player lifecycle.
- Image caching.
- Pull-to-refresh and infinite scroll.
- Form validation before submit for better UX.

Flutter must not independently implement:

- Article ranking rules.
- UGC moderation decisions.
- UGC OTP bypass rules.
- Notification targeting rules.
- Reward coin calculation.
- Ad pricing calculation.

## 33. Final Flutter Screen List

01. SplashScreen
    - APIs: health, guest-device, auth/me
    - Destination: HomeScreen or LoginScreen when explicitly required

02. LoginScreen
    - APIs: auth/login
    - Destination: HomeScreen or original protected action

03. RegisterScreen
    - APIs: auth/register
    - Destination: HomeScreen

04. ForgotPasswordScreen
    - APIs: password/reset/request
    - Destination: ResetPasswordTokenScreen

05. ResetPasswordTokenScreen
    - APIs: password/reset/verify
    - Destination: ResetPasswordConfirmScreen

06. ResetPasswordConfirmScreen
    - APIs: password/reset/confirm
    - Destination: LoginScreen

07. HomeScreen
    - APIs: feed, categories, featured, ads, posters, polls, video-feed, shorts-feed
    - Destination: content detail screens

08. CategoryScreen
    - APIs: articles/feed with category
    - Destination: ArticleDetailScreen

09. ArticleDetailScreen
    - APIs: article detail, comments, reactions, bookmarks, TTS optional
    - Destination: CommentsSheet, VideoPlayerScreen

10. SearchScreen
    - APIs: search, trending
    - Destination: ArticleDetailScreen

11. VideoFeedScreen
    - APIs: articles/video-feed
    - Destination: VideoPlayerScreen

12. VideoPlayerScreen
    - APIs: none required after selected payload
    - Handles YouTube/direct video

13. ShortsScreen
    - APIs: articles/shorts-feed
    - Full-screen vertical player

14. UGCFeedScreen
    - APIs: ugc/feed
    - Destination: media viewer/report

15. UGCSubmitScreen
    - APIs: ugc/send-otp, ugc/verify-otp, ugc/submit, ugc/upload-media
    - Destination: UGCReporterDashboard

16. UGCReporterDashboard
    - APIs: ugc/reporter/dashboard, ugc/reporter/submissions
    - Destination: submission status list

17. LocationSelectionScreen
    - APIs: locations/search, states, districts, subdistricts, villages, location profile
    - Destination: previous screen/HomeScreen

18. PostersScreen
    - APIs: posters
    - Destination: PosterDetailScreen

19. PosterDetailScreen
    - APIs: none required after selected poster
    - Handles image carousel/share/download

20. AdsBookingScreen
    - APIs: ads/areas, ads/pricing, ads/bookings
    - Destination: booking success

21. NotificationsScreen
    - APIs: inbox, unread-count, mark-read
    - Requires login

22. NotificationSettingsScreen
    - APIs: preferences, subscriptions
    - Requires login

23. BookmarksScreen
    - APIs: bookmarks
    - Requires login

24. ProfileScreen
    - APIs: auth/me, rewards/wallet
    - Requires login for full profile

25. SettingsScreen
    - APIs: auth/me patch, CMS pages
    - Mixed

26. RewardsScreen
    - APIs: rewards/wallet, transactions, payouts
    - Requires login

27. CMSPageScreen
    - APIs: cms/{slug}
    - Public

## 34. Flutter Developer Implementation Checklist

Before development:

- [ ] Configure API base URL.
- [ ] Generate and persist stable device_id.
- [ ] Implement response envelope parser.
- [ ] Implement secure token storage.
- [ ] Implement auth interceptor with one refresh retry.
- [ ] Implement guest FCM registration.
- [ ] Implement Firebase token refresh handling.
- [ ] Implement UI language and content language separately.
- [ ] Implement location selection and canonical location profile.
- [ ] Implement models for all major API payloads.
- [ ] Implement repositories per feature.
- [ ] Implement HomeScreen sections.
- [ ] Implement article feed and detail.
- [ ] Implement multi-image/media carousel for articles.
- [ ] Implement direct video player.
- [ ] Implement YouTube player.
- [ ] Implement Shorts vertical PageView with player disposal.
- [ ] Implement UGC OTP first-time flow.
- [ ] Implement UGC multi-file media upload.
- [ ] Implement comments, reactions, and reports.
- [ ] Implement bookmarks.
- [ ] Implement search with debounce.
- [ ] Implement posters carousel and share/download.
- [ ] Implement ads display, click, and event tracking.
- [ ] Implement ads booking flow.
- [ ] Implement notifications inbox for logged-in users.
- [ ] Implement guest push receive without guest inbox.
- [ ] Implement rewards wallet/payout screens.
- [ ] Implement CMS static page rendering.
- [ ] Implement loading skeletons.
- [ ] Implement empty states.
- [ ] Implement centralized error mapping.
- [ ] Implement pagination and duplicate prevention.
- [ ] Test slow network.
- [ ] Test offline mode.
- [ ] Test expired access token.
- [ ] Test expired/rotated refresh token.
- [ ] Test API validation errors.
- [ ] Test Android app background/resume.
- [ ] Test fullscreen video.
- [ ] Test notification tap deep links.
- [ ] Test image/video upload size failures.
- [ ] Test app restart state restoration.
