import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/admin_push_notification_payload.dart';
import '../../data/models/admin_ugc_submission_model.dart';
import '../../data/repositories/admin_ugc_repository.dart';
import 'admin_load_status.dart';

class AdminUgcDetailController extends ChangeNotifier {
  final AdminUgcRepository _repository = AdminUgcRepository();

  AdminUgcSubmissionModel submission;
  AdminLoadStatus status = AdminLoadStatus.loaded;
  String? errorMessage;

  final ValueNotifier<double> uploadProgress = ValueNotifier<double>(0);

  AdminUgcDetailController({required this.submission});

  Future<void> loadDetail() async {
    status = AdminLoadStatus.loading;
    notifyListeners();
    try {
      submission = await _repository.getSubmissionDetail(submission.id);
      status = AdminLoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = AdminLoadStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> approve({
    required String notes,
    required String publicationLevel,
    AdminPushNotificationPayload? push,
  }) async {
    submission = await _repository.approveSubmission(submission.id, notes: notes, publicationLevel: publicationLevel, push: push);
    notifyListeners();
  }

  Future<void> reject({required String notes}) async {
    submission = await _repository.rejectSubmission(submission.id, notes: notes);
    notifyListeners();
  }

  Future<void> flag() async {
    submission = await _repository.flagSubmission(submission.id);
    notifyListeners();
  }

  Future<void> increaseTrust() async {
    await _repository.increaseTrust(submission.id);
    submission = submission.copyWith(trustScore: (submission.trustScore + 10).clamp(0, 100));
    notifyListeners();
  }

  Future<void> decreaseTrust() async {
    await _repository.decreaseTrust(submission.id);
    submission = submission.copyWith(trustScore: (submission.trustScore - 10).clamp(0, 100));
    notifyListeners();
  }

  Future<void> blockUploader() async {
    await _repository.blockUploader(submission.id);
    submission = submission.copyWith(uploaderBlocked: true);
    notifyListeners();
  }

  Future<void> unblockUploader() async {
    await _repository.unblockUploader(submission.id);
    submission = submission.copyWith(uploaderBlocked: false);
    notifyListeners();
  }

  Future<void> patchMetadata(Map<String, dynamic> body) async {
    submission = await _repository.patchSubmission(submission.id, body);
    notifyListeners();
  }

  Future<void> uploadBrandedMedia({File? imageFile, File? videoFile, File? thumbnailFile, required String notes}) async {
    uploadProgress.value = 0;
    submission = await _repository.uploadBrandedMedia(
      submission.id,
      imageFile: imageFile,
      videoFile: videoFile,
      thumbnailFile: thumbnailFile,
      notes: notes,
      onSendProgress: (sent, total) {
        if (total > 0) uploadProgress.value = sent / total;
      },
    );
    notifyListeners();
  }

  @override
  void dispose() {
    uploadProgress.dispose();
    super.dispose();
  }
}
