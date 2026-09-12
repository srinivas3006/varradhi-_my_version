import 'dart:io';

/// Result of validating a media file for UGC submission.
class MediaValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int? fileSizeBytes;
  final String? extension;

  const MediaValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.fileSizeBytes,
    this.extension,
  });

  factory MediaValidationResult.valid({
    required int fileSizeBytes,
    required String extension,
  }) {
    return MediaValidationResult._(
      isValid: true,
      fileSizeBytes: fileSizeBytes,
      extension: extension,
    );
  }

  factory MediaValidationResult.invalid(String message) {
    return MediaValidationResult._(
      isValid: false,
      errorMessage: message,
    );
  }
}

/// Production validator enforcing backend media constraints for UGC.
///
/// Backend configuration constraints verified:
/// - MAX_IMAGE_MB: 10
/// - MAX_VIDEO_MB: 50
/// - UGC_MAX_MEDIA_ITEMS: 10
class MediaValidator {
  static const int maxImageBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxVideoBytes = 50 * 1024 * 1024; // 50 MB
  static const int maxMediaItems = 10;

  static const Set<String> allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const Set<String> allowedVideoExtensions = {
    'mp4',
    'mov',
    'mkv',
  };

  /// Validates a single image file on disk.
  static Future<MediaValidationResult> validateImage(String filePath) async {
    return _validateFile(
      filePath: filePath,
      maxSizeBytes: maxImageBytes,
      maxMbLabel: '10 MB',
      allowedExtensions: allowedImageExtensions,
      mediaLabel: 'Image',
    );
  }

  /// Validates a single video file on disk.
  static Future<MediaValidationResult> validateVideo(String filePath) async {
    return _validateFile(
      filePath: filePath,
      maxSizeBytes: maxVideoBytes,
      maxMbLabel: '50 MB',
      allowedExtensions: allowedVideoExtensions,
      mediaLabel: 'Video',
    );
  }

  /// Validates a batch of image files.
  static Future<MediaValidationResult> validateImagesBatch(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      return MediaValidationResult.invalid('Please attach at least one photo.');
    }
    if (filePaths.length > maxMediaItems) {
      return MediaValidationResult.invalid('Maximum $maxMediaItems photos are allowed per report.');
    }

    for (int i = 0; i < filePaths.length; i++) {
      final res = await validateImage(filePaths[i]);
      if (!res.isValid) {
        return MediaValidationResult.invalid('Photo ${i + 1}: ${res.errorMessage}');
      }
    }

    return MediaValidationResult.valid(
      fileSizeBytes: 0,
      extension: 'batch',
    );
  }

  static Future<MediaValidationResult> _validateFile({
    required String filePath,
    required int maxSizeBytes,
    required String maxMbLabel,
    required Set<String> allowedExtensions,
    required String mediaLabel,
  }) async {
    if (filePath.trim().isEmpty) {
      return MediaValidationResult.invalid('$mediaLabel file path is empty.');
    }

    final file = File(filePath);
    final exists = await file.exists();
    if (!exists) {
      return MediaValidationResult.invalid('$mediaLabel file does not exist or has been removed.');
    }

    // Extract extension safely
    final extIndex = filePath.lastIndexOf('.');
    if (extIndex == -1 || extIndex == filePath.length - 1) {
      return MediaValidationResult.invalid('$mediaLabel has an unknown or missing file extension.');
    }
    final extension = filePath.substring(extIndex + 1).toLowerCase();

    if (!allowedExtensions.contains(extension)) {
      final allowedStr = allowedExtensions.map((e) => '.$e').join(', ');
      return MediaValidationResult.invalid(
        'Unsupported $mediaLabel format (.$extension). Allowed formats: $allowedStr.',
      );
    }

    int length = 0;
    try {
      length = await file.length();
    } catch (_) {
      return MediaValidationResult.invalid('$mediaLabel file could not be read.');
    }

    if (length == 0) {
      return MediaValidationResult.invalid('$mediaLabel file is empty (0 bytes).');
    }

    if (length > maxSizeBytes) {
      final sizeMb = (length / (1024 * 1024)).toStringAsFixed(1);
      return MediaValidationResult.invalid(
        '$mediaLabel is too large (${sizeMb}MB). Maximum allowed size is $maxMbLabel.',
      );
    }

    return MediaValidationResult.valid(
      fileSizeBytes: length,
      extension: extension,
    );
  }
}
