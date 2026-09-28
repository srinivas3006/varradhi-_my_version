import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import '../core/errors/app_exception.dart';
import '../core/errors/ugc_error.dart';
import '../core/utils/media_picker_helper.dart';
import '../core/utils/media_validator.dart';
import '../models/reporter_post.dart';
import '../models/ugc_draft.dart';
import '../repositories/ugc_draft_repository.dart';
import '../repositories/ugc_repository.dart';
import '../services/location_permission_coordinator.dart';
import '../state/app_state.dart';

/// Production controller managing Citizen Reporter (UGC) lifecycle,
/// media validation, multipart upload progress, draft persistence,
/// bounded retries, and cancellation.
class UgcController extends ChangeNotifier {
  final UgcRepository _ugcRepository;
  final UgcDraftRepository _draftRepository;
  final MediaPickerHelper _pickerHelper;

  UgcController({
    UgcRepository? ugcRepository,
    UgcDraftRepository? draftRepository,
    MediaPickerHelper? pickerHelper,
  })  : _ugcRepository = ugcRepository ?? UgcRepository.instance,
        _draftRepository = draftRepository ?? UgcDraftRepository.instance,
        _pickerHelper = pickerHelper ?? MediaPickerHelper();

  // Form State
  PostType _type = PostType.image;
  String _category = 'Local';
  String _title = '';
  String _description = '';
  List<String> _selectedImagePaths = [];
  String? _selectedVideoPath;

  // Process & Upload State
  UgcUploadStatus _status = UgcUploadStatus.idle;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  UgcErrorKind? _errorKind;
  String? _submissionId;

  /// Set when POST /submit/ got no response, so it may or may not exist on
  /// the server. Cleared once My Submissions has been checked.
  DateTime? _unconfirmedSubmitAt;
  CancelToken? _cancelToken;

  // Draft recovery flag
  UgcDraft? _pendingDraft;
  List<String> _missingFilesWarning = [];

  // Getters
  PostType get type => _type;
  String get category => _category;
  String get title => _title;
  String get description => _description;
  List<String> get selectedImagePaths => List.unmodifiable(_selectedImagePaths);
  String? get selectedVideoPath => _selectedVideoPath;
  UgcUploadStatus get status => _status;
  double get uploadProgress => _uploadProgress;
  String? get errorMessage => _errorMessage;

  /// Kind of the last backend failure, so the screen can react (open
  /// verification, disable the button) without parsing messages.
  UgcErrorKind? get errorKind => _errorKind;
  String? get submissionId => _submissionId;

  /// The submission that just finished uploading, for status tracking.
  String? _lastCompletedSubmissionId;
  String? get lastCompletedSubmissionId => _lastCompletedSubmissionId;

  /// Uploads are off: backend said daily limit reached or uploader blocked.
  bool get isUploadRestricted =>
      AppState.instance.isUgcDailyLimitActive ||
      AppState.instance.isUgcUploaderBlocked;

  static String _t(String te, String en) =>
      AppState.instance.language == 'Telugu' ? te : en;

  static String get dailyLimitMessage => _t(
      'ఈరోజు అప్‌లోడ్ పరిమితి పూర్తయింది. రేపు మళ్లీ ప్రయత్నించండి.',
      'Daily upload limit reached. You can post again tomorrow.');

  static String get blockedMessage => _t(
      'మీ ఖాతా నుండి వార్తలు పంపడం నిలిపివేయబడింది. సహాయం కోసం సపోర్ట్‌ను సంప్రదించండి.',
      'Uploading is blocked for your account. Please contact support.');
  UgcDraft? get pendingDraft => _pendingDraft;
  List<String> get missingFilesWarning =>
      List.unmodifiable(_missingFilesWarning);

  bool get isSubmittingOrUploading =>
      _status == UgcUploadStatus.preparing ||
      _status == UgcUploadStatus.submitting ||
      _status == UgcUploadStatus.uploading;

  bool get hasUnsavedChanges =>
      _title.trim().isNotEmpty ||
      _description.trim().isNotEmpty ||
      _selectedImagePaths.isNotEmpty ||
      _selectedVideoPath != null;

  // Setters & Form Mutators
  void setType(PostType newType) {
    if (_type == newType) return;
    _type = newType;
    if (_type == PostType.image) {
      _selectedVideoPath = null;
    } else {
      _selectedImagePaths.clear();
    }
    _errorMessage = null;
    notifyListeners();
    _autoSaveDraft();
  }

  void setCategory(String newCategory) {
    _category = newCategory;
    notifyListeners();
    _autoSaveDraft();
  }

  void setTitle(String newTitle) {
    _title = newTitle;
    notifyListeners();
    _autoSaveDraft();
  }

  void setDescription(String newDescription) {
    _description = newDescription;
    notifyListeners();
    _autoSaveDraft();
  }

  // --- Media Selection ---

  Future<void> pickPhotoFromCamera() async {
    final xFile = await _pickerHelper.pickPhotoFromCamera();
    if (xFile != null) {
      if (_selectedImagePaths.length < MediaValidator.maxMediaItems) {
        _selectedImagePaths.add(xFile.path);
      } else {
        _errorMessage =
            'Maximum ${MediaValidator.maxMediaItems} photos are allowed.';
      }
      notifyListeners();
      _autoSaveDraft();
    }
  }

  Future<void> pickPhotosFromGallery() async {
    final remainingSlots =
        MediaValidator.maxMediaItems - _selectedImagePaths.length;
    if (remainingSlots <= 0) {
      _errorMessage = 'Maximum ${MediaValidator.maxMediaItems} photos reached.';
      notifyListeners();
      return;
    }

    final xFiles =
        await _pickerHelper.pickPhotosFromGallery(maxItems: remainingSlots);
    if (xFiles.isNotEmpty) {
      for (final f in xFiles) {
        if (_selectedImagePaths.length < MediaValidator.maxMediaItems &&
            !_selectedImagePaths.contains(f.path)) {
          _selectedImagePaths.add(f.path);
        }
      }
      _errorMessage = null;
      notifyListeners();
      _autoSaveDraft();
    }
  }

  Future<void> recordVideoFromCamera() async {
    final xFile = await _pickerHelper.recordVideoFromCamera();
    if (xFile != null) {
      _selectedVideoPath = xFile.path;
      _errorMessage = null;
      notifyListeners();
      _autoSaveDraft();
    }
  }

  Future<void> pickVideoFromGallery() async {
    final xFile = await _pickerHelper.pickVideoFromGallery();
    if (xFile != null) {
      _selectedVideoPath = xFile.path;
      _errorMessage = null;
      notifyListeners();
      _autoSaveDraft();
    }
  }

  void removeImageAt(int index) {
    if (index >= 0 && index < _selectedImagePaths.length) {
      _selectedImagePaths.removeAt(index);
      notifyListeners();
      _autoSaveDraft();
    }
  }

  void clearMedia() {
    _selectedImagePaths.clear();
    _selectedVideoPath = null;
    notifyListeners();
    _autoSaveDraft();
  }

  // --- Draft Management ---

  Future<void> checkForPendingDraft() async {
    final draft = await _draftRepository.loadDraft();
    if (draft != null && draft.hasContent) {
      _pendingDraft = draft;
      notifyListeners();
    }
  }

  Future<void> restorePendingDraft() async {
    if (_pendingDraft == null) return;
    final draft = _pendingDraft!;

    _title = draft.title;
    _description = draft.description;
    _category = draft.category;
    _type =
        draft.type.toUpperCase() == 'VIDEO' ? PostType.video : PostType.image;
    _submissionId = draft.submissionId;

    // Validate local files
    final missing = await draft.findMissingFiles();
    _missingFilesWarning = missing;

    if (_type == PostType.image) {
      _selectedImagePaths =
          draft.filePaths.where((p) => !missing.contains(p)).toList();
      _selectedVideoPath = null;
    } else {
      if (draft.filePaths.isNotEmpty &&
          !missing.contains(draft.filePaths.first)) {
        _selectedVideoPath = draft.filePaths.first;
      } else {
        _selectedVideoPath = null;
      }
      _selectedImagePaths.clear();
    }

    _pendingDraft = null;
    notifyListeners();
  }

  void dismissPendingDraft() {
    _pendingDraft = null;
    notifyListeners();
  }

  Future<void> discardDraft() async {
    _title = '';
    _description = '';
    _selectedImagePaths.clear();
    _selectedVideoPath = null;
    _submissionId = null;
    _unconfirmedSubmitAt = null;
    _status = UgcUploadStatus.idle;
    _uploadProgress = 0.0;
    _errorMessage = null;
    _missingFilesWarning.clear();
    await _draftRepository.clearDraft();
    notifyListeners();
  }

  void _autoSaveDraft() {
    if (!hasUnsavedChanges) return;
    final draft = UgcDraft(
      title: _title,
      description: _description,
      category: _category,
      type: _type == PostType.image ? 'IMAGE' : 'VIDEO',
      filePaths: _type == PostType.image
          ? _selectedImagePaths
          : (_selectedVideoPath != null ? [_selectedVideoPath!] : []),
      submissionId: _submissionId,
      uploadStatus: _status,
      locationLat: AppState.instance.latitude?.toString(),
      locationLon: AppState.instance.longitude?.toString(),
      district: AppState.instance.district,
      stateName: AppState.instance.stateName,
      mobile: AppState.instance.ugcVerifiedMobile,
    );
    _draftRepository.saveDraft(draft);
  }

  // --- Location Requirement ---

  /// Citizen reports need real GPS coordinates (manual admin-area selection
  /// is not enough — see the "prevent fake coordinates" check below), so
  /// this is a genuine strong-permission moment: it shows the reader why
  /// before asking, via [LocationPermissionCoordinator]'s sheet, rather than
  /// popping the native dialog with no context.
  Future<bool> ensureLocationAvailable(BuildContext context) async {
    if (AppState.instance.latitude != null &&
        AppState.instance.longitude != null) {
      return true;
    }
    final applied = await LocationPermissionCoordinator.requestCurrentLocation(
      context,
      reason: LocationPromptReason.post,
    );
    final hasCoords = AppState.instance.latitude != null &&
        AppState.instance.longitude != null;
    if (!applied || !hasCoords) {
      _errorMessage = 'దయచేసి GPS ద్వారా మీ ప్రాంతాన్ని గుర్తించండి.';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  // --- Submission & Upload Pipeline ---

  /// Primary action called when the user taps Submit or Retry.
  Future<bool> submitNews(BuildContext context) async {
    if (isSubmittingOrUploading) return false;
    _errorKind = null;

    // 0. Backend-imposed restrictions: don't hammer the server.
    if (AppState.instance.isUgcUploaderBlocked) {
      _status = UgcUploadStatus.failed;
      _errorKind = UgcErrorKind.uploaderBlocked;
      _errorMessage = blockedMessage;
      notifyListeners();
      return false;
    }
    if (AppState.instance.isUgcDailyLimitActive) {
      _status = UgcUploadStatus.failed;
      _errorKind = UgcErrorKind.dailyLimitReached;
      _errorMessage = dailyLimitMessage;
      notifyListeners();
      return false;
    }

    // 1. Form Validation
    if (_title.trim().isEmpty) {
      _errorMessage = 'దయచేసి వార్త శీర్షికను (Title) నమోదు చేయండి.';
      notifyListeners();
      return false;
    }
    if (_description.trim().isEmpty) {
      _errorMessage =
          'దయచేసి వార్త పూర్తి వివరాలను (Description) నమోదు చేయండి.';
      notifyListeners();
      return false;
    }

    // 2. Media Selection & Validation
    if (_type == PostType.image && _selectedImagePaths.isEmpty) {
      _errorMessage = 'దయచేసి కనీసం ఒక ఫోటోను జతపరచండి.';
      notifyListeners();
      return false;
    }
    if (_type == PostType.video && _selectedVideoPath == null) {
      _errorMessage = 'దయచేసి వీడియోను జతపరచండి.';
      notifyListeners();
      return false;
    }

    _status = UgcUploadStatus.preparing;
    _errorMessage = null;
    notifyListeners();

    if (_type == PostType.image) {
      final validation =
          await MediaValidator.validateImagesBatch(_selectedImagePaths);
      if (!validation.isValid) {
        _status = UgcUploadStatus.failed;
        _errorMessage = validation.errorMessage;
        notifyListeners();
        return false;
      }
    } else {
      final validation =
          await MediaValidator.validateVideo(_selectedVideoPath!);
      if (!validation.isValid) {
        _status = UgcUploadStatus.failed;
        _errorMessage = validation.errorMessage;
        notifyListeners();
        return false;
      }
    }

    // 3. Location Verification (Prevent fake coordinates)
    if (!context.mounted) {
      _status = UgcUploadStatus.failed;
      notifyListeners();
      return false;
    }
    final hasLoc = await ensureLocationAvailable(context);
    if (!hasLoc) {
      _status = UgcUploadStatus.failed;
      notifyListeners();
      return false;
    }

    // 4a. Verified UGC mobile. Only the backend-returned 10-digit number is
    // ever sent — never +91, never the profile phone, never a placeholder.
    if (!AppState.instance.uploadVerified) {
      _status = UgcUploadStatus.verificationRequired;
      _errorKind = UgcErrorKind.mobileNotVerified;
      _errorMessage = null;
      notifyListeners();
      return false;
    }
    final mobile = AppState.instance.ugcVerifiedMobile;
    // Backend enums are uppercase (content_type TEXT|IMAGE|VIDEO, media_type
    // IMAGE|VIDEO|SHORT_VIDEO); lowercase fails serializer validation.
    final mediaType = _type == PostType.image ? 'IMAGE' : 'VIDEO';

    // 4-pre. The last submit timed out, so it may have been created. Never
    // re-POST blindly (it is not idempotent): look for it in My Submissions
    // first and continue with that id if it is there.
    final unconfirmedAt = _unconfirmedSubmitAt;
    if ((_submissionId == null || _submissionId!.isEmpty) &&
        unconfirmedAt != null) {
      _status = UgcUploadStatus.submitting;
      notifyListeners();
      try {
        final existing = await _ugcRepository.findRecentSubmission(
          title: _title,
          since: unconfirmedAt.subtract(const Duration(minutes: 2)),
        );
        _unconfirmedSubmitAt = null;
        if (existing != null) {
          _submissionId = existing;
          _autoSaveDraft();
        }
      } catch (_) {
        _status = UgcUploadStatus.failed;
        _errorKind = UgcErrorKind.network;
        _errorMessage = _t(
            'మునుపటి సమర్పణ స్థితిని నిర్ధారించలేకపోయాము. కనెక్షన్ తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
            'Could not confirm the previous submit. Check your connection and try again.');
        notifyListeners();
        return false;
      }
    }

    // 4. Submission creation (POST /api/v1/ugc/submit/) if submissionId doesn't exist
    if (_submissionId == null || _submissionId!.isEmpty) {
      _status = UgcUploadStatus.submitting;
      notifyListeners();

      final attemptAt = DateTime.now();
      try {
        final submissionPayload = {
          'mobile': mobile,
          'title': _title.trim(),
          'description': _description.trim(),
          'category': _category.toLowerCase(),
          'content_type': mediaType,
          'media_url': '',
          'thumbnail_url': '',
          'location_lat': AppState.instance.latitude!.toString(),
          'location_lon': AppState.instance.longitude!.toString(),
          'village': AppState.instance.village,
          'subdistrict': AppState.instance.subdistrict,
          'district': AppState.instance.district,
          'state': AppState.instance.stateName,
          'country': 'India',
        };

        final response = await _ugcRepository.submitPost(submissionPayload);
        _submissionId =
            (response['submission_id'] ?? response['id'])?.toString();
        _autoSaveDraft();
      } catch (e) {
        // No response (timeout / dropped connection): the server may still
        // have created it. The next attempt checks before re-posting.
        if (UgcApiError.from(e).kind == UgcErrorKind.network) {
          _unconfirmedSubmitAt = attemptAt;
        }
        return _failFromBackend(
            e,
            _t('వార్తను సమర్పించడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.',
                'Could not submit the news. Please try again.'));
      }
    }

    // If server created submission, proceed to media upload
    if (_submissionId == null || _submissionId!.isEmpty) {
      _status = UgcUploadStatus.failed;
      _errorMessage =
          'సర్వర్ నుండి రిఫరెన్స్ ఐడీ రాలేదు. దయచేసి మళ్ళీ ప్రయత్నించండి.';
      notifyListeners();
      return false;
    }

    // 5. Multipart Media Upload (POST /api/v1/ugc/upload-media/) with Progress & Cancel
    _status = UgcUploadStatus.uploading;
    _uploadProgress = 0.0;
    _cancelToken = CancelToken();
    notifyListeners();

    bool uploadSuccess = false;
    int retryCount = 0;
    const maxRetries = 2;

    while (!uploadSuccess && retryCount <= maxRetries) {
      try {
        if (_type == PostType.image) {
          if (_selectedImagePaths.length == 1) {
            await _ugcRepository.uploadMedia(
              submissionId: _submissionId!,
              mobile: mobile,
              mediaType: mediaType,
              filePath: _selectedImagePaths.first,
              onSendProgress: _onSendProgress,
              cancelToken: _cancelToken,
            );
          } else {
            await _ugcRepository.uploadMediaBatch(
              submissionId: _submissionId!,
              mobile: mobile,
              filePaths: _selectedImagePaths,
              mediaTypes: List.filled(_selectedImagePaths.length, mediaType),
              onSendProgress: _onSendProgress,
              cancelToken: _cancelToken,
            );
          }
        } else {
          await _ugcRepository.uploadMedia(
            submissionId: _submissionId!,
            mobile: mobile,
            mediaType: mediaType,
            filePath: _selectedVideoPath!,
            onSendProgress: _onSendProgress,
            cancelToken: _cancelToken,
          );
        }
        uploadSuccess = true;
      } catch (e) {
        if ((e is DioException && CancelToken.isCancel(e)) ||
            (_cancelToken?.isCancelled ?? false)) {
          _status = UgcUploadStatus.cancelled;
          _errorMessage = 'అప్‌లోడ్ రద్దు చేయబడింది.';
          notifyListeners();
          return false;
        }

        final error = UgcApiError.from(e);
        final status = error.statusCode;
        // Do NOT retry 4xx client errors (validation, verification,
        // limit, block, auth rejection…).
        if (status != null && status >= 400 && status < 500) {
          return _failFromBackend(
              error,
              _t('మీడియా అప్‌లోడ్ చెల్లుబాటు కాలేదు ($status).',
                  'Media upload was rejected ($status).'));
        }

        // Bounded retry for transient 5xx or connection issues
        retryCount++;
        if (retryCount > maxRetries) {
          _status = UgcUploadStatus.failed;
          _errorKind = error.kind;
          _errorMessage = error.isRetryable
              ? 'నెట్‌వర్క్ సమస్య కారణంగా మీడియా అప్‌లోడ్ విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.'
              : (e is AppException
                  ? e.message
                  : 'మీడియా అప్‌లోడ్ విఫలమైంది.');
          notifyListeners();
          return false;
        }
        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    // 6. Success handling
    _status = UgcUploadStatus.completed;
    _uploadProgress = 1.0;
    unawaited(AppState.instance.clearUgcUploadRestrictions());
    // Done with this submission: the next story must create a new one, not
    // upload its media into this one.
    _lastCompletedSubmissionId = _submissionId;
    _submissionId = null;
    _unconfirmedSubmitAt = null;

    // Register local post in AppState for immediate dashboard reflection
    AppState.instance.submitReporterPost(
      type: _type,
      caption: _title.trim(),
      category: _category,
      mediaUrl: _type == PostType.image && _selectedImagePaths.isNotEmpty
          ? _selectedImagePaths.first
          : (_selectedVideoPath ?? ''),
    );

    // Clear completed draft from disk
    await _draftRepository.clearDraft();

    notifyListeners();
    return true;
  }

  /// Applies the documented frontend action for a failed submit/upload and
  /// returns false so callers can `return _failFromBackend(...)`.
  Future<bool> _failFromBackend(Object e, String fallbackMessage) async {
    final error = UgcApiError.from(e);
    _errorKind = error.kind;
    switch (error.kind) {
      case UgcErrorKind.mobileNotVerified:
        // Backend is the source of truth: drop the stale cache and verify.
        await AppState.instance.clearUgcVerification();
        _status = UgcUploadStatus.verificationRequired;
        _errorMessage = null;
        break;
      case UgcErrorKind.mobileMismatch:
        // The account is bound to a different number than we sent. Re-run
        // verification; the backend will only accept that bound number and
        // hand it back, and the retry then uses it.
        await AppState.instance.clearUgcVerification();
        _status = UgcUploadStatus.verificationRequired;
        _errorMessage = _t(
            'మీ ఖాతా మరో మొబైల్ నంబర్‌తో ధృవీకరించబడింది. దయచేసి ఆ నంబర్‌ను ధృవీకరించండి.',
            'Your account is verified with a different mobile number. Please verify that number.');
        break;
      case UgcErrorKind.nonIndianPhone:
      case UgcErrorKind.tokenMissingPhone:
        // The saved number cannot be used: verify again with Firebase.
        await AppState.instance.clearUgcVerification();
        _status = UgcUploadStatus.verificationRequired;
        _errorMessage = error.kind == UgcErrorKind.nonIndianPhone
            ? _t('దయచేసి సరైన భారతీయ మొబైల్ నంబర్ ఉపయోగించండి.',
                'Please use a valid Indian mobile number.')
            : null;
        break;
      case UgcErrorKind.dailyLimitReached:
        await AppState.instance.markUgcDailyLimitReached();
        _status = UgcUploadStatus.failed;
        _errorMessage = dailyLimitMessage;
        break;
      case UgcErrorKind.uploaderBlocked:
        await AppState.instance.markUgcUploaderBlocked();
        _status = UgcUploadStatus.failed;
        _errorMessage = blockedMessage;
        break;
      case UgcErrorKind.cancelled:
        _status = UgcUploadStatus.cancelled;
        _errorMessage = 'అప్‌లోడ్ రద్దు చేయబడింది.';
        break;
      case UgcErrorKind.sessionExpired:
        _status = UgcUploadStatus.failed;
        _errorMessage = _t(
            'సెషన్ గడువు ముగిసింది. దయచేసి మళ్లీ లాగిన్ అవ్వండి.',
            'Your session expired. Please log in again.');
        break;
      default:
        _status = UgcUploadStatus.failed;
        _errorMessage = (e is AppException ||
                    (e is DioException && e.error is AppException)) &&
                error.message.isNotEmpty
            ? error.message
            : fallbackMessage;
    }
    notifyListeners();
    return false;
  }

  void cancelUpload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User cancelled upload');
    }
    _status = UgcUploadStatus.cancelled;
    _uploadProgress = 0.0;
    _errorMessage = 'అప్‌లోడ్ రద్దు చేయబడింది.';
    notifyListeners();
  }

  void _onSendProgress(int sent, int total) {
    if (total > 0) {
      _uploadProgress = sent / total;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}
