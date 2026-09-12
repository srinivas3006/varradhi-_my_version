import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/media_picker_helper.dart';
import '../core/utils/media_validator.dart';
import '../models/reporter_post.dart';
import '../models/ugc_draft.dart';
import '../repositories/ugc_draft_repository.dart';
import '../repositories/ugc_repository.dart';
import '../services/location_service.dart';
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
  String? _submissionId;
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
  String? get submissionId => _submissionId;
  UgcDraft? get pendingDraft => _pendingDraft;
  List<String> get missingFilesWarning => List.unmodifiable(_missingFilesWarning);

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
        _errorMessage = 'Maximum ${MediaValidator.maxMediaItems} photos are allowed.';
      }
      notifyListeners();
      _autoSaveDraft();
    }
  }

  Future<void> pickPhotosFromGallery() async {
    final remainingSlots = MediaValidator.maxMediaItems - _selectedImagePaths.length;
    if (remainingSlots <= 0) {
      _errorMessage = 'Maximum ${MediaValidator.maxMediaItems} photos reached.';
      notifyListeners();
      return;
    }

    final xFiles = await _pickerHelper.pickPhotosFromGallery(maxItems: remainingSlots);
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
    _type = draft.type.toUpperCase() == 'VIDEO' ? PostType.video : PostType.image;
    _submissionId = draft.submissionId;

    // Validate local files
    final missing = await draft.findMissingFiles();
    _missingFilesWarning = missing;

    if (_type == PostType.image) {
      _selectedImagePaths = draft.filePaths.where((p) => !missing.contains(p)).toList();
      _selectedVideoPath = null;
    } else {
      if (draft.filePaths.isNotEmpty && !missing.contains(draft.filePaths.first)) {
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
      mobile: AppState.instance.userPhone,
    );
    _draftRepository.saveDraft(draft);
  }

  // --- Location Requirement ---

  Future<bool> ensureLocationAvailable() async {
    if (AppState.instance.latitude != null && AppState.instance.longitude != null) {
      return true;
    }
    try {
      final loc = await LocationService.detectLocation();
      AppState.instance.setDeviceLocation(loc);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'దయచేసి మీ ప్రాంత వివరాలను (Location) ఎంచుకోండి / GPS ఆన్ చేయండి.';
      notifyListeners();
      return false;
    }
  }

  // --- Submission & Upload Pipeline ---

  /// Primary action called when the user taps Submit or Retry.
  Future<bool> submitNews() async {
    if (isSubmittingOrUploading) return false;

    // 1. Form Validation
    if (_title.trim().isEmpty) {
      _errorMessage = 'దయచేసి వార్త శీర్షికను (Title) నమోదు చేయండి.';
      notifyListeners();
      return false;
    }
    if (_description.trim().isEmpty) {
      _errorMessage = 'దయచేసి వార్త పూర్తి వివరాలను (Description) నమోదు చేయండి.';
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
      final validation = await MediaValidator.validateImagesBatch(_selectedImagePaths);
      if (!validation.isValid) {
        _status = UgcUploadStatus.failed;
        _errorMessage = validation.errorMessage;
        notifyListeners();
        return false;
      }
    } else {
      final validation = await MediaValidator.validateVideo(_selectedVideoPath!);
      if (!validation.isValid) {
        _status = UgcUploadStatus.failed;
        _errorMessage = validation.errorMessage;
        notifyListeners();
        return false;
      }
    }

    // 3. Location Verification (Prevent fake coordinates)
    final hasLoc = await ensureLocationAvailable();
    if (!hasLoc) {
      _status = UgcUploadStatus.failed;
      notifyListeners();
      return false;
    }

    final mobile = AppState.instance.userPhone.isNotEmpty
        ? AppState.instance.userPhone
        : '9876543210';
    final contentType = _type == PostType.image ? 'IMAGE' : 'VIDEO';

    // 4. Submission creation (POST /api/v1/ugc/submit/) if submissionId doesn't exist
    if (_submissionId == null || _submissionId!.isEmpty) {
      _status = UgcUploadStatus.submitting;
      notifyListeners();

      try {
        final submissionPayload = {
          'mobile': mobile,
          'title': _title.trim(),
          'description': _description.trim(),
          'category': _category.toLowerCase(),
          'content_type': contentType,
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
        _submissionId = (response['submission_id'] ?? response['id'])?.toString();
        _autoSaveDraft();
      } catch (e) {
        _status = UgcUploadStatus.failed;
        _errorMessage = e is AppException ? e.message : 'వార్తను సమర్పించడం విఫలమైంది: $e';
        notifyListeners();
        return false;
      }
    }

    // If server created submission, proceed to media upload
    if (_submissionId == null || _submissionId!.isEmpty) {
      _status = UgcUploadStatus.failed;
      _errorMessage = 'సర్వర్ నుండి రిఫరెన్స్ ఐడీ రాలేదు. దయచేసి మళ్ళీ ప్రయత్నించండి.';
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
              mediaType: 'IMAGE',
              filePath: _selectedImagePaths.first,
              onSendProgress: _onSendProgress,
              cancelToken: _cancelToken,
            );
          } else {
            await _ugcRepository.uploadMediaBatch(
              submissionId: _submissionId!,
              mobile: mobile,
              filePaths: _selectedImagePaths,
              mediaTypes: List.filled(_selectedImagePaths.length, 'IMAGE'),
              onSendProgress: _onSendProgress,
              cancelToken: _cancelToken,
            );
          }
        } else {
          await _ugcRepository.uploadMedia(
            submissionId: _submissionId!,
            mobile: mobile,
            mediaType: 'VIDEO',
            filePath: _selectedVideoPath!,
            onSendProgress: _onSendProgress,
            cancelToken: _cancelToken,
          );
        }
        uploadSuccess = true;
      } on DioException catch (dioErr) {
        if (CancelToken.isCancel(dioErr)) {
          _status = UgcUploadStatus.cancelled;
          _errorMessage = 'అప్‌లోడ్ రద్దు చేయబడింది.';
          notifyListeners();
          return false;
        }

        final statusCode = dioErr.response?.statusCode;
        // Do NOT retry 4xx client errors (validation, auth rejection, etc.)
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          _status = UgcUploadStatus.failed;
          _errorMessage = dioErr.response?.data?['errors']?['message']?.toString() ??
              'మీడియా అప్‌లోడ్ చెల్లుబాటు కాలేదు ($statusCode).';
          notifyListeners();
          return false;
        }

        // Bounded retry for transient 5xx or connection issues
        retryCount++;
        if (retryCount > maxRetries) {
          _status = UgcUploadStatus.failed;
          _errorMessage = 'నెట్‌వర్క్ సమస్య కారణంగా మీడియా అప్‌లోడ్ విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.';
          notifyListeners();
          return false;
        }
        await Future.delayed(Duration(seconds: retryCount));
      } catch (e) {
        retryCount++;
        if (retryCount > maxRetries) {
          _status = UgcUploadStatus.failed;
          _errorMessage = e is AppException ? e.message : 'మీడియా అప్‌లోడ్ విఫలమైంది.';
          notifyListeners();
          return false;
        }
        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    // 6. Success handling
    _status = UgcUploadStatus.completed;
    _uploadProgress = 1.0;

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
