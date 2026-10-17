import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/log_safe.dart';
import '../../../../utils/share_service.dart';
import '../models/admin_ugc_submission_model.dart';

/// Result of saving a submission's media to the phone.
class AdminDownloadResult {
  final int saved;
  final int failed;
  final bool permissionDenied;

  const AdminDownloadResult(
      {required this.saved, required this.failed, this.permissionDenied = false});
}

/// Admin tools for a citizen submission's media: save the reporter's
/// originals to the gallery, and make a Vaaradhi-branded copy of a photo
/// (the same sticker the reader share uses) ready for branded-media upload.
class AdminMediaTools {
  AdminMediaTools({Dio? dio, Future<Directory> Function()? tempDir})
      // A plain client: media sits on the public CDN, so no API token is
      // sent with it.
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 3),
            )),
        _tempDir = tempDir ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _tempDir;

  /// Saving to the gallery; replaceable in tests.
  @visibleForTesting
  static Future<int> Function(String path, {bool isVideo}) saveToGallery =
      ShareService.saveFileToGallery;

  /// Branding a photo; replaceable in tests.
  @visibleForTesting
  static Future<File?> Function(Uint8List bytes, String name) brand =
      ShareService.brandPhotoBytes;

  static String _extension(AdminMediaItem m) {
    final path = Uri.tryParse(m.url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    final ext = dot >= 0 ? path.substring(dot).toLowerCase() : '';
    if (ext.length > 1 && ext.length <= 5) return ext;
    return m.isVideo ? '.mp4' : '.jpg';
  }

  Future<File> _fetch(AdminMediaItem m, String name) async {
    final dir = await _tempDir();
    final file = File('${dir.path}/$name${_extension(m)}');
    await _dio.download(m.url, file.path);
    return file;
  }

  /// Saves every photo and video of [s] to the gallery (album "Vaaradhi").
  Future<AdminDownloadResult> downloadAll(AdminUgcSubmissionModel s,
      {void Function(int done, int total)? onProgress}) async {
    final media = s.allMedia;
    var saved = 0;
    var failed = 0;
    for (var i = 0; i < media.length; i++) {
      final m = media[i];
      try {
        final file = await _fetch(m, 'vaaradhi_ugc_${_safe(s.id)}_${i + 1}');
        final code = await saveToGallery(file.path, isVideo: m.isVideo);
        if (code == ShareService.downloadPermissionDenied) {
          return AdminDownloadResult(
              saved: saved, failed: media.length - saved, permissionDenied: true);
        }
        code == ShareService.downloadSaved ? saved++ : failed++;
      } catch (e) {
        debugPrint('[AdminMedia] download failed: ${LogSafe.scrub(e)}');
        failed++;
      }
      onProgress?.call(i + 1, media.length);
    }
    return AdminDownloadResult(saved: saved, failed: failed);
  }

  /// A branded copy of the submission's first photo, or null when it has no
  /// photo or the photo cannot be read. Videos are branded on the backend /
  /// by hand and uploaded through the branded-media sheet.
  Future<File?> brandFirstPhoto(AdminUgcSubmissionModel s) async {
    final photo = s.firstImage;
    if (photo == null) return null;
    try {
      final response = await _dio.get<List<int>>(photo.url,
          options: Options(responseType: ResponseType.bytes));
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      return await brand(
          Uint8List.fromList(bytes), 'vaaradhi_branded_${_safe(s.id)}');
    } catch (e) {
      debugPrint('[AdminMedia] branding failed: ${LogSafe.scrub(e)}');
      return null;
    }
  }

  static String _safe(String id) =>
      id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}
