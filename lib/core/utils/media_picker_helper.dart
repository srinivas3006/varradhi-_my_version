import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Helper wrapping [ImagePicker] with safe error handling,
/// off-UI compression limits, and clean camera/gallery abstraction.
class MediaPickerHelper {
  final ImagePicker _picker;

  MediaPickerHelper({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Captures a photo using the device camera with native dimension and quality constraints.
  Future<XFile?> pickPhotoFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      debugPrint('[MediaPickerHelper] Camera photo error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[MediaPickerHelper] Unexpected error picking photo from camera: $e');
      return null;
    }
  }

  /// Picks a single photo from the gallery.
  Future<XFile?> pickPhotoFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      debugPrint('[MediaPickerHelper] Gallery photo error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[MediaPickerHelper] Unexpected error picking photo from gallery: $e');
      return null;
    }
  }

  /// Picks multiple photos from the gallery (capped at [maxItems], default 10).
  Future<List<XFile>> pickPhotosFromGallery({int maxItems = 10}) async {
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        limit: maxItems,
      );
      if (picked.length > maxItems) {
        return picked.sublist(0, maxItems);
      }
      return picked;
    } on PlatformException catch (e) {
      debugPrint('[MediaPickerHelper] Gallery multi-image error: ${e.code} - ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[MediaPickerHelper] Unexpected error picking multi-images: $e');
      return [];
    }
  }

  /// Records a video using the device camera with an optional maximum duration.
  Future<XFile?> recordVideoFromCamera({Duration maxDuration = const Duration(minutes: 3)}) async {
    try {
      return await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
      );
    } on PlatformException catch (e) {
      debugPrint('[MediaPickerHelper] Camera video error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[MediaPickerHelper] Unexpected error recording video: $e');
      return null;
    }
  }

  /// Picks a video from the gallery.
  Future<XFile?> pickVideoFromGallery() async {
    try {
      return await _picker.pickVideo(
        source: ImageSource.gallery,
      );
    } on PlatformException catch (e) {
      debugPrint('[MediaPickerHelper] Gallery video error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[MediaPickerHelper] Unexpected error picking video: $e');
      return null;
    }
  }
}
