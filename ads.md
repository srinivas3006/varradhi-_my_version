# VARADHI Ads System Guide

This document explains the complete advertisement system for backend, admin, and frontend integration.

## 1. System Overview

VARADHI ads has two main parts:

1. **Ad Display System**
   - Admin creates ad banners.
   - Backend serves active ads to the APK/frontend.
   - Frontend displays ads in feed, article, splash, and search screens.
   - Frontend reports impressions and clicks.

2. **Advertisement Booking System**
   - User/advertiser selects ad type, area, and duration.
   - Backend returns pricing.
   - User submits booking inquiry.
   - Backend returns a WhatsApp URL for follow-up.
   - Admin manages booking status.

Current ad creative support is image-based. The API has an `ad_type="video"` option, but there is no `video_url` or video upload flow yet. Frontend should render `image_url`.

## 2. Media Support

| Media | Status |
| --- | --- |
| Image ad URL | Supported |
| CDN/S3 image URL | Supported |
| Video ad type enum | Partially supported |
| Actual video URL | Not supported yet |
| Video upload | Not supported yet |

Frontend rule: render all ads using `image_url`.

## 3. Response Envelope

Runtime API responses use this envelope:

```json
{
  "data": {},
  "meta": {},
  "errors": null
}
```

List APIs return:

```json
{
  "data": [],
  "meta": {},
  "errors": null
}
```

## 4. Public APIs

These APIs are public and do not require JWT.

### 4.1 Get Active Ads

```http
GET /api/v1/ads/
```

Purpose: Get active ads for frontend display.

Query params:

| Param | Type | Required | Example | Use |
| --- | --- | --- | --- | --- |
| `zone` | string | No | `feed` | Placement zone |
| `placement_zone` | string | No | `article` | Same as `zone` |
| `scope` | string | No | `main`, `local` | Global/main or local ads |
| `state` | string | No | `Telangana` | Location targeting |
| `district` | string | No | `Suryapet` | Location targeting |
| `city` | string | No | `Suryapet` | Location targeting |
| `subdistrict` | string | No | `Suryapet Rural` | Location targeting |
| `village` | string | No | `Madhapur` | Location targeting |
| `area_id` | UUID | No | `08c5...` | Direct area targeting |

Placement zones:

```text
feed
article
splash
search
```

Example:

```http
GET /api/v1/ads/?zone=feed
```

Local example:

```http
GET /api/v1/ads/?zone=feed&scope=local&state=Telangana&district=Suryapet
```

Response:

```json
{
  "data": [
    {
      "id": "8a3d4c7e-7f33-49d1-b7ad-4f2a0c3e8a11",
      "image_url": "https://cdn.varadhi.example.com/ads/suryapet-banner.jpg",
      "destination_url": "https://wa.me/919876543210",
      "ad_type": "banner",
      "placement_zone": "feed",
      "target_scope": "area",
      "area": {
        "id": "08c5c4f8-7334-4135-a6c8-b16c12a7c4de",
        "name": "Suryapet Local Area"
      },
      "display_frequency": 5,
      "ctr": 2.35
    }
  ],
  "meta": {},
  "errors": null
}
```

Important fields:

| Field | Use |
| --- | --- |
| `id` | Required for impression/click event tracking |
| `image_url` | Image creative to render |
| `destination_url` | URL to open when user clicks |
| `ad_type` | Layout hint |
| `placement_zone` | Screen/placement |
| `target_scope` | `global` or `area` |
| `area` | Local area info when targeted |
| `display_frequency` | Show ad after every N feed items |
| `ctr` | Click-through rate percentage |

Frontend display rule:

```text
display_frequency = 5 means show the ad after every 5 feed items.
```

### 4.2 Track Ad Event

```http
POST /api/v1/ads/event/
```

Purpose: Track ad impression and click events.

Recommended headers:

```http
X-Device-ID: device-unique-id
```

or:

```http
X-Session-ID: session-id
```

Request body:

```json
{
  "ad_id": "8a3d4c7e-7f33-49d1-b7ad-4f2a0c3e8a11",
  "event_type": "impression"
}
```

For click:

```json
{
  "ad_id": "8a3d4c7e-7f33-49d1-b7ad-4f2a0c3e8a11",
  "event_type": "click"
}
```

Response:

```json
{
  "data": {
    "recorded": true
  },
  "meta": {},
  "errors": null
}
```

Backend dedupe:

| Event | Dedupe Window |
| --- | --- |
| impression | 10 minutes |
| click | 1 minute |

Frontend should call `impression` only when the ad is actually visible.

### 4.3 Get Advertisement Areas

```http
GET /api/v1/ads/areas/
```

Purpose: Used on booking screen for local advertisement area selection.

Response:

```json
{
  "data": [
    {
      "id": "08c5c4f8-7334-4135-a6c8-b16c12a7c4de",
      "name": "Suryapet Local Area",
      "state": "Telangana",
      "district": "Suryapet",
      "city": "Suryapet",
      "village": "",
      "subdistrict": "",
      "sort_order": 1
    }
  ],
  "meta": {},
  "errors": null
}
```

### 4.4 Get Advertisement Pricing

```http
GET /api/v1/ads/pricing/
```

Purpose: Get price for selected ad type, area, and duration.

Query params:

| Param | Required | Example |
| --- | --- | --- |
| `ad_type` | Yes | `local`, `main` |
| `duration_days` | Yes | `7` |
| `area_id` | Required for `local` only | `08c5...` |

Local pricing:

```http
GET /api/v1/ads/pricing/?ad_type=local&area_id=08c5c4f8-7334-4135-a6c8-b16c12a7c4de&duration_days=7
```

Main pricing:

```http
GET /api/v1/ads/pricing/?ad_type=main&duration_days=7
```

Response:

```json
{
  "data": {
    "ad_type": "local",
    "area": {
      "id": "08c5c4f8-7334-4135-a6c8-b16c12a7c4de",
      "name": "Suryapet Local Area"
    },
    "duration_days": 7,
    "price": "1500.00",
    "currency": "INR"
  },
  "meta": {},
  "errors": null
}
```

### 4.5 Create Advertisement Booking

```http
POST /api/v1/ads/bookings/
```

Purpose: Create advertiser inquiry and return WhatsApp URL.

Local ad request:

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

Main ad request:

```json
{
  "advertiser_name": "Ravi",
  "phone": "9876543210",
  "business_name": "Ravi Mobiles",
  "ad_type": "main",
  "duration_days": 7,
  "message": "Need main advertisement"
}
```

Response:

```json
{
  "data": {
    "id": "b7b665ff-b7df-47c8-a1fb-fbd1cc083003",
    "status": "pending",
    "quoted_price": "1500.00",
    "currency": "INR",
    "whatsapp_url": "https://wa.me/919876543210?text=VARADHI%20advertisement%20inquiry..."
  },
  "meta": {},
  "errors": null
}
```

Frontend should open `whatsapp_url` after successful booking if it is not empty.

## 5. Admin APIs

Admin APIs require admin JWT.

### 5.1 List Ads

```http
GET /api/v1/ads/admin/
Authorization: Bearer <admin_access_token>
```

Response includes all ad management fields.

### 5.2 Create Ad

```http
POST /api/v1/ads/admin/
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Area-targeted ad:

```json
{
  "title": "Suryapet banner",
  "image_url": "https://cdn.varadhi.example.com/ads/suryapet-banner.jpg",
  "destination_url": "https://wa.me/919876543210",
  "ad_type": "banner",
  "placement_zone": "feed",
  "target_scope": "area",
  "area_id": "08c5c4f8-7334-4135-a6c8-b16c12a7c4de",
  "display_frequency": 5,
  "is_active": true,
  "start_date": "2026-07-15T09:00:00+05:30",
  "end_date": "2026-07-22T09:00:00+05:30"
}
```

Global ad:

```json
{
  "title": "Global feed banner",
  "image_url": "https://cdn.varadhi.example.com/ads/global-banner.jpg",
  "destination_url": "https://example.com",
  "ad_type": "banner",
  "placement_zone": "feed",
  "target_scope": "global",
  "display_frequency": 5,
  "is_active": true
}
```

Rules:

- `target_scope="area"` requires `area_id`.
- `target_scope="global"` must not use `area_id`.
- `image_url` is required.
- `start_date` and `end_date` are optional.
- If date range is set, ad appears only inside that range.

### 5.3 Get Single Ad

```http
GET /api/v1/ads/admin/{ad_id}/
Authorization: Bearer <admin_access_token>
```

### 5.4 Update Ad

```http
PATCH /api/v1/ads/admin/{ad_id}/
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Example:

```json
{
  "is_active": false
}
```

### 5.5 Delete Ad

```http
DELETE /api/v1/ads/admin/{ad_id}/
Authorization: Bearer <admin_access_token>
```

This soft-deletes the ad.

## 6. Admin Advertisement Area APIs

### 6.1 List Areas

```http
GET /api/v1/ads/admin/areas/
Authorization: Bearer <admin_access_token>
```

### 6.2 Create Area

```http
POST /api/v1/ads/admin/areas/
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Payload:

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

### 6.3 Update Area

```http
PATCH /api/v1/ads/admin/areas/{area_id}/
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Payload:

```json
{
  "is_active": false
}
```

## 7. Admin Pricing APIs

### 7.1 List Pricing

```http
GET /api/v1/ads/admin/pricing/
Authorization: Bearer <admin_access_token>
```

### 7.2 Create Pricing

```http
POST /api/v1/ads/admin/pricing/
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Local pricing:

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

Main pricing:

```json
{
  "ad_type": "main",
  "area": null,
  "duration_days": 7,
  "price": "5000.00",
  "currency": "INR",
  "is_active": true
}
```

Rules:

- `local` pricing requires an area.
- `main` pricing should use `area: null`.
- `duration_days` must match the duration selected in pricing/booking APIs.

### 7.3 Update Pricing

```http
PATCH /api/v1/ads/admin/pricing/{pricing_id}/
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Example:

```json
{
  "price": "1800.00",
  "is_active": true
}
```

## 8. Admin Booking APIs

### 8.1 List Bookings

```http
GET /api/v1/ads/admin/bookings/
Authorization: Bearer <admin_access_token>
```

Filter by status:

```http
GET /api/v1/ads/admin/bookings/?status=pending
```

Allowed statuses:

```text
pending
contacted
approved
rejected
```

### 8.2 Update Booking Status

```http
PATCH /api/v1/ads/admin/bookings/{booking_id}/
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Payload:

```json
{
  "status": "contacted"
}
```

## 9. Backend Workflow

### 9.1 Ad Display Backend Flow

1. Admin creates `AdBanner`.
2. Admin sets:
   - image URL
   - destination URL
   - placement zone
   - target scope
   - area if local
   - date range
   - display frequency
3. Frontend calls `GET /api/v1/ads/`.
4. Backend filters:
   - active ads only
   - matching placement zone
   - current date inside start/end dates
   - global ads
   - local area-matching ads
5. Backend caches result for 5 minutes.
6. Frontend renders ads.
7. Frontend sends impression/click events.
8. Backend increments Redis counters.
9. DB metrics are synced from Redis by scheduled analytics task.

### 9.2 Booking Backend Flow

1. Admin creates `AdvertisementArea`.
2. Admin creates `AdvertisementPricing`.
3. Frontend lists active areas.
4. Frontend checks price.
5. User submits booking.
6. Backend validates area/pricing.
7. Backend creates `AdvertisementBooking`.
8. Backend generates `whatsapp_url`.
9. Frontend opens WhatsApp URL.
10. Admin later updates booking status.

## 10. Frontend Workflow

### 10.1 Feed Ads

1. Call news feed API.
2. Call:

```http
GET /api/v1/ads/?zone=feed&scope=main
```

or local:

```http
GET /api/v1/ads/?zone=feed&scope=local&state=Telangana&district=Suryapet
```

3. Insert ad after every `display_frequency` news items.
4. Render `image_url`.
5. On visible, call:

```http
POST /api/v1/ads/event/
```

with `event_type="impression"`.

6. On tap, call same event API with `event_type="click"`.
7. Open `destination_url` if not empty.

### 10.2 Article Detail Ads

Call:

```http
GET /api/v1/ads/?zone=article
```

Recommended placement:

- after first paragraph
- middle of article
- bottom of article

### 10.3 Splash Ads

Call:

```http
GET /api/v1/ads/?zone=splash
```

Render first active ad as app-open splash image.

### 10.4 Search Ads

Call:

```http
GET /api/v1/ads/?zone=search
```

Render between search results.

### 10.5 Booking Screen

1. Get areas:

```http
GET /api/v1/ads/areas/
```

2. User selects:
   - Local Advertisement or Main Advertisement
   - Area if local
   - Duration

3. Get pricing:

```http
GET /api/v1/ads/pricing/?ad_type=local&area_id=<uuid>&duration_days=7
```

4. Show price.
5. Submit booking:

```http
POST /api/v1/ads/bookings/
```

6. Open returned `whatsapp_url`.

## 11. Error Responses

Validation error:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 400,
    "message": "Validation error",
    "details": {
      "area_id": ["area_id is required for local advertisements."]
    }
  }
}
```

Pricing not found:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 404,
    "message": "Advertisement pricing not found.",
    "details": {
      "detail": "Advertisement pricing not found."
    }
  }
}
```

Rate limited:

```json
{
  "data": null,
  "meta": {},
  "errors": {
    "code": 429,
    "message": "Request was throttled.",
    "details": {
      "detail": "Request was throttled."
    }
  }
}
```

## 12. Caching And Tracking Notes

- Active ad list is cached for 5 minutes.
- Admin create/update/delete invalidates ad cache.
- Impression and click counters are Redis-backed.
- Duplicate impressions are ignored for 10 minutes per ad/user-device/session/IP.
- Duplicate clicks are ignored for 1 minute per ad/user-device/session/IP.
- Frontend should send `X-Device-ID` for better deduplication.

## 13. Recommended Frontend Mapping

| Screen | API |
| --- | --- |
| Home feed ads | `GET /api/v1/ads/?zone=feed` |
| Local feed ads | `GET /api/v1/ads/?zone=feed&scope=local&state=&district=&subdistrict=&village=` |
| Local feed ads by area | `GET /api/v1/ads/?zone=feed&scope=local&area_id=<uuid>` |
| Article detail ads | `GET /api/v1/ads/?zone=article` |
| Splash ad | `GET /api/v1/ads/?zone=splash` |
| Search ads | `GET /api/v1/ads/?zone=search` |
| Ad impression/click | `POST /api/v1/ads/event/` |
| Booking area list | `GET /api/v1/ads/areas/` |
| Booking pricing | `GET /api/v1/ads/pricing/` |
| Booking submit | `POST /api/v1/ads/bookings/` |

## 14. Implementation Checklist For Frontend

- Render ad image from `image_url`.
- Use `destination_url` on click if present.
- Send impression only when visible.
- Send click before opening destination URL.
- Use `display_frequency` for feed insertion.
- Use local location params for local ads.
- Hide ad section if `data` is empty.
- For booking, call pricing before submit.
- Open `whatsapp_url` after booking.
- Do not implement video playback yet unless backend adds `video_url`.

## 15. Local Ads Frontend Integration

Frontend should pass the user's available location fields when requesting local ads.

Supported location params:

```text
state
district
city
subdistrict
village
area_id
```

Recommended local feed URL:

```http
GET /api/v1/ads/?zone=feed&scope=local&state=Telangana&district=Suryapet&subdistrict=Suryapet%20Rural&village=Kesaram
```

Direct area URL:

```http
GET /api/v1/ads/?zone=feed&scope=local&area_id=08c5c4f8-7334-4135-a6c8-b16c12a7c4de
```

Backend matching priority:

1. `area_id` direct match if provided
2. `village`
3. `subdistrict`
4. `city`
5. `district`
6. `state`
7. global ads are also included

Frontend example:

```js
const params = new URLSearchParams({
  zone: "feed",
  scope: "local",
});

if (location.state) params.append("state", location.state);
if (location.district) params.append("district", location.district);
if (location.city) params.append("city", location.city);
if (location.subdistrict) params.append("subdistrict", location.subdistrict);
if (location.village) params.append("village", location.village);

const response = await fetch(`${API_BASE_URL}/api/v1/ads/?${params.toString()}`);
const body = await response.json();
const ads = body.data || [];
```

Insert ads into feed:

```js
function insertAdsIntoFeed(articles, ads) {
  if (!ads.length) return articles.map((item) => ({ type: "article", item }));

  const result = [];
  let adIndex = 0;

  articles.forEach((article, index) => {
    result.push({ type: "article", item: article });

    const ad = ads[adIndex % ads.length];
    const frequency = ad.display_frequency || 5;

    if ((index + 1) % frequency === 0) {
      result.push({ type: "ad", item: ad });
      adIndex += 1;
    }
  });

  return result;
}
```

Track impression when the ad becomes visible:

```js
await fetch(`${API_BASE_URL}/api/v1/ads/event/`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-Device-ID": deviceId,
  },
  body: JSON.stringify({
    ad_id: ad.id,
    event_type: "impression",
  }),
});
```

Track click before opening the destination:

```js
await fetch(`${API_BASE_URL}/api/v1/ads/event/`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-Device-ID": deviceId,
  },
  body: JSON.stringify({
    ad_id: ad.id,
    event_type: "click",
  }),
});

if (ad.destination_url) {
  Linking.openURL(ad.destination_url);
}
```

If `data` is empty, frontend should hide the ad slot.
