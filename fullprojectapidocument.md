# VARADHI Complete Frontend API Documentation

Generated from `openapi-schema.yml`, Django URL routes, DRF views, serializers, permissions, and the unified renderer.

## 1. Overview

Base URL:

```text
https://<api-host>/api/v1
```

Admin API base:

```text
https://<api-host>/admin/api
```

API version: `v1`

Authentication:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

Access labels used in this document:

| Label | Meaning |
| --- | --- |
| PUBLIC | No login required. |
| OPTIONAL AUTH | Works without login; token may add personalized fields. |
| PRIVATE | JWT login required. |
| REPORTER | JWT login required; data is scoped to the logged-in reporter/user. |
| ADMIN | Staff/admin/superuser access required. |
| INTERNAL | Operational endpoint; not for normal app UI. |

Runtime response envelope:

```json
{
  "data": {},
  "meta": {},
  "errors": null
}
```

Paginated runtime response:

```json
{
  "data": [],
  "meta": {
    "count": 0,
    "next": null,
    "previous": null
  },
  "errors": null
}
```

Runtime error response:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Validation error",
    "details": {
      "field": ["This field is required."]
    }
  }
}
```

Contract warning: the requested documentation example showed `errors` as an array. The actual backend renderer returns `errors` as an object with `code`, `message`, and `details`.

Pagination:

Most list APIs use cursor-style pagination when the view returns `results`, `next`, and `previous`. The unified renderer lifts those values into `meta`. Frontend should load the next page by calling `meta.next` exactly as returned. If `meta.next` is `null`, stop infinite scroll.

Language and location:

Common language params are `lang` or `language`. Common location params are `state`, `district`, `city`, `subdistrict`, `village`, `latitude`, and `longitude`. Article/feed endpoints use these to rank or filter local content. Feed endpoints that support `scope` use `scope=main` by default for broad/ranked feeds and `scope=local` for strict local filtering with no fallback to unrelated regions.

## 2. Actual Backend Request Payloads

These examples use the exact field names accepted by the current DRF serializers. Frontend and QA should prefer these over older client examples.

### UGC Submit

`POST /api/v1/ugc/submit/`

Auth: user/reporter JWT required.

```json
{
  "mobile": "9876543210",
  "title": "Suryapet road repair update",
  "description": "Local road repair work started near the market area.",
  "category": "local",
  "content_type": "video",
  "media_url": "",
  "thumbnail_url": "",
  "location_lat": "17.141500",
  "location_lon": "79.623600",
  "village": "",
  "subdistrict": "Suryapet",
  "district": "Suryapet",
  "state": "Telangana",
  "country": "India"
}
```

Required backend fields: `mobile`, `title`, `description`, `content_type`, `location_lat`, `location_lon`.

Valid `content_type` values come from the backend `UserNewsSubmission.ContentType` choices. Use Swagger for the generated enum list.

### UGC Media Upload

`POST /api/v1/ugc/upload-media/`

Auth: user/reporter JWT required.

Multipart form-data:

| Field | Required | Notes |
| --- | --- | --- |
| `submission_id` | Yes | UUID returned by UGC submit. |
| `mobile` | Yes | Must match verified mobile. |
| `media_type` | Yes | Backend media type enum. |
| `file` | Yes | Binary image/video file. |

### Admin Branded Media Upload

`POST /api/v1/ugc/admin/submissions/{submission_id}/branded-media/`

Auth: admin JWT required.

Multipart form-data:

| Field | Required | Notes |
| --- | --- | --- |
| `file` | Yes | Branded image/video file. |
| `thumbnail` | No | Optional binary thumbnail. |
| `notes` | No | Stored as admin notes when provided. |

Public UGC feed returns `media_url`; it does not expose `original_media_url` or `branded_media_url` separately.

### Admin Create Advertisement Area

`POST /api/v1/ads/admin/areas/`

Auth: admin JWT required.

```json
{
  "name": "Suryapet Local Area",
  "state": "Telangana",
  "district": "Suryapet",
  "city": "Suryapet",
  "village": "",
  "subdistrict": "",
  "is_active": true,
  "sort_order": 1
}
```

### Admin Create Advertisement Pricing

`POST /api/v1/ads/admin/pricing/`

Auth: admin JWT required.

```json
{
  "ad_type": "local",
  "area": "08c5c4f8-7334-4135-a6c8-b16c12a7c4de",
  "duration_days": 7,
  "price": "1500.00",
  "currency": "INR",
  "is_active": true
}
```

Important: admin pricing uses `area`, not `area_id`.

### Admin Create Advertisement Banner

`POST /api/v1/ads/admin/`

Auth: admin JWT required.

```json
{
  "title": "Suryapet banner",
  "image_url": "https://cdn.varadhi.example.com/ads/suryapet-banner.jpg",
  "destination_url": "https://wa.me/919876543210",
  "ad_type": "banner",
  "placement_zone": "feed",
  "target_scope": "area",
  "area_id": "08c5c4f8-7334-4135-a6c8-b16c12a7c4de",
  "display_frequency": 1,
  "is_active": true,
  "start_date": "2026-06-28T09:00:00+05:30",
  "end_date": "2026-07-05T09:00:00+05:30"
}
```

Important: admin ad create uses `area_id` for area-targeted ads. `placement_zone` currently supports backend enum values such as `feed`, `article`, `splash`, and `search`; do not send undocumented values like `home_top`.

### Public Advertisement Booking

`POST /api/v1/ads/bookings/`

Auth: not required.

```json
{
  "advertiser_name": "Ravi",
  "phone": "9876543210",
  "business_name": "Ravi Mobiles",
  "ad_type": "local",
  "area_id": "08c5c4f8-7334-4135-a6c8-b16c12a7c4de",
  "duration_days": 7,
  "message": "Need banner ad in Suryapet"
}
```

Local bookings require `area_id`. Main bookings do not require `area_id`.

### Public Advertisement Event

`POST /api/v1/ads/event/`

Auth: not required.

```json
{
  "ad_id": "2c85b3d0-ec89-4bf8-9874-08809c2fbb04",
  "event_type": "impression"
}
```

Valid `event_type` values: `impression`, `click`.

### Admin Create Poster/Card

`POST /api/v1/posters/admin/`

Auth: admin JWT required.

```json
{
  "title": "Daily Quote",
  "category": "daily_quote",
  "image_url": "https://cdn.varadhi.example.com/posters/daily-quote.jpg",
  "thumbnail_url": "",
  "language": "te",
  "festival_name": "",
  "event_date": null,
  "is_active": true,
  "sort_order": 1
}
```

The admin may also upload an `image` file when using multipart form-data. Public `image_url` resolves to uploaded file URL first, then falls back to the text `image_url`.

### Admin Add Poster/Card Image

`POST /api/v1/posters/admin/{poster_id}/images/`

Auth: admin JWT required.

Multipart or JSON-compatible fields:

| Field | Required | Notes |
| --- | --- | --- |
| `image` | No | Binary file upload. |
| `image_url` | No | CDN/remote image URL. |
| `caption` | No | Text caption. |
| `sort_order` | No | Integer ordering. |
| `is_active` | No | Boolean. |

At least one of `image` or `image_url` should be provided for a usable card image.

### Admin Notification Target Preview

`POST /api/v1/notifications/admin/target-preview/`

Auth: admin JWT required.

```json
{
  "target_scope": "category_location",
  "category_slug": "education",
  "state": "Telangana",
  "district": "Suryapet",
  "city": "Suryapet",
  "village": "",
  "subdistrict": ""
}
```

Valid targeting scopes: `all`, `location`, `category`, `category_location`.

### Admin Send Notification

`POST /api/v1/notifications/send/`

Alternative admin route: `POST /admin/api/notifications/send/`

Auth: admin JWT required.

```json
{
  "title": "Education update",
  "body": "New local education update is available.",
  "image_url": "",
  "notification_type": "local",
  "deep_link": "varadhi://category/education",
  "target_scope": "category_location",
  "category_slug": "education",
  "state": "Telangana",
  "district": "Suryapet",
  "city": "Suryapet",
  "village": "",
  "subdistrict": ""
}
```

Important: notification create uses `body`, not `message`. There is no generic `data` request field in the current serializer.

## 3. Frontend Screen to API Mapping

| Frontend Screen | Purpose | APIs Used | Auth Required | Notes |
| --- | --- | --- | --- | --- |
| Splash / App Launch | Optional service check and load cached token/location/language | `GET /api/v1/health/` | No | Do not call on every screen. |
| Onboarding | Register/login, set language/location | `POST /api/v1/auth/register/`, `POST /api/v1/auth/login/`, `POST /api/v1/user/location/`, `PATCH /api/v1/users/me/preferences/` | Mixed | Location/preferences require JWT. |
| Location Selection | Persist user location | `POST /api/v1/user/location/` | Yes | Guest can still pass location params to feed. |
| Language Selection | Persist category/language preference | `PATCH /api/v1/users/me/preferences/`, feed params `lang` | Yes for stored preference | Guest can use `lang` query param. |
| Home Shorts | Shorts-first home UI | `GET /api/v1/articles/shorts-feed/` | No | Cursor paginated. |
| Main News | Personalized main feed | `GET /api/v1/articles/feed/` or `GET /api/v1/feed/` | No | Use `lang`, category and location params. |
| Local News | Strict local news by place | `GET /api/v1/feed/?scope=local&state=&district=&subdistrict=&village=` or `GET /api/v1/ugc/feed/?scope=local&state=&district=` | No | No separate local-news API needed. Empty local results should show app empty state. |
| Article Detail | Full article view | `GET /api/v1/articles/{slug}/` | No | `is_bookmarked=false` for guests. |
| Search | Article/news search | `GET /api/v1/search/?q=` | No | Search endpoint is throttled. |
| Categories | Category selector | `GET /api/v1/categories/` | No | Public. |
| Posters / Info Cards | Poster/cards list, Jyothishyam, Panchangam, health, education, govt cards | `GET /api/v1/posters/?category=` | No | Supports `images[]` for swipe UI; `share_url` is always `null`. |
| Poster Detail / Share | Share poster image | `GET /api/v1/posters/` | No | No poster detail API exists. Use list item data. |
| Post News / UGC Submit | User news submission | `POST /api/v1/ugc/submit/` | Yes | Login required. |
| UGC Media Upload | Upload UGC media | `POST /api/v1/ugc/upload-media/` | Yes | Multipart form data. |
| Reporter Dashboard | Reporter stats | `GET /api/v1/ugc/reporter/dashboard/` | Yes | User-scoped. |
| Reporter Submission List | Reporter submissions and statuses | `GET /api/v1/ugc/reporter/submissions/` | Yes | User-scoped cursor list. |
| Rewards Wallet | User coin balance | `GET /api/v1/rewards/wallet/` | Yes | Coins earned from approved image/video UGC. |
| Rewards Payouts | Manual payout workflow | `GET/POST /api/v1/rewards/payouts/` | Yes | Locks coins while payout is pending. |
| Login | Authenticate user | `POST /api/v1/auth/login/` | No | Store access/refresh tokens. |
| Register | Create account | `POST /api/v1/auth/register/` | No | Device fields required. |
| OTP Verification | UGC mobile verification | `POST /api/v1/ugc/send-otp/`, `POST /api/v1/ugc/verify-otp/` | No | Used for UGC mobile verification flow. |
| Password Reset | Account recovery | `POST /api/v1/auth/password/reset/request/`, `/verify/`, `/confirm/` | No | Email token flow. |
| Profile | View/update account | `GET/PATCH /api/v1/auth/me/` | Yes | JWT required. |
| User Preferences | Category weights | `PATCH /api/v1/users/me/preferences/` | Yes | Category slugs must be active. |
| Bookmarks | Save/read articles | `GET/POST /api/v1/bookmarks/`, `POST /toggle/`, `DELETE /{id}/` | Yes | Guest should show login prompt. |
| Notifications | Inbox/read state | `GET /api/v1/notifications/inbox/`, unread count, mark read | Yes | User-specific data. |
| Polls | Poll list/detail/vote | `GET /api/v1/polls/`, `GET /api/v1/polls/{id}/`, `POST /vote/` | No | Public APK voting. Send `X-Device-ID` to prevent duplicate votes per device. |
| Ads Display | Global and location-matched ads | `GET /api/v1/ads/`, `POST /api/v1/ads/event/` | No | Global ads show everywhere; area ads need matching location/area. |
| Ad Booking | Booking inquiry and WhatsApp handoff | `GET /ads/areas/`, `GET /ads/pricing/`, `POST /ads/bookings/` | No | Backend returns `whatsapp_url`. |
| CMS Pages | Static policy/about pages | `GET /api/v1/cms/{slug}/` | No | Public active pages only. |
| Quotes / Daily Cards | Random quote card | `GET /api/v1/quotes/random/` | No | Public. |
| Admin / Moderator | Editorial, UGC moderation, analytics, system | `/admin/api/...`, selected `/api/v1/...` admin routes | Admin | Not for mobile consumer UI. |

## 4. API Summary Table

The table below lists every OpenAPI operation discovered in the current schema.

| Method | Endpoint | Access | Group | Query / Path Params |
| --- | --- | --- | --- | --- |
| GET | `/admin/api/analytics/content/` | ADMIN / INTERNAL | Admin Analytics | days |
| GET | `/admin/api/analytics/dashboard/` | ADMIN / INTERNAL | Admin Analytics | days |
| GET | `/admin/api/analytics/notifications/` | ADMIN / INTERNAL | Admin Analytics | - |
| GET | `/admin/api/analytics/search/` | ADMIN / INTERNAL | Admin Analytics | days |
| GET | `/admin/api/analytics/ugc/` | ADMIN / INTERNAL | Admin Analytics | - |
| GET | `/admin/api/articles/` | ADMIN / INTERNAL | Admin Articles | author, created_at, status |
| POST | `/admin/api/articles/` | ADMIN / INTERNAL | Admin Articles | - |
| GET | `/admin/api/articles/blogs/` | ADMIN / INTERNAL | Admin Blogs | cursor, page_size |
| POST | `/admin/api/articles/blogs/` | ADMIN / INTERNAL | Admin Blogs | - |
| GET | `/admin/api/articles/blogs/{blog_id}/` | ADMIN / INTERNAL | Admin Blogs | blog_id |
| PATCH | `/admin/api/articles/blogs/{blog_id}/` | ADMIN / INTERNAL | Admin Blogs | blog_id |
| DELETE | `/admin/api/articles/blogs/{blog_id}/` | ADMIN / INTERNAL | Admin Blogs | blog_id |
| GET | `/admin/api/articles/{article_id}/` | ADMIN / INTERNAL | Admin Articles | article_id |
| PATCH | `/admin/api/articles/{article_id}/` | ADMIN / INTERNAL | Admin Articles | article_id |
| POST | `/admin/api/articles/{article_id}/approve/` | ADMIN / INTERNAL | Admin Articles | article_id |
| POST | `/admin/api/articles/{article_id}/archive/` | ADMIN / INTERNAL | Admin Articles | article_id |
| POST | `/admin/api/articles/{article_id}/publish/` | ADMIN / INTERNAL | Admin Articles | article_id |
| POST | `/admin/api/articles/{article_id}/reject/` | ADMIN / INTERNAL | Admin Articles | article_id |
| POST | `/admin/api/articles/thumbnail-upload-url/` | ADMIN / INTERNAL | Admin Articles | - |
| GET | `/admin/api/cms/` | ADMIN / INTERNAL | admin | cursor, ordering, page_size, search |
| POST | `/admin/api/cms/` | ADMIN / INTERNAL | admin | - |
| GET | `/admin/api/cms/{slug}/` | ADMIN / INTERNAL | admin | slug |
| PUT | `/admin/api/cms/{slug}/` | ADMIN / INTERNAL | admin | slug |
| PATCH | `/admin/api/cms/{slug}/` | ADMIN / INTERNAL | admin | slug |
| DELETE | `/admin/api/cms/{slug}/` | ADMIN / INTERNAL | admin | slug |
| GET | `/admin/api/dashboard/queues/` | ADMIN / INTERNAL | Admin Dashboard | - |
| GET | `/admin/api/dashboard/summary/` | ADMIN / INTERNAL | Admin Dashboard | - |
| GET | `/admin/api/epapers/` | ADMIN / INTERNAL | Admin EPapers | is_active, language |
| POST | `/admin/api/epapers/` | ADMIN / INTERNAL | Admin EPapers | - |
| PATCH | `/admin/api/epapers/{epaper_id}/` | ADMIN / INTERNAL | Admin EPapers | epaper_id |
| DELETE | `/admin/api/epapers/{epaper_id}/` | ADMIN / INTERNAL | Admin EPapers | epaper_id |
| POST | `/admin/api/epapers/{epaper_id}/activate/` | ADMIN / INTERNAL | Admin EPapers | epaper_id |
| POST | `/admin/api/epapers/{epaper_id}/deactivate/` | ADMIN / INTERNAL | Admin EPapers | epaper_id |
| GET | `/admin/api/notifications/` | ADMIN / INTERNAL | Admin Notifications | status |
| GET | `/admin/api/notifications/{notification_id}/` | ADMIN / INTERNAL | Admin Notifications | notification_id |
| POST | `/admin/api/notifications/{notification_id}/retry-failed/` | ADMIN / INTERNAL | Admin Notifications | notification_id |
| POST | `/admin/api/notifications/send/` | ADMIN / INTERNAL | Admin Notifications | - |
| POST | `/admin/api/notifications/target-preview/` | ADMIN / INTERNAL | Admin Notifications | target_scope, location/category |
| GET | `/admin/api/polls/` | ADMIN / INTERNAL | Admin Polls | is_active |
| POST | `/admin/api/polls/` | ADMIN / INTERNAL | Admin Polls | - |
| GET | `/admin/api/polls/{poll_id}/` | ADMIN / INTERNAL | Admin Polls | poll_id |
| PATCH | `/admin/api/polls/{poll_id}/` | ADMIN / INTERNAL | Admin Polls | poll_id |
| DELETE | `/admin/api/polls/{poll_id}/` | ADMIN / INTERNAL | Admin Polls | poll_id |
| POST | `/admin/api/polls/{poll_id}/close/` | ADMIN / INTERNAL | Admin Polls | poll_id |
| GET | `/admin/api/polls/{poll_id}/results/` | ADMIN / INTERNAL | Admin Polls | poll_id |
| GET | `/admin/api/quotes/` | ADMIN / INTERNAL | admin | cursor, ordering, page_size, search |
| POST | `/admin/api/quotes/` | ADMIN / INTERNAL | admin | - |
| GET | `/admin/api/quotes/{id}/` | ADMIN / INTERNAL | admin | id |
| PUT | `/admin/api/quotes/{id}/` | ADMIN / INTERNAL | admin | id |
| PATCH | `/admin/api/quotes/{id}/` | ADMIN / INTERNAL | admin | id |
| DELETE | `/admin/api/quotes/{id}/` | ADMIN / INTERNAL | admin | id |
| GET | `/admin/api/search/logs/` | ADMIN / INTERNAL | Admin Search | is_anonymized, keyword, zero_results |
| POST | `/admin/api/search/logs/anonymize/` | ADMIN / INTERNAL | Admin Search | - |
| GET | `/admin/api/search/trending/` | ADMIN / INTERNAL | Admin Search | days, limit |
| GET | `/admin/api/search/zero-results/` | ADMIN / INTERNAL | Admin Search | days, limit |
| GET | `/admin/api/system/health/` | ADMIN / INTERNAL | System | - |
| GET | `/admin/api/system/readiness/` | ADMIN / INTERNAL | Admin System | - |
| GET | `/admin/api/system/release-audit/` | ADMIN / INTERNAL | Admin System | - |
| GET | `/admin/api/ugc/otp-deliveries/` | ADMIN / INTERNAL | UGC Admin | cursor, page_size |
| GET | `/admin/api/ugc/queue/` | ADMIN / INTERNAL | UGC Admin | cursor, page_size |
| GET | `/admin/api/ugc/submissions/{submission_id}/` | ADMIN / INTERNAL | UGC Admin | submission_id |
| POST | `/admin/api/ugc/submissions/{submission_id}/approve/` | ADMIN / INTERNAL | UGC Admin | submission_id |
| POST | `/admin/api/ugc/submissions/{submission_id}/flag/` | ADMIN / INTERNAL | UGC Admin | submission_id |
| POST | `/admin/api/ugc/submissions/{submission_id}/reject/` | ADMIN / INTERNAL | UGC Admin | submission_id |
| GET | `/admin/api/users/` | ADMIN / INTERNAL | Admin Users | is_active, q |
| GET | `/admin/api/users/{user_id}/` | ADMIN / INTERNAL | Admin Users | user_id |
| POST | `/admin/api/users/{user_id}/activate/` | ADMIN / INTERNAL | Admin Users | user_id |
| POST | `/admin/api/users/{user_id}/deactivate/` | ADMIN / INTERNAL | Admin Users | user_id |
| GET | `/api/v1/ads/` | PUBLIC | Ads | zone, placement_zone, scope, area_id, state, district, city, subdistrict, village |
| GET | `/api/v1/ads/admin/` | ADMIN / INTERNAL | Ads | - |
| POST | `/api/v1/ads/admin/` | ADMIN / INTERNAL | Ads | - |
| GET | `/api/v1/ads/admin/{ad_id}/` | ADMIN / INTERNAL | Ads | ad_id |
| PATCH | `/api/v1/ads/admin/{ad_id}/` | ADMIN / INTERNAL | Ads | ad_id |
| DELETE | `/api/v1/ads/admin/{ad_id}/` | ADMIN / INTERNAL | Ads | ad_id |
| GET | `/api/v1/ads/admin/areas/` | ADMIN / INTERNAL | Ads | - |
| POST | `/api/v1/ads/admin/areas/` | ADMIN / INTERNAL | Ads | - |
| PATCH | `/api/v1/ads/admin/areas/{area_id}/` | ADMIN / INTERNAL | Ads | area_id |
| GET | `/api/v1/ads/admin/pricing/` | ADMIN / INTERNAL | Ads | - |
| POST | `/api/v1/ads/admin/pricing/` | ADMIN / INTERNAL | Ads | - |
| PATCH | `/api/v1/ads/admin/pricing/{pricing_id}/` | ADMIN / INTERNAL | Ads | pricing_id |
| GET | `/api/v1/ads/admin/bookings/` | ADMIN / INTERNAL | Ads | status |
| PATCH | `/api/v1/ads/admin/bookings/{booking_id}/` | ADMIN / INTERNAL | Ads | booking_id |
| GET | `/api/v1/ads/areas/` | PUBLIC | Ads | - |
| POST | `/api/v1/ads/bookings/` | PUBLIC | Ads | - |
| POST | `/api/v1/ads/event/` | PUBLIC | Ads | - |
| GET | `/api/v1/ads/pricing/` | PUBLIC | Ads | ad_type, area_id, duration_days |
| GET | `/api/v1/analytics/dashboard/` | ADMIN / INTERNAL | Analytics | days |
| GET | `/api/v1/analytics/user-preferences/` | ADMIN / INTERNAL | Analytics | - |
| POST | `/api/v1/articles/` | PRIVATE / CONTRIBUTOR | Feed & Articles | - |
| GET | `/api/v1/articles/{slug}/` | PUBLIC | Feed & Articles | slug |
| GET | `/api/v1/articles/blogs/` | PUBLIC | Blogs | - |
| GET | `/api/v1/articles/editorial/queue/` | ADMIN / INTERNAL | Editorial | author, created_at, status |
| GET | `/api/v1/articles/epapers/` | PUBLIC | E-Paper | lang |
| GET | `/api/v1/articles/featured/` | PUBLIC | Feed & Articles | lang |
| GET | `/api/v1/articles/feed/` | PUBLIC | Feed & Articles | breaking, category, city, cursor, district, lang, latitude, longitude, page_size, scope, state, subdistrict, village |
| GET | `/api/v1/articles/live/` | PUBLIC | Live News | - |
| GET | `/api/v1/articles/recommendation-metrics/` | ADMIN / INTERNAL | api | - |
| POST | `/api/v1/articles/recommendation/click/` | PUBLIC | Feed & Articles | - |
| POST | `/api/v1/articles/recommendation/dwell/` | PUBLIC | Feed & Articles | - |
| POST | `/api/v1/articles/recommendation/impression/` | PUBLIC | Feed & Articles | - |
| GET | `/api/v1/articles/recommendations/` | PUBLIC | Feed & Articles | category, city, district, lang, limit, state, subdistrict, village |
| GET | `/api/v1/articles/shorts-feed/` | PUBLIC | Videos | cursor, lang, page_size, scope, state, district, city, subdistrict, village |
| POST | `/api/v1/articles/tts/` | PUBLIC | TTS | - |
| GET | `/api/v1/articles/tts/stats/` | ADMIN / INTERNAL | api | - |
| GET | `/api/v1/articles/tts/status/{task_id}/` | PUBLIC | TTS | task_id |
| GET | `/api/v1/articles/video-feed/` | PUBLIC | Videos | cursor, lang, page_size, scope, state, district, city, subdistrict, village |
| POST | `/api/v1/auth/login/` | PUBLIC | Auth | - |
| POST | `/api/v1/auth/logout/` | PRIVATE | Auth | - |
| GET | `/api/v1/auth/me/` | PRIVATE | Auth | - |
| PATCH | `/api/v1/auth/me/` | PRIVATE | Auth | - |
| POST | `/api/v1/auth/password/change/` | PRIVATE | Auth | - |
| POST | `/api/v1/auth/password/reset/confirm/` | PUBLIC | Auth | - |
| POST | `/api/v1/auth/password/reset/request/` | PUBLIC | Auth | - |
| POST | `/api/v1/auth/password/reset/verify/` | PUBLIC | Auth | - |
| POST | `/api/v1/auth/register/` | PUBLIC | Auth | - |
| POST | `/api/v1/auth/revoke/` | PRIVATE | api | - |
| GET | `/api/v1/auth/sessions/` | PRIVATE | Auth | - |
| DELETE | `/api/v1/auth/sessions/{session_id}/` | PRIVATE | Auth | session_id |
| POST | `/api/v1/auth/token/refresh/` | PUBLIC | Auth | - |
| GET | `/api/v1/bookmarks/` | PRIVATE | Bookmarks | - |
| POST | `/api/v1/bookmarks/` | PRIVATE | Bookmarks | - |
| DELETE | `/api/v1/bookmarks/{bookmark_id}/` | PRIVATE | Bookmarks | bookmark_id |
| POST | `/api/v1/bookmarks/toggle/` | PRIVATE | Bookmarks | - |
| GET | `/api/v1/categories/` | PUBLIC | Categories | - |
| POST | `/api/v1/categories/admin/` | ADMIN / INTERNAL | Categories | - |
| PATCH | `/api/v1/categories/admin/{slug}/` | ADMIN / INTERNAL | Categories | slug |
| DELETE | `/api/v1/categories/admin/{slug}/` | ADMIN / INTERNAL | Categories | slug |
| GET | `/api/v1/cms/{slug}/` | PUBLIC | CMS | slug |
| GET | `/api/v1/feed/` | PUBLIC | Unified Feed | category, city, cursor, district, include, lang, language, page_size, scope, state, subdistrict, village |
| GET | `/api/v1/health/` | PUBLIC | System | - |
| GET | `/api/v1/live/channel-info/` | ADMIN / INTERNAL | Live News | - |
| GET | `/api/v1/notifications/` | PRIVATE | Notifications | - |
| GET | `/api/v1/notifications/{notification_id}/` | PRIVATE | Notifications | notification_id |
| GET | `/api/v1/notifications/inbox/` | PRIVATE | Notifications | unread |
| GET | `/api/v1/notifications/inbox/{user_notification_id}/` | PRIVATE | Notifications | user_notification_id |
| POST | `/api/v1/notifications/inbox/{user_notification_id}/read/` | PRIVATE | Notifications | user_notification_id |
| GET | `/api/v1/notifications/inbox/unread-count/` | PRIVATE | Notifications | - |
| POST | `/api/v1/notifications/send/` | ADMIN / INTERNAL | Notifications | target_scope, category/location |
| POST | `/api/v1/notifications/admin/target-preview/` | ADMIN / INTERNAL | Notifications | target_scope, category/location |
| GET | `/api/v1/polls/` | PUBLIC | Polls | - |
| GET | `/api/v1/polls/{poll_id}/` | PUBLIC | Polls | poll_id |
| POST | `/api/v1/polls/{poll_id}/vote/` | PUBLIC | Polls | poll_id |
| POST | `/api/v1/polls/admin/` | ADMIN / INTERNAL | Polls | - |
| GET | `/api/v1/posters/` | PUBLIC | Posters | category, cursor, lang, page_size |
| GET | `/api/v1/posters/admin/` | ADMIN / INTERNAL | Posters Admin | category, cursor, page_size |
| POST | `/api/v1/posters/admin/` | ADMIN / INTERNAL | Posters Admin | - |
| GET | `/api/v1/posters/admin/{poster_id}/` | ADMIN / INTERNAL | Posters Admin | poster_id |
| PATCH | `/api/v1/posters/admin/{poster_id}/` | ADMIN / INTERNAL | Posters Admin | poster_id |
| DELETE | `/api/v1/posters/admin/{poster_id}/` | ADMIN / INTERNAL | Posters Admin | poster_id |
| POST | `/api/v1/posters/admin/{poster_id}/images/` | ADMIN / INTERNAL | Posters Admin | poster_id |
| PATCH | `/api/v1/posters/admin/{poster_id}/images/{image_id}/` | ADMIN / INTERNAL | Posters Admin | poster_id, image_id |
| DELETE | `/api/v1/posters/admin/{poster_id}/images/{image_id}/` | ADMIN / INTERNAL | Posters Admin | poster_id, image_id |
| GET | `/api/v1/quotes/random/` | PUBLIC | Quotes | - |
| GET | `/api/v1/search/` | PUBLIC | Search | category, lang, q |
| GET | `/api/v1/search/trending/` | PUBLIC | Search | days |
| GET | `/api/v1/search/zero-results/` | PUBLIC | Search | days |
| GET | `/api/v1/system/health/` | ADMIN / INTERNAL | System | - |
| GET | `/api/v1/rewards/wallet/` | PRIVATE | Rewards | - |
| GET | `/api/v1/rewards/transactions/` | PRIVATE | Rewards | cursor, page_size |
| GET | `/api/v1/rewards/payouts/` | PRIVATE | Rewards | cursor, page_size |
| POST | `/api/v1/rewards/payouts/` | PRIVATE | Rewards | - |
| GET | `/api/v1/rewards/payouts/{payout_id}/` | PRIVATE | Rewards | payout_id |
| GET | `/api/v1/rewards/admin/dashboard/` | ADMIN / INTERNAL | Rewards Admin | - |
| GET | `/api/v1/rewards/admin/wallets/` | ADMIN / INTERNAL | Rewards Admin | user, q, has_balance, cursor, page_size |
| GET | `/api/v1/rewards/admin/wallets/{user_id}/` | ADMIN / INTERNAL | Rewards Admin | user_id |
| POST | `/api/v1/rewards/admin/wallets/{user_id}/adjust/` | ADMIN / INTERNAL | Rewards Admin | user_id |
| GET | `/api/v1/rewards/admin/transactions/` | ADMIN / INTERNAL | Rewards Admin | user_id, transaction_type, date_from, date_to, cursor, page_size |
| GET | `/api/v1/rewards/admin/payouts/` | ADMIN / INTERNAL | Rewards Admin | status, payout_method, user_id, date_from, date_to, cursor, page_size |
| GET | `/api/v1/rewards/admin/payouts/{payout_id}/` | ADMIN / INTERNAL | Rewards Admin | payout_id |
| POST | `/api/v1/rewards/admin/payouts/{payout_id}/mark-paid/` | ADMIN / INTERNAL | Rewards Admin | payout_id |
| POST | `/api/v1/rewards/admin/payouts/{payout_id}/reject/` | ADMIN / INTERNAL | Rewards Admin | payout_id |
| GET | `/api/v1/rewards/admin/settings/` | ADMIN / INTERNAL | Rewards Admin | - |
| PATCH | `/api/v1/rewards/admin/settings/` | ADMIN / INTERNAL | Rewards Admin | - |
| POST | `/api/v1/ugc/admin/submissions/{submission_id}/branded-media/` | ADMIN / INTERNAL | UGC Admin | multipart file, optional thumbnail, notes |
| GET | `/api/v1/ugc/feed/` | PUBLIC | UGC | city, cursor, district, page_size, scope, state, subdistrict, village |
| GET | `/api/v1/ugc/moderation/queue/` | ADMIN / INTERNAL | UGC Admin | cursor, page_size |
| POST | `/api/v1/ugc/report/` | PRIVATE | UGC | - |
| GET | `/api/v1/ugc/reporter/dashboard/` | PRIVATE | UGC Reporter | - |
| GET | `/api/v1/ugc/reporter/submissions/` | PRIVATE | UGC Reporter | cursor, page_size, status |
| POST | `/api/v1/ugc/send-otp/` | PUBLIC | UGC | - |
| POST | `/api/v1/ugc/submit/` | PRIVATE | UGC | - |
| POST | `/api/v1/ugc/upload-media/` | PRIVATE | UGC | - |
| POST | `/api/v1/ugc/verify-otp/` | PUBLIC | UGC | - |
| POST | `/api/v1/user/location/` | PRIVATE | Users | - |
| PATCH | `/api/v1/users/me/preferences/` | PRIVATE | Users | - |

## 5. Detailed Frontend API Contracts

### 4.1 Auth / Accounts

#### Register

Purpose: create an account and device session.

Frontend screen: Register / Onboarding.

Access: PUBLIC.

Method and endpoint:

```http
POST /api/v1/auth/register/
```

Request:

```json
{
  "email": "ravi@example.com",
  "password": "StrongPass123!",
  "password_confirm": "StrongPass123!",
  "full_name": "Ravi Kumar",
  "preferred_language": "te",
  "device_id": "android-uuid-123",
  "device_name": "Pixel 8",
  "device_type": "android",
  "fcm_token": "optional-fcm-token"
}
```

Response:

```json
{
  "data": {
    "access": "jwt-access-token",
    "refresh": "jwt-refresh-token",
    "session_id": "1d0d9b0e-88ec-45ca-924b-5d9ba0615f10",
    "user": {
      "id": "c52f9153-d3b6-45e8-99dd-ffbf6a44bb16",
      "email": "ravi@example.com",
      "full_name": "Ravi Kumar",
      "profile_image": null,
      "preferred_language": "te",
      "theme": "system",
      "font_size": 16,
      "is_contributor": false,
      "is_admin": false,
      "created_at": "2026-06-22T10:00:00+05:30"
    }
  },
  "meta": {},
  "errors": null
}
```

Status codes: `201`, `400`, `429`, `500`.

#### Login

Purpose: authenticate and create/update a device session.

Access: PUBLIC.

```http
POST /api/v1/auth/login/
```

Request:

```json
{
  "email": "ravi@example.com",
  "password": "StrongPass123!",
  "device_id": "android-uuid-123",
  "device_name": "Pixel 8",
  "device_type": "android",
  "fcm_token": "optional-fcm-token"
}
```

Response: same auth token shape as register.

Status codes: `200`, `400`, `401`, `429`, `500`.

#### Refresh Token

Access: PUBLIC.

```http
POST /api/v1/auth/token/refresh/
```

Request:

```json
{
  "refresh": "jwt-refresh-token",
  "device_id": "android-uuid-123"
}
```

Response:

```json
{
  "data": {
    "access": "new-access-token",
    "refresh": "new-refresh-token"
  },
  "meta": {},
  "errors": null
}
```

#### Logout / Revoke

Access: PRIVATE.

```http
POST /api/v1/auth/logout/
POST /api/v1/auth/revoke/
```

Logout request:

```json
{
  "refresh": "jwt-refresh-token",
  "logout_all_devices": false
}
```

#### Profile

Access: PRIVATE.

```http
GET /api/v1/auth/me/
PATCH /api/v1/auth/me/
```

Patch request:

```json
{
  "full_name": "Ravi Kumar",
  "preferred_language": "te",
  "theme": "system",
  "font_size": 16
}
```

Profile fields: `id`, `email`, `full_name`, `profile_image`, `preferred_language`, `theme`, `font_size`, `is_contributor`, `is_admin`, `created_at`.

#### Password APIs

Access:

| API | Access |
| --- | --- |
| `POST /api/v1/auth/password/change/` | PRIVATE |
| `POST /api/v1/auth/password/reset/request/` | PUBLIC |
| `POST /api/v1/auth/password/reset/verify/` | PUBLIC |
| `POST /api/v1/auth/password/reset/confirm/` | PUBLIC |

Password change request:

```json
{
  "current_password": "OldPass123!",
  "new_password": "NewPass123!",
  "new_password_confirm": "NewPass123!"
}
```

Password reset request:

```json
{
  "email": "ravi@example.com"
}
```

Password reset verify:

```json
{
  "email": "ravi@example.com",
  "token": "reset-token-from-email"
}
```

Password reset confirm:

```json
{
  "email": "ravi@example.com",
  "token": "reset-token-from-email",
  "new_password": "NewPass123!",
  "new_password_confirm": "NewPass123!"
}
```

#### Device Sessions

Access: PRIVATE.

```http
GET /api/v1/auth/sessions/
DELETE /api/v1/auth/sessions/{session_id}/
```

Session fields: `id`, `device_name`, `device_type`, `last_used_at`, `ip_address`, `is_active`, `created_at`.

#### User Location and Preferences

Access: PRIVATE.

```http
POST /api/v1/user/location/
PATCH /api/v1/users/me/preferences/
```

Location request:

```json
{
  "lat": 17.385,
  "lon": 78.4867,
  "city": "Hyderabad",
  "state": "Telangana",
  "country": "India"
}
```

Location response fields: `lat`, `lon`, `village`, `city`, `subdistrict`, `district`, `state`, `country`, `location_source`, `location_updated_at`.

Preferences request:

```json
{
  "category_weights": {
    "local": 1.0,
    "politics": 0.7,
    "sports": 0.5
  }
}
```

Preferences response fields: `user`, `category_weights`, `top_categories`, `updated_at`.

### 4.2 Articles / News

#### Article Feed

Purpose: main/home/local article feed.

Frontend screen: Home, Main News, Local News, Category News.

Access: PUBLIC. Token is optional in practice for personalized fields such as `is_bookmarked`.

```http
GET /api/v1/articles/feed/
```

Query params:

| Param | Type | Required | Example | Purpose |
| --- | --- | --- | --- | --- |
| `cursor` | string | No | `cD0...` | Next page cursor. |
| `page_size` | integer | No | `20` | Page size. |
| `lang` | string | No | `te` | Language filter/preference. |
| `category` | string | No | `politics` | Category filter/ranking. |
| `breaking` | boolean | No | `true` | Return breaking articles only. |
| `state` | string | No | `Telangana` | Location ranking/filter. |
| `district` | string | No | `Hyderabad` | Location ranking/filter. |
| `city` | string | No | `Hyderabad` | City alias. |
| `subdistrict` | string | No | `Secunderabad` | Local ranking. |
| `village` | string | No | `Madhapur` | Local ranking. |
| `latitude` | number | No | `17.385` | Proximity ranking. |
| `longitude` | number | No | `78.4867` | Proximity ranking. |

Response item fields from `ArticleFeedSerializer`:

`id`, `title`, `slug`, `summary`, `thumbnail_url`, `category`, `author_name`, `source_name`, `language`, `is_featured`, `is_breaking`, `is_bookmarked`, `share_url`, `read_time_minutes`, `view_count`, `published_at`, `state`, `district`, `village`, `subdistrict`, `is_regional`, `priority_score`, `location_tags`.

Example:

```json
{
  "data": [
    {
      "id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
      "title": "Metro services extended in Hyderabad",
      "slug": "metro-services-extended-hyderabad",
      "summary": "Metro timings have been extended for the weekend.",
      "thumbnail_url": "https://cdn.varadhi.example.com/articles/metro.jpg",
      "category": {
        "id": "2d35a2f8-0e71-45c0-a2d1-fec74ec1b7ff",
        "name": "Local",
        "slug": "local",
        "icon": "",
        "order": 1,
        "is_active": true
      },
      "author_name": "VARADHI News",
      "source_name": "Reporter",
      "language": "te",
      "is_featured": false,
      "is_breaking": true,
      "is_bookmarked": false,
      "share_url": null,
      "read_time_minutes": 2,
      "view_count": 125,
      "published_at": "2026-06-22T08:30:00+05:30",
      "state": "Telangana",
      "district": "Hyderabad",
      "village": "",
      "subdistrict": "",
      "is_regional": true,
      "priority_score": 90,
      "location_tags": ["Hyderabad"]
    }
  ],
  "meta": {
    "count": null,
    "next": null,
    "previous": null
  },
  "errors": null
}
```

Empty state:

```json
{
  "data": [],
  "meta": {
    "count": 0,
    "next": null,
    "previous": null
  },
  "errors": null
}
```

Status codes: `200`, `400`, `429`, `500`.

#### Article Detail

Purpose: full article body by slug.

Access: PUBLIC.

```http
GET /api/v1/articles/{slug}/
```

Response fields from `ArticleDetailSerializer`: feed fields plus `content`, `source_url`, `source_logo_url`, `seo_title`, `seo_description`, `seo_tags`, and `tts_url`. Detail does not include `state` or `district` in the serializer.

Example:

```json
{
  "data": {
    "id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
    "title": "Metro services extended in Hyderabad",
    "slug": "metro-services-extended-hyderabad",
    "summary": "Metro timings have been extended for the weekend.",
    "content": "Full article body...",
    "thumbnail_url": "https://cdn.varadhi.example.com/articles/metro.jpg",
    "category": {
      "id": "2d35a2f8-0e71-45c0-a2d1-fec74ec1b7ff",
      "name": "Local",
      "slug": "local",
      "icon": "",
      "order": 1,
      "is_active": true
    },
    "author_name": "VARADHI News",
    "source_url": "https://example.com/source",
    "source_name": "Reporter",
    "source_logo_url": "",
    "language": "te",
    "is_featured": false,
    "is_breaking": true,
    "seo_title": "",
    "seo_description": "",
    "seo_tags": [],
    "read_time_minutes": 2,
    "view_count": 126,
    "published_at": "2026-06-22T08:30:00+05:30",
    "is_bookmarked": false,
    "share_url": null,
    "village": "",
    "subdistrict": "",
    "tts_url": ""
  },
  "meta": {},
  "errors": null
}
```

Status codes: `200`, `404`, `429`, `500`.

#### Featured Articles

Access: PUBLIC.

```http
GET /api/v1/articles/featured/?lang=te
```

Response: list of `ArticleFeedSerializer` items in the envelope.

#### Recommendations

Access: PUBLIC.

```http
GET /api/v1/articles/recommendations/
```

Query params: `limit`, `lang`, `state`, `district`, `city`, `village`, `subdistrict`, `category`.

Response: non-cursor list of `RecommendationSerializer` article items. Additional field: `tts_url`.

Contract warning: recommendations are not cursor paginated. Use `limit`, not `cursor`.

#### Recommendation Tracking

Access: PUBLIC, throttled.

```http
POST /api/v1/articles/recommendation/impression/
POST /api/v1/articles/recommendation/click/
POST /api/v1/articles/recommendation/dwell/
```

Impression/click request:

```json
{
  "article_id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
  "session_id": "guest-session-123"
}
```

Dwell request:

```json
{
  "article_id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
  "seconds": 18,
  "session_id": "guest-session-123"
}
```

Status codes: `200`, `400`, `429`, `500`.

#### Live News

Access: PUBLIC.

```http
GET /api/v1/articles/live/
```

Fields from `LiveNewsSerializer`: `id`, `title`, `youtube_url`, `youtube_video_id`, `thumbnail_url`, `description`, `channel_name`, `is_active`, `autoplay`, `sort_order`.

#### Video Feed

Access: PUBLIC.

```http
GET /api/v1/articles/video-feed/?lang=te&page_size=20
GET /api/v1/articles/video-feed/?scope=local&state=Telangana&district=Suryapet&lang=te&page_size=20
```

Location note: video feed supports `scope=main` for broad/ranked video results and `scope=local` for strict local filtering when `NewsVideo` location fields are populated. Local scope accepts `state`, `district`, `city`, `subdistrict`, and `village`; legacy videos without deep location remain available in main scope and do not appear in strict local results.

Fields include: `id`, `title`, `youtube_video_id`, `youtube_url`, `thumbnail_url`, `description`, `channel_name`, `published_at`, `is_live`, `is_trending`, `is_breaking`, `is_short`, `video_priority`, `state`, `district`, `city`, `subdistrict`, `village`, `location_tags`, `language`, `views_count`, `likes_count`, `concurrent_viewers`, `duration_seconds`, `created_at`, `updated_at`.

Contract warning: first-page live items may omit optional `NewsVideo` fields. If `is_live=true`, treat `duration_seconds`, `concurrent_viewers`, `likes_count`, `views_count`, `state`, `district`, `city`, `subdistrict`, `village`, `location_tags`, `language`, `created_at`, and `updated_at` as optional.

#### Shorts Feed

Access: PUBLIC.

```http
GET /api/v1/articles/shorts-feed/?lang=te&page_size=20
GET /api/v1/articles/shorts-feed/?scope=local&state=Telangana&district=Suryapet&lang=te&page_size=20
```

Location note: shorts feed uses the same strict local filtering as video feed. Use `scope=local` with APK location params for local shorts. Items without matching deep location fields are excluded from local scope.

Fields from `ShortsVideoSerializer`: `id`, `title`, `thumbnail_url`, `youtube_video_id`, `youtube_url`, `is_live`, `is_breaking`, `is_trending`, `channel_name`, `video_priority`, `is_short`, `duration_seconds`, `state`, `district`, `city`, `subdistrict`, `village`, `location_tags`.

#### Blogs, EPapers, TTS

| API | Access | Purpose |
| --- | --- | --- |
| `GET /api/v1/articles/blogs/` | PUBLIC | Short blog list. |
| `GET /api/v1/articles/epapers/?lang=te` | PUBLIC | E-paper list with pre-signed `pdf_url`. |
| `POST /api/v1/articles/tts/` | PUBLIC | Generate/fetch text-to-speech audio. |
| `GET /api/v1/articles/tts/status/{task_id}/` | PUBLIC | Poll async TTS task status. |

Admin blog workflow:

```http
GET /admin/api/articles/blogs/
POST /admin/api/articles/blogs/
GET /admin/api/articles/blogs/{blog_id}/
PATCH /admin/api/articles/blogs/{blog_id}/
DELETE /admin/api/articles/blogs/{blog_id}/
```

Access: ADMIN / INTERNAL. Delete is soft delete. Public mobile apps should continue to read blogs from `GET /api/v1/articles/blogs/`.

Create/update payload:

```json
{
  "title": "Short Blog",
  "slug": "short-blog",
  "content": "This is a short backend verified blog.",
  "thumbnail_url": "",
  "category": "7c7b120a-6b79-4926-972e-e08ba616ec9e",
  "seo_title": "",
  "seo_description": "",
  "seo_tags": [],
  "is_published": true,
  "scheduled_at": null
}
```

`content` is limited to short blog content by backend validation. `author` defaults to the authenticated admin user when omitted.

Admin article create workflow:

```http
POST /admin/api/articles/
```

Access: ADMIN / INTERNAL. Use JWT bearer token from an admin user. The authenticated admin user becomes the article `author`.

Request fields:

`title`, `summary`, `content`, `thumbnail_url`, `thumbnail_upload`, `category`, `language`, `is_featured`, `is_breaking`, `status`, `scheduled_at`, `seo_title`, `seo_description`, `seo_tags`, `source_url`, `source_name`, `state`, `district`, `city`, `village`, `subdistrict`, `priority_score`, `location_tags`.

Request example:

```json
{
  "title": "Hyderabad Metro services extended",
  "summary": "Metro services will run longer for festival traffic.",
  "content": "Full article body content for the admin-created news story.",
  "thumbnail_url": "https://cdn.varadhi.example.com/articles/metro.jpg",
  "category": "7c7b120a-6b79-4926-972e-e08ba616ec9e",
  "language": "en",
  "status": "published",
  "is_featured": false,
  "is_breaking": true,
  "state": "Telangana",
  "district": "Hyderabad",
  "city": "Hyderabad",
  "village": "Madhapur",
  "subdistrict": "Serilingampally",
  "priority_score": 10,
  "location_tags": ["Telangana", "Hyderabad", "Madhapur", "Serilingampally"],
  "seo_title": "Hyderabad Metro services extended",
  "seo_description": "Metro services will run longer for festival traffic.",
  "seo_tags": ["hyderabad", "metro"],
  "source_name": "VARADHI Desk"
}
```

Multipart upload example:

```http
POST /admin/api/articles/
Content-Type: multipart/form-data
Authorization: Bearer <admin_access_token>
```

Form fields:

```text
title=Hyderabad Metro services extended
summary=Metro services will run longer for festival traffic.
content=Full article body content for the admin-created news story.
thumbnail_upload=<image file>
category=7c7b120a-6b79-4926-972e-e08ba616ec9e
language=en
status=published
is_featured=false
is_breaking=true
state=Telangana
district=Hyderabad
city=Hyderabad
village=Madhapur
subdistrict=Serilingampally
priority_score=10
location_tags=["Telangana","Hyderabad","Madhapur","Serilingampally"]
source_name=VARADHI Desk
```

Response example:

```json
{
  "data": {
    "id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
    "title": "Hyderabad Metro services extended",
    "slug": "hyderabad-metro-services-extended",
    "summary": "Metro services will run longer for festival traffic.",
    "content": "Full article body content for the admin-created news story.",
    "thumbnail_url": "https://cdn.varadhi.example.com/articles/metro.jpg",
    "category": "7c7b120a-6b79-4926-972e-e08ba616ec9e",
    "category_name": "General",
    "author_email": "admin@example.com",
    "language": "en",
    "status": "published",
    "is_featured": false,
    "is_breaking": true,
    "scheduled_at": null,
    "published_at": "2026-07-01T10:00:00+05:30",
    "seo_title": "Hyderabad Metro services extended",
    "seo_description": "Metro services will run longer for festival traffic.",
    "seo_tags": ["hyderabad", "metro"],
    "source_url": "",
    "source_name": "VARADHI Desk",
    "state": "Telangana",
    "district": "Hyderabad",
    "city": "Hyderabad",
    "village": "Madhapur",
    "subdistrict": "Serilingampally",
    "priority_score": 10,
    "created_at": "2026-07-01T10:00:00+05:30",
    "updated_at": "2026-07-01T10:00:00+05:30"
  },
  "meta": {},
  "errors": null
}
```

Notes:

- `status="published"` automatically sets `published_at` and invalidates the feed cache.
- `status="scheduled"` requires a future `scheduled_at`.
- `location_tags` is accepted on create, but the admin response currently returns `state`, `district`, `city`, `village`, `subdistrict`, and `priority_score`; frontend should not require `location_tags` in the response.
- For thumbnail, admin frontend can use either `thumbnail_url` or `thumbnail_upload`.
- If using `thumbnail_upload`, send the request as `multipart/form-data`; uploaded file takes priority over `thumbnail_url`.
- Alternative direct-to-S3 flow: call `POST /admin/api/articles/thumbnail-upload-url/`, upload directly to S3 using the returned fields, then send the returned `file_url` as `thumbnail_url`.

TTS request:

```json
{
  "content": "Article text to read aloud",
  "language": "te",
  "object_type": "article",
  "object_id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
  "force_regenerate": false
}
```

TTS status fields: `task_id`, `state`, `tts_id`, `file_url`, `error`.

#### Contributor Article Create

Access: PRIVATE / CONTRIBUTOR.

```http
POST /api/v1/articles/
```

Request fields: `title`, `summary`, `content`, `thumbnail_url`, `thumbnail_upload`, `category`, `language`, `is_featured`, `is_breaking`, `status`, `scheduled_at`, `seo_title`, `seo_description`, `seo_tags`, `source_url`, `source_name`, `state`, `district`, `city`, `village`, `subdistrict`, `priority_score`, `location_tags`.

### 4.3 Unified Feed

Purpose: mixed feed of articles, UGC, and live content.

Access: PUBLIC.

```http
GET /api/v1/feed/
```

Query params: `include`, `lang`, `language`, `state`, `district`, `city`, `village`, `subdistrict`, `category`, `cursor`, `page_size`.

Unified item fields from `UnifiedFeedItemSerializer`: `id`, `type`, `title`, `summary`, `thumbnail_url`, `media_url`, `created_at`, `district`, `subdistrict`, `village`, `state`, `priority_score`, `source`, `trust_score`, `metadata`.

Example:

```json
{
  "data": [
    {
      "id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
      "type": "article",
      "title": "Metro services extended",
      "summary": "Metro timings extended.",
      "thumbnail_url": "https://cdn.varadhi.example.com/articles/metro.jpg",
      "media_url": "",
      "created_at": "2026-06-22T08:30:00+05:30",
      "district": "Hyderabad",
      "subdistrict": "",
      "village": "",
      "state": "Telangana",
      "priority_score": 90,
      "source": "VARADHI News",
      "trust_score": 0,
      "metadata": {}
    }
  ],
  "meta": {
    "count": null,
    "next": null,
    "previous": null
  },
  "errors": null
}
```

### 4.4 Search

Purpose: search articles/news.

Access: PUBLIC.

```http
GET /api/v1/search/?q=metro&lang=te&category=local
```

Query params:

| Param | Type | Required | Purpose |
| --- | --- | --- | --- |
| `q` | string | No | Search keyword. |
| `lang` | string | No | Language filter. |
| `category` | string | No | Category filter. |

Actual response shape:

```json
{
  "data": {
    "keyword": "metro",
    "result_count": 1,
    "results": [
      {
        "id": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3",
        "title": "Metro services extended in Hyderabad",
        "slug": "metro-services-extended-hyderabad",
        "summary": "Metro timings have been extended.",
        "thumbnail_url": "https://cdn.varadhi.example.com/articles/metro.jpg",
        "category": {
          "id": "2d35a2f8-0e71-45c0-a2d1-fec74ec1b7ff",
          "name": "Local",
          "slug": "local",
          "icon": "",
          "order": 1,
          "is_active": true
        },
        "author_name": "VARADHI News",
        "source_name": "Reporter",
        "language": "te",
        "is_featured": false,
        "is_breaking": false,
        "is_bookmarked": false,
        "share_url": null,
        "read_time_minutes": 2,
        "view_count": 125,
        "published_at": "2026-06-22T08:30:00+05:30",
        "state": "Telangana",
        "district": "Hyderabad",
        "village": "",
        "subdistrict": "",
        "is_regional": true,
        "priority_score": 90,
        "location_tags": ["Hyderabad"]
      }
    ]
  },
  "meta": {},
  "errors": null
}
```

Public search discovery:

```http
GET /api/v1/search/trending/
GET /api/v1/search/zero-results/
```

Admin-only search analytics:

```http
GET /admin/api/search/logs/
POST /admin/api/search/logs/anonymize/
GET /admin/api/search/trending/
GET /admin/api/search/zero-results/
```

### 4.5 Categories

Access: PUBLIC.

```http
GET /api/v1/categories/
```

Category fields: `id`, `name`, `slug`, `icon`, `order`, `is_active`.

Admin category APIs:

```http
POST /api/v1/categories/admin/
PATCH /api/v1/categories/admin/{slug}/
DELETE /api/v1/categories/admin/{slug}/
```

Access: ADMIN.

### 4.6 Bookmarks

Access: PRIVATE.

```http
GET /api/v1/bookmarks/
POST /api/v1/bookmarks/
POST /api/v1/bookmarks/toggle/
DELETE /api/v1/bookmarks/{bookmark_id}/
```

Create/toggle request:

```json
{
  "article": "5f90fd61-6bbf-43d5-9d92-d4269c1052d3"
}
```

Frontend notes:

If guest taps bookmark, show login prompt. Article feed/detail safely return `is_bookmarked: false` for guests.

### 4.7 UGC / Reporter

#### Public UGC OTP

```http
POST /api/v1/ugc/send-otp/
POST /api/v1/ugc/verify-otp/
```

Access: PUBLIC.

Request:

```json
{
  "mobile": "9876543210"
}
```

Verify request:

```json
{
  "mobile": "9876543210",
  "otp": "123456"
}
```

#### UGC Submit

Access: PRIVATE.

```http
POST /api/v1/ugc/submit/
```

Request:

```json
{
  "mobile": "9876543210",
  "title": "Road repair work started",
  "description": "Road work has started near the market.",
  "category": "local",
  "content_type": "TEXT",
  "media_url": "",
  "thumbnail_url": "",
  "location_lat": "17.385000",
  "location_lon": "78.486700",
  "village": "Madhapur",
  "subdistrict": "Serilingampally",
  "district": "Hyderabad",
  "state": "Telangana",
  "country": "India"
}
```

Submission response fields from `UserNewsSubmissionSerializer`: `id`, `title`, `description`, `category`, `content_type`, `media_url`, `thumbnail_url`, `media_type`, `media_metadata`, `upload_status`, `validation_status`, `duplicate_score`, `duplicate_matches`, `duplicate_flagged`, `location_lat`, `location_lon`, `village`, `subdistrict`, `district`, `state`, `country`, `status`, `source_type`, `mobile_verified`, `created_at`, `updated_at`.

#### Upload Media

Access: PRIVATE.

```http
POST /api/v1/ugc/upload-media/
```

Request type: `multipart/form-data`.

Fields: `submission_id`, `mobile`, `media_type`, `file`.

#### UGC Feed

Access: PUBLIC.

```http
GET /api/v1/ugc/feed/?state=Telangana&district=Hyderabad&page_size=20
```

Use `scope=local` for Local News. Local scope uses the most specific supplied location and does not fall back to other regions:

```http
GET /api/v1/ugc/feed/?scope=local&state=Telangana&district=Suryapet&page_size=20
```

Response fields from `UGCFeedItemSerializer`: `id`, `type`, `title`, `description`, `thumbnail_url`, `media_url`, `media_type`, `district`, `state`, `village`, `subdistrict`, `created_at`, `priority_score`, `source`, `trust_level`, `trust_score`, `uploader`.

#### UGC Admin Branded Media

Access: ADMIN / INTERNAL.

```http
POST /api/v1/ugc/admin/submissions/{submission_id}/branded-media/
```

Request type: `multipart/form-data`.

Fields: `file`, optional `thumbnail`, optional `notes`.

Behavior: preserves the original user upload in admin-only fields, stores the uploaded branded media, and keeps public `media_url` pointing to the active display media.

#### Reporter Dashboard

Access: PRIVATE / REPORTER.

```http
GET /api/v1/ugc/reporter/dashboard/
```

Response:

```json
{
  "data": {
    "total_submissions": 4,
    "pending_count": 1,
    "approved_count": 2,
    "published_count": 2,
    "rejected_count": 1,
    "trust_score": 65,
    "reporter_level": "TRUSTED",
    "recent_submissions": []
  },
  "meta": {},
  "errors": null
}
```

#### Reporter Submissions

Access: PRIVATE / REPORTER.

```http
GET /api/v1/ugc/reporter/submissions/?status=pending&page_size=20
```

Supported `status`: `pending`, `approved`, `published`, `rejected`. `published` aliases approved.

#### Report Submission

Access: PRIVATE.

```http
POST /api/v1/ugc/report/
```

Request:

```json
{
  "submission_id": "67de3618-96ca-4bbf-9501-d3161321ee4b",
  "reason": "spam",
  "notes": "Repeated duplicate content"
}
```

Admin moderation:

```http
GET /api/v1/ugc/moderation/queue/
GET /admin/api/ugc/queue/
GET /admin/api/ugc/otp-deliveries/
GET /admin/api/ugc/submissions/{submission_id}/
POST /admin/api/ugc/submissions/{submission_id}/approve/
POST /admin/api/ugc/submissions/{submission_id}/reject/
POST /admin/api/ugc/submissions/{submission_id}/flag/
```

Access: ADMIN.

### 4.8 Rewards

Rewards are private/user or admin-only. A user earns coins only when an admin approves an image/video UGC submission. Text-only UGC does not earn coins. Duplicate approval cannot create duplicate coins because the ledger uses `reward:ugc_approved_media:{submission_id}` as the idempotency key.

#### User Rewards APIs

```http
GET /api/v1/rewards/wallet/
GET /api/v1/rewards/transactions/?page_size=20
GET /api/v1/rewards/payouts/?page_size=20
POST /api/v1/rewards/payouts/
GET /api/v1/rewards/payouts/{payout_id}/
```

Access: PRIVATE.

Wallet response fields from `RewardWalletSummarySerializer`: `available_coins`, `locked_coins`, `redeemed_coins`, `lifetime_earned_coins`, `coin_value_rupees`, `available_value_rupees`, `minimum_withdrawal_coins`.

Payout create payload:

```json
{
  "coins_requested": 1,
  "payout_method": "PHONEPE",
  "payout_mobile": "9876543210",
  "payout_upi_id": "user@upi",
  "user_notes": "Please send to PhonePe"
}
```

Payout response fields from `RewardPayoutRequestSerializer`: `id`, `coins_requested`, `coin_value_rupees`, `amount_rupees`, `payout_method`, `payout_mobile`, `payout_upi_id`, `payout_account_name`, `status`, `user_notes`, `payment_reference`, `requested_at`, `approved_at`, `paid_at`, `rejected_at`, `created_at`, `updated_at`.

Transaction fields from `RewardTransactionSerializer`: `id`, `transaction_type`, `coins`, `value_rupees`, `status`, `source_app`, `source_model`, `source_object_id`, `metadata`, `created_at`.

#### Admin Rewards APIs

```http
GET /api/v1/rewards/admin/dashboard/
GET /api/v1/rewards/admin/wallets/
GET /api/v1/rewards/admin/wallets/{user_id}/
POST /api/v1/rewards/admin/wallets/{user_id}/adjust/
GET /api/v1/rewards/admin/transactions/
GET /api/v1/rewards/admin/payouts/
GET /api/v1/rewards/admin/payouts/{payout_id}/
POST /api/v1/rewards/admin/payouts/{payout_id}/mark-paid/
POST /api/v1/rewards/admin/payouts/{payout_id}/reject/
GET /api/v1/rewards/admin/settings/
PATCH /api/v1/rewards/admin/settings/
```

Access: ADMIN.

Admin adjustment payload:

```json
{
  "coins": 1,
  "reason": "Manual correction for approved story"
}
```

Mark paid payload:

```json
{
  "payment_reference": "PHONEPE-TXN-12345",
  "admin_notes": "Paid manually via PhonePe"
}
```

Reject payload:

```json
{
  "admin_notes": "Invalid UPI ID"
}
```

Reward settings payload:

```json
{
  "coin_value_rupees": "5.00",
  "coins_per_approved_media_submission": 1,
  "minimum_withdrawal_coins": 1,
  "is_active": true
}
```

Workflow:

1. User uploads UGC image/video.
2. Admin approves UGC.
3. Backend awards `+1` coin using immutable ledger transaction `EARN_APPROVED_UGC_MEDIA`.
4. User checks wallet.
5. User requests payout.
6. Coins move `available -> locked` using `WITHDRAWAL_HOLD`.
7. Client/admin pays manually through PhonePe/UPI/mobile outside the backend.
8. Admin marks payout paid with `payment_reference`.
9. Coins move `locked -> redeemed` using `WITHDRAWAL_PAID`.
10. Duplicate approval does not duplicate coins.

### 4.9 Posters

Access: PUBLIC.

```http
GET /api/v1/posters/?category=good_morning&lang=te&page_size=20
```

Query params: `category`, `lang`, `cursor`, `page_size`.

Response fields from `PosterSerializer`: `id`, `title`, `category`, `image_url`, `thumbnail_url`, `images`, `language`, `festival_name`, `event_date`, `share_url`, `created_at`.

Important: `share_url` is always `null`. `image_url` returns uploaded image file URL when present; otherwise it falls back to stored `image_url`. `images` is for swipe UI. Existing single-image posters still return one primary image item in `images`.

Info/card categories:

`good_morning`, `devotional`, `love`, `motivational`, `festival`, `special_day`, `jyothishyam`, `panchangam`, `daily_quote`, `health_tip`, `education`, `government_update`.

Example:

```json
{
  "data": [
    {
      "id": "2cd0f967-c7fc-4b68-8a95-bd595ac3a1ab",
      "title": "Good Morning",
      "category": "good_morning",
      "image_url": "https://cdn.varadhi.example.com/posters/good-morning.jpg",
      "thumbnail_url": "",
      "images": [
        {
          "id": "2cd0f967-c7fc-4b68-8a95-bd595ac3a1ab",
          "image_url": "https://cdn.varadhi.example.com/posters/good-morning.jpg",
          "caption": "",
          "sort_order": 0
        }
      ],
      "language": "te",
      "festival_name": "",
      "event_date": null,
      "share_url": null,
      "created_at": "2026-06-22T08:00:00+05:30"
    }
  ],
  "meta": {
    "count": null,
    "next": null,
    "previous": null
  },
  "errors": null
}
```

Admin card APIs:

```http
GET /api/v1/posters/admin/
POST /api/v1/posters/admin/
GET /api/v1/posters/admin/{poster_id}/
PATCH /api/v1/posters/admin/{poster_id}/
DELETE /api/v1/posters/admin/{poster_id}/
POST /api/v1/posters/admin/{poster_id}/images/
PATCH /api/v1/posters/admin/{poster_id}/images/{image_id}/
DELETE /api/v1/posters/admin/{poster_id}/images/{image_id}/
```

Access: ADMIN. Use these for Jyothishyam, Panchangam, daily quote cards, health tips, education cards, and government update cards.

### 4.9 Ads

#### Active Ads

Access: PUBLIC.

```http
GET /api/v1/ads/?placement_zone=feed&state=Telangana&district=Suryapet
```

Query params: `zone` legacy alias, `placement_zone`, `scope`, `area_id`, `state`, `district`, `city`, `subdistrict`, `village`.

Behavior: global ads show everywhere. Area ads show only when `area_id` or location params match the ad area. If no location is supplied, only global ads are returned.

Fields: `id`, `image_url`, `destination_url`, `ad_type`, `placement_zone`, `target_scope`, `area`, `display_frequency`, `ctr`.

#### Ad Event

Access: PUBLIC, throttled.

```http
POST /api/v1/ads/event/
```

Request:

```json
{
  "ad_id": "016d68c8-5b68-4c4f-9e09-d19a3a67d2ee",
  "event_type": "impression"
}
```

`event_type`: `impression` or `click`.

#### Advertisement Areas

Access: PUBLIC.

```http
GET /api/v1/ads/areas/
```

Fields: `id`, `name`, `state`, `district`, `city`, `village`, `subdistrict`, `sort_order`.

#### Advertisement Pricing

Access: PUBLIC.

```http
GET /api/v1/ads/pricing/?ad_type=local&area_id=<uuid>&duration_days=7
```

For `ad_type=local`, `area_id` is required. For `ad_type=main`, area may be null.

Response fields: `ad_type`, `area`, `duration_days`, `price`, `currency`.

#### Advertisement Booking

Access: PUBLIC, throttled.

```http
POST /api/v1/ads/bookings/
```

Request:

```json
{
  "advertiser_name": "Ravi",
  "phone": "9876543210",
  "business_name": "Ravi Mobiles",
  "ad_type": "local",
  "area_id": "6d5b3d3b-138d-4adf-88ef-3d5e9f51967a",
  "duration_days": 7,
  "message": "Need banner ad in Hyderabad"
}
```

Response:

```json
{
  "data": {
    "id": "ce154de3-59d6-41c6-a587-7be2483fdc2f",
    "status": "pending",
    "quoted_price": "1500.00",
    "currency": "INR",
    "whatsapp_url": "https://wa.me/919876543210?text=..."
  },
  "meta": {},
  "errors": null
}
```

Frontend flow: load areas, request pricing after type/area/duration selection, create booking, then open `whatsapp_url` using the platform browser/intent.

Admin ad APIs:

```http
GET /api/v1/ads/admin/
POST /api/v1/ads/admin/
GET /api/v1/ads/admin/{ad_id}/
PATCH /api/v1/ads/admin/{ad_id}/
DELETE /api/v1/ads/admin/{ad_id}/
GET /api/v1/ads/admin/areas/
POST /api/v1/ads/admin/areas/
PATCH /api/v1/ads/admin/areas/{area_id}/
GET /api/v1/ads/admin/pricing/
POST /api/v1/ads/admin/pricing/
PATCH /api/v1/ads/admin/pricing/{pricing_id}/
GET /api/v1/ads/admin/bookings/
PATCH /api/v1/ads/admin/bookings/{booking_id}/
```

Access: ADMIN.

Ad create/update supports `target_scope=global|area` and `area_id` for area ads. Existing ads without targeting remain global.

### 4.10 Notifications

User notification APIs are PRIVATE.

```http
GET /api/v1/notifications/inbox/?unread=true
GET /api/v1/notifications/inbox/unread-count/
GET /api/v1/notifications/inbox/{user_notification_id}/
POST /api/v1/notifications/inbox/{user_notification_id}/read/
```

User notification fields: `id`, `notification_id`, `title`, `body`, `image_url`, `deep_link`, `is_read`, `read_at`, `notification_created_at`, `created_at`.

Admin/legacy notification APIs:

```http
POST /api/v1/notifications/send/
POST /api/v1/notifications/admin/target-preview/
GET /api/v1/notifications/
GET /api/v1/notifications/{notification_id}/
GET /admin/api/notifications/
POST /admin/api/notifications/send/
POST /admin/api/notifications/target-preview/
GET /admin/api/notifications/{notification_id}/
POST /admin/api/notifications/{notification_id}/retry-failed/
```

Access: ADMIN.

Location/category targeting payload:

```json
{
  "title": "Suryapet Alert",
  "body": "Local update",
  "notification_type": "local",
  "target_scope": "location",
  "state": "Telangana",
  "district": "Suryapet",
  "category_slug": ""
}
```

`target_scope`: `all`, `location`, `category`, `category_location`.

Preview:

```http
POST /api/v1/notifications/admin/target-preview/
```

Response:

```json
{
  "data": {
    "target_count": 10
  },
  "meta": {},
  "errors": null
}
```

Category targeting uses existing user category preference weights when available. The selected category and location are stored in `target_data`.

### 4.11 Polls

#### Poll List and Detail

Access: PUBLIC.

```http
GET /api/v1/polls/
GET /api/v1/polls/{poll_id}/
```

Fields from `PollSerializer`: `id`, `question`, `option_a`, `option_b`, `vote_a_count`, `vote_b_count`, `total_votes`, `options`, `percentages`, `user_vote`, `user_vote_option_id`, `is_active`, `is_expired`, `ends_at`, `created_at`.

`options` supports multi-option polls:

```json
[
  {
    "id": "f6d0c8b7-8e0e-47d7-8b82-49e504cf7301",
    "label": "Roads",
    "sort_order": 0,
    "vote_count": 12,
    "percentage": 42.9
  }
]
```

For guests, `user_vote` and `user_vote_option_id` are returned when the APK sends the same `X-Device-ID` used for voting.

#### Vote

Access: PUBLIC, throttled. APK should send `X-Device-ID` so one device can vote only once per poll.

```http
POST /api/v1/polls/{poll_id}/vote/
```

Request:

```json
{
  "option_id": "f6d0c8b7-8e0e-47d7-8b82-49e504cf7301"
}
```

Legacy two-option payload still works:

```json
{
  "choice": "a"
}
```

Status codes: `200`, `400`, `404`, `429`, `500`.

Admin poll APIs:

```http
POST /api/v1/polls/admin/
GET /admin/api/polls/
POST /admin/api/polls/
GET /admin/api/polls/{poll_id}/
PATCH /admin/api/polls/{poll_id}/
DELETE /admin/api/polls/{poll_id}/
POST /admin/api/polls/{poll_id}/close/
GET /admin/api/polls/{poll_id}/results/
```

Access: ADMIN.

Create multi-option poll:

```json
{
  "question": "Best local issue?",
  "options": ["Roads", "Water", "Power", "Schools"],
  "is_active": true,
  "ends_at": null
}
```

Legacy two-option create still works with `option_a` and `option_b`.

### 4.12 CMS

Access: PUBLIC.

```http
GET /api/v1/cms/{slug}/
```

Public CMS fields: `id`, `slug`, `title`, `content`, `updated_at` as defined by `CMSPagePublicSerializer`.

Admin CMS APIs:

```http
GET /admin/api/cms/
POST /admin/api/cms/
GET /admin/api/cms/{slug}/
PUT /admin/api/cms/{slug}/
PATCH /admin/api/cms/{slug}/
DELETE /admin/api/cms/{slug}/
```

### 4.13 Quotes / Daily Cards

Access: PUBLIC.

```http
GET /api/v1/quotes/random/
```

Purpose: show one random active quote/daily card.

Admin quote APIs:

```http
GET /admin/api/quotes/
POST /admin/api/quotes/
GET /admin/api/quotes/{id}/
PUT /admin/api/quotes/{id}/
PATCH /admin/api/quotes/{id}/
DELETE /admin/api/quotes/{id}/
```

### 4.14 Analytics / Metrics / Health

#### Lightweight Health

Access: PUBLIC.

```http
GET /api/v1/health/
```

Use only for app startup diagnostics or deployment checks. Do not block normal app launch on this endpoint unless product requires it.

#### System Health

Access: ADMIN / INTERNAL.

```http
GET /api/v1/system/health/
GET /admin/api/system/health/
GET /admin/api/system/readiness/
GET /admin/api/system/release-audit/
```

#### Metrics

Access: INTERNAL.

```http
GET /metrics/
```

This route exists only when `ENABLE_PROMETHEUS_METRICS=True`. It should be protected by network controls such as Nginx allowlists/security groups and must not be used by the mobile app.

#### Analytics

Access: ADMIN.

```http
GET /api/v1/analytics/dashboard/
GET /api/v1/analytics/user-preferences/
GET /admin/api/analytics/dashboard/
GET /admin/api/analytics/content/
GET /admin/api/analytics/ugc/
GET /admin/api/analytics/search/
GET /admin/api/analytics/notifications/
```

## 6. Common Field Contracts

### Article Feed Item

| Field | Type | Required | Nullable | Frontend Use |
| --- | --- | --- | --- | --- |
| `id` | UUID string | Yes | No | Stable item key. |
| `title` | string | Yes | No | Card/detail title. |
| `slug` | string | Yes | No | Article detail route. |
| `summary` | string | Yes | No | Card preview. |
| `thumbnail_url` | string | Yes | Can be empty | Image. |
| `category` | object | Yes | Yes if no category | Chip/filter display. |
| `author_name` | string | Yes | No | Byline. |
| `source_name` | string | Yes | Can be empty | Source label. |
| `language` | string | Yes | No | Language handling. |
| `is_featured` | boolean | Yes | No | Featured badge. |
| `is_breaking` | boolean | Yes | No | Breaking badge. |
| `is_bookmarked` | boolean | Yes | No | Bookmark UI state. |
| `share_url` | null | Yes | Yes | Currently always `null`; APK-first. |
| `read_time_minutes` | integer | Yes | No | Reading time. |
| `view_count` | integer | Yes | No | Popularity display. |
| `published_at` | datetime | Yes | Yes | Time label. |
| `state` | string | Yes | Can be empty | Local display. |
| `district` | string | Yes | Can be empty | Local display. |
| `village` | string | Yes | Can be empty | Local display. |
| `subdistrict` | string | Yes | Can be empty | Local display. |

### Video Item

| Field | Type | Required | Nullable | Frontend Use |
| --- | --- | --- | --- | --- |
| `id` | string | Yes | No | Stable key. |
| `title` | string | Yes | No | Video title. |
| `youtube_video_id` | string | Yes | No | YouTube player ID. |
| `youtube_url` | URI string | Yes | No | External/open URL. |
| `thumbnail_url` | string | Yes | Can be empty | Video thumbnail. |
| `channel_name` | string | No | Can be empty | Channel label. |
| `published_at` | datetime | No | Yes | Published label. |
| `is_live` | boolean | Yes | No | Live badge/player handling. |
| `is_short` | boolean | No | No | Shorts UI. |
| `duration_seconds` | integer | No | Yes | Duration badge. |

### Error Handling Rules

| Status | Meaning | Frontend Action |
| --- | --- | --- |
| `200` | Success | Render `data`. |
| `201` | Created | Render new resource or success UI. |
| `204` | No content | Treat as success; body may be empty before renderer. |
| `400` | Validation error | Show field-level error from `errors.details`. |
| `401` | Missing/invalid token | Clear token or show login. |
| `403` | Forbidden | Show permission message. |
| `404` | Not found | Show empty/not-found state. |
| `409` | Conflict | Show duplicate/state conflict if returned. |
| `429` | Throttled | Back off and show retry message. |
| `500` | Server error | Show generic retry UI. |

## 7. Frontend Implementation Flow

### App Start Flow

1. Read stored access token, refresh token, language, and location from device storage.
2. Optionally call `GET /api/v1/health/` for diagnostics.
3. Start home with `GET /api/v1/articles/shorts-feed/`.
4. In parallel, preload `GET /api/v1/categories/`, `GET /api/v1/articles/feed/`, `GET /api/v1/ads/`, and `GET /api/v1/quotes/random/`.

### Guest User Flow

Guest users can use:

`/articles/feed/`, `/articles/{slug}/`, `/articles/featured/`, `/articles/live/`, `/articles/video-feed/`, `/articles/shorts-feed/`, `/articles/recommendations/`, `/feed/`, `/search/`, `/search/trending/`, `/search/zero-results/`, `/categories/`, `/posters/`, `/ads/`, `/ads/areas/`, `/ads/pricing/`, `/ads/bookings/`, `/polls/`, `/cms/{slug}/`, `/quotes/random/`, `/ugc/feed/`, `/ugc/send-otp/`, `/ugc/verify-otp/`.

Guest users cannot use bookmarks, profile updates, notifications, UGC submit/upload/report, or reporter dashboard. Poll voting is public; APK should send `X-Device-ID` for duplicate-vote protection.

### Logged-in User Flow

1. Login/register.
2. Store `access` and `refresh`.
3. Call `GET /api/v1/auth/me/`.
4. Store/update location via `POST /api/v1/user/location/`.
5. Enable bookmarks, notifications, poll voting, UGC submit, and reporter screens.

### Home Page Flow

Recommended calls:

1. `GET /api/v1/articles/shorts-feed/?lang=<lang>&page_size=20`
2. `GET /api/v1/articles/feed/?lang=<lang>&page_size=20`
3. `GET /api/v1/articles/feed/?state=&district=&subdistrict=&village=&lang=`
4. `GET /api/v1/ads/?zone=home`
5. `GET /api/v1/posters/?lang=<lang>&page_size=10`
6. `GET /api/v1/quotes/random/`

### Local News Flow

Use local scope with location params. `scope=local` is strict and returns an empty list when no matching local content exists.

```text
GET /api/v1/feed/?scope=local&state=Telangana&district=Suryapet&subdistrict=&village=&lang=te
```

### Article Detail Flow

1. User taps feed card.
2. Open `GET /api/v1/articles/{slug}/`.
3. Render title, content, thumbnail, source, category, published time, read time, `is_bookmarked`, and `tts_url` if present.
4. Since `share_url` is currently `null`, app should use native share text/deep-link only after product defines a deep-link contract.

### Post News Flow

1. Require login.
2. Optionally verify mobile using UGC OTP APIs.
3. Submit with `POST /api/v1/ugc/submit/`.
4. Upload media with `POST /api/v1/ugc/upload-media/` if needed.
5. Show status from reporter dashboard/submissions.

### Reporter Dashboard Flow

1. `GET /api/v1/ugc/reporter/dashboard/`.
2. `GET /api/v1/ugc/reporter/submissions/?status=pending`.
3. Use status filters: `pending`, `approved`, `published`, `rejected`.

### Ads Booking Flow

1. `GET /api/v1/ads/areas/`.
2. `GET /api/v1/ads/pricing/?ad_type=local&area_id=<uuid>&duration_days=7`.
3. `POST /api/v1/ads/bookings/`.
4. Open `whatsapp_url`.

### Notifications Flow

After login:

1. `GET /api/v1/notifications/inbox/unread-count/`.
2. `GET /api/v1/notifications/inbox/`.
3. `POST /api/v1/notifications/inbox/{user_notification_id}/read/`.

## 8. Contract Warnings and Integration Notes

1. Runtime error shape uses an object, not an array: `errors.code`, `errors.message`, `errors.details`.
2. `share_url` is intentionally `null` for articles and posters because VARADHI is APK-first and has no public website/deep-link contract yet.
3. `GET /api/v1/articles/recommendations/` is not cursor paginated. Use `limit`.
4. `GET /api/v1/articles/video-feed/` may return live first-page items with some optional video fields omitted.
5. Admin endpoints may be documented by OpenAPI as raw serializers in places, but runtime renderer still wraps successful DRF responses in `{data, meta, errors}`.
6. `GET /api/v1/health/` is public and lightweight. `GET /api/v1/system/health/` and `/admin/api/system/*` are admin/internal.
7. `/metrics/` is not part of `/api/v1`; it exists only when metrics are enabled and must not be consumed by the mobile app.

## 9. Documentation Generation Summary

Files created:

- `fullprojectapidocument.md`

Total OpenAPI operations documented: 142.

Public APIs count: 39.

Private APIs count: 26.

Admin/internal APIs count: 77.

Frontend screens covered:

Splash, onboarding, login, register, password reset, location selection, language selection, home shorts, main news, local news, article detail, search, categories, posters, UGC submit, UGC media upload, reporter dashboard, reporter submission list, profile, preferences, bookmarks, notifications, polls, ads display, ad booking, CMS pages, quotes, and admin/moderator screens.

OpenAPI status:

This document was generated from the existing `openapi-schema.yml` and code inspection. No backend business logic, serializers, or API contracts were changed.

Notes for frontend developer:

Always unwrap `response.data.data` for actual payload, read pagination from `response.data.meta`, and handle errors from `response.data.errors`. Treat all admin/internal APIs as unavailable to mobile users unless building a separate admin console.
