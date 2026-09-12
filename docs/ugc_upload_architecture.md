# VARADHI UGC & Media Upload Architecture — Step 7

## 1. System Overview
Step 7 delivers a production-grade Citizen Reporter (UGC) media capture, client-side preparation, multipart upload transmission, progress observation, and draft recovery system for the Vaaradhi Flutter mobile application.

The implementation strictly complies with backend contracts, maintains clean separation of concerns, offloads heavy media compression to native background engines via `image_picker`, and ensures zero data loss when uploads are interrupted.

---

## 2. Target UGC Architecture

```text
[Presentation Layer]
  CreatePostScreen (UGCSubmitScreen)
      │
      ▼
[Controller & State Layer]
  UgcController (ChangeNotifier)
      │
      ├──> MediaPickerHelper (Camera photo/video, Gallery multi-photo/video with native limits)
      ├──> MediaValidator (10MB image, 50MB video, format, existence, readability)
      └──> UgcDraftRepository (Local persistence of in-progress drafts via SharedPreferences)
      │
      ▼
[Domain / Repository Layer]
  UgcRepository
      │
      ▼
[Network Layer]
  ApiService & ApiClient (Dio)
      ├──> POST /api/v1/ugc/submit/        (JSON payload, obtains submission_id)
      └──> POST /api/v1/ugc/upload-media/  (Multipart form-data, onSendProgress, CancelToken)
```

---

## 3. Endpoints & Protocol Contracts

### 3.1 UGC Submission: `POST /api/v1/ugc/submit/`
- **Authentication**: `Authorization: Bearer <access_token>`
- **Content-Type**: `application/json`
- **Fields**:
  - `mobile`: 10-digit Indian mobile string
  - `title`: News title (max 255 chars)
  - `description`: Detailed report description
  - `category`: News category (e.g. `local`, `politics`, `weather`, `accident`)
  - `content_type`: Enum string (`TEXT`, `IMAGE`, `VIDEO`)
  - `location_lat`, `location_lon`: Decimal coordinate strings
  - `village`, `subdistrict`, `district`, `state`, `country`: Location strings
- **Response**: `201 Created` returning `data.id` (UUID submission ID) and `upload_status: PENDING`.

### 3.2 Multipart Media Upload: `POST /api/v1/ugc/upload-media/`
- **Authentication**: `Authorization: Bearer <access_token>`
- **Content-Type**: `multipart/form-data`
- **Single File Form Data**:
  - `submission_id`: UUID
  - `mobile`: String
  - `media_type`: `IMAGE` or `VIDEO`
  - `file`: Binary file stream
- **Multiple Files Form Data**:
  - `submission_id`: UUID
  - `mobile`: String
  - `media_type`: First item's enum (`IMAGE` or `VIDEO`)
  - `media_types`: Comma-delimited list of types matching file count (e.g. `IMAGE,IMAGE`)
  - `files`: Array of binary file streams
- **Backend Constraints**:
  - `MAX_IMAGE_MB`: 10 MB
  - `MAX_VIDEO_MB`: 50 MB
  - `UGC_MAX_MEDIA_ITEMS`: 10 items

---

## 4. Media Pipeline & Processing

### 4.1 Media Selection
The user is provided with an intuitive bottom sheet supporting:
- **Image News**:
  - "Take Photo with Camera" (`MediaPickerHelper.pickPhotoFromCamera`)
  - "Choose from Gallery" (`MediaPickerHelper.pickPhotosFromGallery`, supports up to 10 images)
- **Video News**:
  - "Record Video with Camera" (`MediaPickerHelper.recordVideoFromCamera`, max 3 mins)
  - "Choose Video from Gallery" (`MediaPickerHelper.pickVideoFromGallery`)

### 4.2 Client-Side Image Preparation (Dimension & Quality Constraints)
To prevent uploading uncompressed 48MP raw camera photos:
- `image_picker` is configured with `maxWidth: 1920`, `maxHeight: 1920`, `imageQuality: 85`.
- Image compression and scaling occur on the native platform background thread before returning to Dart, preventing UI frame drops or main-thread freezing.

### 4.3 Media Validation (`MediaValidator`)
Before any network transmission, media files undergo client validation:
1. **File existence**: Verified on disk via `file.exists()`.
2. **File readability & non-empty**: `file.length() > 0`.
3. **Format & Container**:
   - Allowed Image Extensions: `.jpg`, `.jpeg`, `.png`, `.webp`
   - Allowed Video Extensions: `.mp4`, `.mov`, `.mkv`
4. **Size Bounds**:
   - Image <= 10MB
   - Video <= 50MB
   - Max photos <= 10
If validation fails, a localized, clear user-facing error message is surfaced without crashing.

---

## 5. Upload State Machine & Progress

### 5.1 States
`UgcUploadStatus` enum:
- `idle`: Form editing, no upload active.
- `preparing`: Validating form fields and media files.
- `submitting`: Calling `POST /api/v1/ugc/submit/`.
- `uploading`: Streaming multipart media files to `POST /api/v1/ugc/upload-media/`.
- `completed`: Successfully uploaded and registered with Reporter system.
- `failed`: An error occurred during submission creation or media upload.
- `cancelled`: User actively tapped "Cancel" during upload.

### 5.2 Real Upload Progress
- Dio's `onSendProgress: (sent, total)` is bridged from `ApiClient.post` through `ApiService` into `UgcController`.
- The UI renders an actual `LinearProgressIndicator` showing `Uploading media (45%)...`.
- Fake timer-based progress is strictly avoided.

### 5.3 Upload Cancellation
- When `uploading`, a "Cancel" action is visible.
- Triggering cancellation signals `CancelToken.cancel()`.
- The state transitions to `cancelled`, network connections are terminated immediately, and the draft is preserved for subsequent editing or retry.

---

## 6. Draft Recovery & Local Persistence

### 6.1 Draft Storage (`UgcDraftRepository`)
- Whenever the user edits post title, description, category, or media paths, `UgcDraft` is serialized and persisted to `SharedPreferences`.
- On screen mount, `UgcController.checkForPendingDraft()` detects uncompleted drafts and presents a non-intrusive "Restore Draft" banner.

### 6.2 Submission ID Preservation on Upload Failure
- If `POST /ugc/submit/` succeeds but `POST /ugc/upload-media/` fails, `submission_id` is retained in the draft.
- The UI presents a "Retry Media Upload" button.
- Retrying re-uses the existing `submission_id` instead of generating redundant submissions.

### 6.3 Missing Local File Verification
- If local photos or videos were removed from device storage while the app was closed, `draft.findMissingFiles()` detects the absence.
- Missing files are filtered out, and a warning banner notifies the user: "Some attached media files are no longer available on your device. Please re-attach them."

---

## 7. Location & Authentication Verification

### 7.1 Location Verification
- Rule 29 Compliance: Real GPS coordinates (`AppState.instance.latitude` & `longitude`) are required.
- If coordinates are absent, the app does not substitute hardcoded fake coordinates; it prompts the user to enable GPS or detect location before submission.

### 7.2 Authentication & OTP Verification
- Submission requires an active JWT session.
- If the account has not completed mobile verification (`!AppState.instance.uploadVerified`), a bottom sheet prompts for OTP (`/api/v1/ugc/send-otp/` and `/api/v1/ugc/verify-otp/`).
- Supports 4 to 6 digit OTP codes.
- Once verified, `AppState.instance.markUploadVerified()` persists the verified state so future submissions proceed directly.

---

## 8. Test Matrix & Verification

| Test Area | Scenarios Covered | Status |
| :--- | :--- | :--- |
| **Media Validation** | Valid JPEG, PNG, MP4; non-existent file; empty file; unsupported format (.pdf); missing extension; oversized image (>10MB); batch size capping at 10 items | **PASS** (9 tests) |
| **Draft Management** | JSON serialization/deserialization; missing local media detection; draft save, load, and clear lifecycle | **PASS** (3 tests) |
| **Controller & State Machine** | Missing title/description validation; missing media validation; missing location handling; full submit/upload pipeline completion; upload failure draft & submissionId preservation; retry without duplicate submission; cancellation via CancelToken; duplicate in-flight submit rejection | **PASS** (7 tests) |
| **Regression Test Suite** | 138 total project unit & widget tests covering APIs, feeds, media player, ads, navigation, and performance | **PASS** (138 tests) |
| **Static Analysis** | `flutter analyze` across entire project | **PASS** (0 issues) |
| **Debug APK Build** | `flutter build apk --debug` | **PASS** |
| **Release APK Build** | `flutter build apk --release` | **PASS** |
