# Backend contract: same engagement for citizen posts, reports for every story

> **Status (2026-09-26): implemented by the backend.** The authoritative
> contract is now `frontend_handover_latest.md` §17. Differences from this
> proposal: UGC bookmarks sync per account, but `GET /api/v1/bookmarks/` stays
> article-only; a 404 means "not found / not public", not "endpoint missing".
> Kept for history only.

The app now shows the same actions on every story, desk article or citizen
(UGC) post: **Like, Dislike, Save, Share, Report**. The endpoints for citizen
posts, and the report endpoint for desk articles, are not in
`fullprojectapidocument.md`. The app already calls the paths below and
detects whether each one exists:

- **Endpoint returns 404 / 405 / 501:** Like, Dislike and Save on citizen posts
  are stored on the device; Report on desk articles falls back to an email
  to the newsroom.
- **Endpoint returns 2xx:** the action syncs to the server, with no app release
  needed.

All paths live in one class: `EngagementEndpoints` in
`lib/services/content_engagement_service.dart`. If the backend chooses
different paths, change them there only.

Response envelope everywhere is the existing `{data, meta, errors}`.

## 1. Report a desk article (needed for Play Store)

Google Play's User Generated Content policy requires an in-app way to report
objectionable content. Citizen posts already have `/api/v1/ugc/report/`. Desk
articles need the equivalent:

```http
POST /api/v1/articles/{article_id}/report/
Authorization: Bearer <access_token>

{ "reason": "misinformation", "notes": "optional free text" }
```

- `reason` values the app sends: `misinformation`, `inappropriate`, `spam`,
  `copyright`, `other`.
- Success: `201`.
- Duplicate: `400` with `errors.message` containing
  **"already reported"**. The app shows "You have already reported this story".
- Reports should appear in the admin Reports queue next to UGC reports.

## 2. Like / Dislike a citizen post

Same shape as `/api/v1/articles/{article_id}/reaction/`:

```http
PUT    /api/v1/ugc/{submission_id}/reaction/   { "reaction_type": "like" | "dislike" }
DELETE /api/v1/ugc/{submission_id}/reaction/
```

Success `data`: `{ "like_count": 12, "dislike_count": 1 }`. The app reads
`like_count` / `dislike_count` to correct its optimistic counts. Guests are
allowed today for articles, so the same should hold here (identified by
`X-Device-ID`).

The UGC feed (`GET /api/v1/ugc/feed/`) should then include `likes_count`,
`dislike_count`, `is_liked_by_user`, `is_disliked_by_user`, matching articles.

## 3. Save (bookmark) a citizen post

```http
POST /api/v1/ugc/{submission_id}/bookmark/toggle/
Authorization: Bearer <access_token>
```

Success `data`: `{ "bookmarked": true | false }`.

`GET /api/v1/bookmarks/` should then return saved citizen posts too, each
with `"feed_item_type": "ugc"` so the app opens them as citizen posts. When
the endpoint goes live, the app drops its device-only copy the next time
the reader saves or unsaves that story.

## Already identical, no backend work

- **Share:** citizen posts share `https://vaaradhinews.com/ugc/{id}`, desk
  articles `…/article/{slug}`. The web routes must serve both.
