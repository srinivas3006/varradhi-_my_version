# VARADHI UGC & Media Upload Audit — Step 7

## Executive Summary
This document provides a comprehensive audit of the Citizen Reporter / User-Generated Content (UGC) subsystem in the Vaaradhi Flutter application prior to implementing Step 7. The audit covers media selection, validation, client-side preparation, multipart upload transmission, progress monitoring, state transitions, draft persistence, error handling, location verification, and authentication integration.

---

## 1. Codebase Inventory & Search Audit

A complete search was performed across the codebase for UGC and media upload keywords:

| Search Term | Occurrences | Key Locations | Current Usage Status |
| :--- | :--- | :--- | :--- |
| `image_picker` | 3 files | `pubspec.yaml`, `profile_tab.dart`, `create_post_screen.dart`, `admin_branded_media_sheet.dart` | Package `image_picker: ^1.2.3` is installed and used for gallery multi-image picking and video selection. Camera capture option is not exposed in the UI. |
| `camera` | 1 file | `profile_tab.dart` (icon only) | No direct `camera` package is installed. `image_picker` provides native `ImageSource.camera` support for photo capture and video recording. |
| `file_picker` | 0 files | None | Not installed; not needed since `image_picker` satisfies all photo and video requirements. |
| `XFile` | 2 files | `create_post_screen.dart`, `profile_tab.dart` | `List<XFile>` used for in-memory media handles during creation session. |
| `MultipartFile` | 2 files | `api_service.dart`, `admin_ugc_api_service.dart` | `MultipartFile.fromFile(path)` used in `uploadMedia` and `uploadMediaBatch`. |
| `FormData` | 2 files | `api_service.dart`, `admin_ugc_api_service.dart` | `FormData.fromMap(...)` constructs multipart form data for Dio POST. |
| `sendUpload` / `upload` | 10+ files | `api_service.dart`, `create_post_screen.dart` | `uploadMedia` and `uploadMediaBatch` methods in `ApiService`. |
| `submitUgc` | 2 files | `api_service.dart`, `create_post_screen.dart`, `ugc_repository.dart` | Sends JSON payload to `POST /api/v1/ugc/submit/`. |
| `UGC` | 30+ files | Repositories, state, screens, admin modules | UGC feed, submission, reporter status, and admin moderation. |
| `draft` | 2 files | `ai_service.dart`, `create_post_screen.dart` | PopScope discard dialog mentions draft loss, but **zero draft persistence or recovery** is implemented. |

---

## 2. Component-by-Component Audit

### 2.1 `create_post_screen.dart`
- **Architecture Violation**: The widget directly calls `ApiService.instance.submitUgc` and `ApiService.instance.uploadMediaBatch` inside a private state method (`_finalizeSubmission`). No controller, state machine, or separation of concerns.
- **Media Picking**: Only triggers `pickMultiImage()` for images and `pickVideo(source: ImageSource.gallery)` for video. There is no UI sheet or dialog allowing the user to choose between **Camera** and **Gallery**.
- **Media Validation**: No file existence check, no file readability check, no file size validation (backend limits 10MB for image, 50MB for video), and no MIME type or extension verification.
- **Media Preparation / Compression**: Uploads raw picked files without dimension constraints or compression quality settings. High-resolution camera photos (e.g. 48MP/12MB) are sent uncompressed.
- **Location Verification**: Uses hardcoded fallback coordinates (`17.141500`, `79.623600`) if `AppState.instance.latitude` is null. This violates Rule 29 ("Do not send fake coordinates; show location selection requirement").
- **OTP Verification**: Modal sheet hardcodes a 4-digit check (`_otpController.text.length != 4`), whereas backend documentation specifies 6-digit OTPs (`123456`).
- **Progress Tracking**: Shows only an indeterminate `CircularProgressIndicator`. Dio's `onSendProgress` is not hooked up, so users receive no actual percentage indicator (e.g., "Uploading 42%").
- **Failure Recovery & State**: If `submitUgc` succeeds but `uploadMedia` fails, the `submission_id` is lost. There is no "Retry Upload" option, and the draft is wiped if the user leaves.
- **Duplicate Submissions**: Protected only by a single `_submitting` boolean flag, but lacking debouncing or state-machine cancellation.

### 2.2 `ugc_submit_screen.dart` & `ugc_reporter_dashboard.dart`
- `ugc_submit_screen.dart`: A simple wrapper delegating directly to `CreatePostScreen`.
- `ugc_reporter_dashboard.dart`: A simple wrapper delegating to `MyPostsScreen`.
- Navigation contracts are stable and preserve route architecture.

### 2.3 `ugc_feed_screen.dart`
- Clean cursor pagination using `UgcRepository.instance.getUgcFeed`.
- Pull-to-refresh and infinite scroll working properly.
- Safe fallback UI for errors and empty reports.

### 2.4 `UgcRepository` (`ugc_repository.dart`)
- Currently only wraps `getUgcFeed` and a bare `submitPost`.
- Does not expose submission creation, media upload, progress streams, cancellation, or draft persistence.
- Needs to become the domain orchestrator for UGC operations.

### 2.5 `ApiService` (`api_service.dart`) & `ApiClient` (`dio_client.dart`)
- `submitUgc(Map<String, dynamic> data)` calls `POST /api/v1/ugc/submit/`.
- `uploadMedia(...)` and `uploadMediaBatch(...)` call `POST /api/v1/ugc/upload-media/`.
- **Missing Parameters**:
  - `onSendProgress` (`ProgressCallback`) is missing from `uploadMedia`, `uploadMediaBatch`, and `ApiClient.post`.
  - `CancelToken` is missing from `uploadMedia` and `uploadMediaBatch`.
- Token refresh: `ApiClient` handles 401 with atomic token refresh via `/api/v1/auth/token/refresh/`. However, long multipart uploads might fail if tokens expire mid-stream unless the refresh is handled cleanly without discarding in-flight draft state.

### 2.6 Authentication & Verification Flow
- `AppState.instance.isLoggedIn` / `authToken`: Stores user session.
- `AppState.instance.uploadVerified`: Persisted in `SharedPreferences`.
- Backend UGC mobile verification contract:
  - `POST /api/v1/ugc/send-otp/`: `{"mobile": "..."}`
  - `POST /api/v1/ugc/verify-otp/`: `{"mobile": "...", "otp": "..."}`
- Once verified, future submissions skip OTP.

### 2.7 Reporter Submission Status (`my_posts_screen.dart`)
- Fetches `GET /api/v1/ugc/reporter/submissions/` with filter tabs (`all`, `pending`, `approved`, `published`, `rejected`).
- Displays token awards and rejection reasons cleanly.
- After a new submission in `CreatePostScreen`, local state is inserted, but refreshing remote submissions is decoupled.

---

## 3. Backend Contract Verification

### Submission Endpoint: `POST /api/v1/ugc/submit/`
- **Request Format**: JSON (`application/json`)
- **Headers**: `Authorization: Bearer <access_token>`
- **Fields**:
  - `mobile` (required string, 10-digit Indian mobile)
  - `title` (required string, max 255 chars)
  - `description` (required string)
  - `category` (optional string, max 100 chars, e.g. "local", "sports", "politics")
  - `content_type` (required enum: `TEXT`, `IMAGE`, `VIDEO`)
  - `location_lat`, `location_lon` (decimal strings)
  - `village`, `subdistrict`, `district`, `state`, `country` (strings)
- **Response**: `201 Created` with `data.id` (UUID submission ID), `data.upload_status: "PENDING"`.

### Media Upload Endpoint: `POST /api/v1/ugc/upload-media/`
- **Request Format**: Multipart Form Data (`multipart/form-data`)
- **Headers**: `Authorization: Bearer <access_token>`
- **Single File Fields**:
  - `submission_id`: UUID
  - `mobile`: String
  - `media_type`: Exact enum (`IMAGE` or `VIDEO`)
  - `file`: Binary file stream
- **Multiple Files Fields**:
  - `submission_id`: UUID
  - `mobile`: String
  - `media_type`: First item's enum (`IMAGE` or `VIDEO`)
  - `media_types`: Comma-separated enums (e.g. `IMAGE,IMAGE,IMAGE`)
  - `files`: Array of binary file streams
- **Constraints**:
  - `MAX_IMAGE_MB`: 10 MB
  - `MAX_VIDEO_MB`: 50 MB
  - `UGC_MAX_MEDIA_ITEMS`: 10 items
  - Allowed image extensions: `.jpg`, `.jpeg`, `.png`, `.webp`
  - Allowed video extensions: `.mp4`, `.mov`, `.mkv`

---

## 4. Gap Analysis & Required Solutions

| # | Current Defect | Impact | Step 7 Solution |
| :--- | :--- | :--- | :--- |
| 1 | Widget handles network logic directly | Difficult to test, state lost on rebuilds | Introduce `UgcUploadManager` / `UgcController` separating presentation from domain. |
| 2 | No actual upload progress percentage | Users see frozen spinner on slow 4G/5G | Pass `onSendProgress` from Dio through `ApiClient` and `ApiService` to `UgcController`. |
| 3 | Camera capture not offered in UI | Users cannot take a photo or record video live | Bottom sheet with Camera and Gallery choices for both Image and Video modes. |
| 4 | No media validation | Oversized files cause 400 backend errors | Client-side `MediaValidator` checking existence, size (<10MB image, <50MB video), and format. |
| 5 | Raw camera resolution uploaded | Slow uploads, excessive bandwidth | Built-in `image_picker` resize: `maxWidth: 1920`, `maxHeight: 1920`, `imageQuality: 85`. |
| 6 | Fake coordinates sent when GPS missing | Corrupts local news geolocation | Check coordinates; if absent, trigger location prompt/selection before allowing submit. |
| 7 | No draft persistence | App exit or crash loses user story and media | `UgcDraft` model persisted in `SharedPreferences`; prompt to restore on screen entry. |
| 8 | Submission ID lost on upload failure | User forced to re-create submission from scratch | Preserve `submission_id` in draft; show "Retry Media Upload" button. |
| 9 | 4-digit OTP hardcoded | Fails with backend 6-digit OTP | Update OTP input to accept standard 4 to 6 digit codes. |
| 10 | No upload cancellation | User trapped during 40MB video upload on slow connection | Wire `CancelToken` to a user-facing "Cancel Upload" action. |

---

## 5. Media Package Verification
`image_picker: ^1.2.3` in `pubspec.yaml` satisfies all requirements:
1. Multi-image selection (`pickMultiImage`)
2. Single-image camera capture (`pickImage(source: ImageSource.camera)`)
3. Video camera recording (`pickVideo(source: ImageSource.camera)`)
4. Video gallery picking (`pickVideo(source: ImageSource.gallery)`)
5. Built-in off-UI-thread resizing (`maxWidth`, `maxHeight`, `imageQuality`).

No additional packages are required. Existing dependencies (`dio`, `path_provider`, `shared_preferences`, `geolocator`) will be reused.
