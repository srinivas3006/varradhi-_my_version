import 'package:flutter/material.dart';
import '../../data/models/admin_reporter_profile_model.dart';
import '../../data/models/admin_ugc_submission_model.dart';
import '../../data/repositories/admin_ugc_repository.dart';
import 'admin_load_status.dart';

class AdminReporterProfileController extends ChangeNotifier {
  final AdminUgcRepository _repository = AdminUgcRepository();

  AdminReporterProfileModel? profile;
  AdminLoadStatus status = AdminLoadStatus.initial;

  /// Set when this sheet was opened from a specific submission — trust/
  /// block actions are keyed by submission id, not reporter user id.
  String? submissionId;

  Future<void> load({String? userId, AdminUgcSubmissionModel? fallbackFrom}) async {
    submissionId = fallbackFrom?.id;
    status = AdminLoadStatus.loading;
    notifyListeners();

    if (userId != null) {
      try {
        profile = await _repository.getReporterProfile(userId);
        status = AdminLoadStatus.loaded;
        notifyListeners();
        return;
      } catch (e) {
        // Deliberate: fall through to the local fallback below. Logged so a
        // profile silently built from the submission is traceable.
        debugPrint('[AdminReporterProfile] fetch failed, using fallback: $e');
      }
    }

    if (fallbackFrom != null) {
      profile = AdminReporterProfileModel.fromSubmission(fallbackFrom);
      status = AdminLoadStatus.loaded;
    } else {
      status = AdminLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> increaseTrust() async {
    if (submissionId == null || profile == null) return;
    await _repository.increaseTrust(submissionId!);
    profile = profile!.copyWith(trustScore: (profile!.trustScore + 10).clamp(0, 100));
    notifyListeners();
  }

  Future<void> decreaseTrust() async {
    if (submissionId == null || profile == null) return;
    await _repository.decreaseTrust(submissionId!);
    profile = profile!.copyWith(trustScore: (profile!.trustScore - 10).clamp(0, 100));
    notifyListeners();
  }

  Future<void> toggleBlock() async {
    if (submissionId == null || profile == null) return;
    if (profile!.isBlocked) {
      await _repository.unblockUploader(submissionId!);
    } else {
      await _repository.blockUploader(submissionId!);
    }
    profile = profile!.copyWith(isBlocked: !profile!.isBlocked);
    notifyListeners();
  }
}
