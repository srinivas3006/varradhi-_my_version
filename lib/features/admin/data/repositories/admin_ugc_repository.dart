import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/errors/app_exception.dart';
import '../models/admin_bulk_action_model.dart';
import '../models/admin_moderation_log_model.dart';
import '../models/admin_otp_delivery_model.dart';
import '../models/admin_paginated_response.dart';
import '../models/admin_push_notification_payload.dart';
import '../models/admin_report_model.dart';
import '../models/admin_reporter_profile_model.dart';
import '../models/admin_ugc_submission_model.dart';
import '../services/admin_ugc_api_service.dart';

class AdminUgcRepository {
  final AdminUgcApiService _api = AdminUgcApiService();

  Future<T> _guard<T>(Future<T> Function() call, String fallbackMessage) async {
    try {
      return await call();
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(fallbackMessage);
    }
  }

  Future<AdminPaginatedResponse<AdminUgcSubmissionModel>> getQueue({
    String? cursor,
    int pageSize = 20,
    String? status,
    String? district,
    bool? duplicateFlagged,
    int? reportCountMin,
    String? createdAt,
  }) =>
      _guard(
        () => _api.getQueue(
          cursor: cursor,
          pageSize: pageSize,
          status: status,
          district: district,
          duplicateFlagged: duplicateFlagged,
          reportCountMin: reportCountMin,
          createdAt: createdAt,
        ),
        'Unable to load the moderation queue',
      );

  Future<AdminUgcSubmissionModel> getSubmissionDetail(String id) =>
      _guard(() => _api.getSubmissionDetail(id), 'Unable to load submission detail');

  Future<AdminUgcSubmissionModel> patchSubmission(String id, Map<String, dynamic> body) =>
      _guard(() => _api.patchSubmission(id, body), 'Unable to save changes');

  Future<AdminUgcSubmissionModel> uploadBrandedMedia(
    String id, {
    File? imageFile,
    File? videoFile,
    File? thumbnailFile,
    required String notes,
    ProgressCallback? onSendProgress,
  }) =>
      _guard(
        () => _api.uploadBrandedMedia(
          id,
          imageFile: imageFile,
          videoFile: videoFile,
          thumbnailFile: thumbnailFile,
          notes: notes,
          onSendProgress: onSendProgress,
        ),
        'Unable to upload branded media',
      );

  Future<AdminUgcSubmissionModel> approveSubmission(
    String id, {
    required String notes,
    required String publicationLevel,
    AdminPushNotificationPayload? push,
  }) =>
      _guard(
        () => _api.approveSubmission(id, notes: notes, publicationLevel: publicationLevel, push: push),
        'Unable to approve submission',
      );

  Future<AdminUgcSubmissionModel> rejectSubmission(String id, {required String notes}) =>
      _guard(() => _api.rejectSubmission(id, notes: notes), 'Unable to reject submission');

  Future<AdminUgcSubmissionModel> flagSubmission(String id, {String? notes}) =>
      _guard(() => _api.flagSubmission(id, notes: notes), 'Unable to flag submission');

  Future<AdminBulkActionResult> bulkAction(AdminBulkActionRequest req) =>
      _guard(() => _api.bulkAction(req), 'Unable to complete bulk action');

  Future<void> blockUploader(String submissionId, {String? reason}) =>
      _guard(() => _api.blockUploader(submissionId, reason: reason), 'Unable to block uploader');

  Future<void> unblockUploader(String submissionId) =>
      _guard(() => _api.unblockUploader(submissionId), 'Unable to unblock uploader');

  Future<void> increaseTrust(String submissionId) =>
      _guard(() => _api.increaseTrust(submissionId), 'Unable to update trust score');

  Future<void> decreaseTrust(String submissionId) =>
      _guard(() => _api.decreaseTrust(submissionId), 'Unable to update trust score');

  Future<AdminPaginatedResponse<AdminModerationLogModel>> getModerationLogs({
    String? cursor,
    int pageSize = 20,
    String? action,
    String? search,
  }) =>
      _guard(
        () => _api.getModerationLogs(cursor: cursor, pageSize: pageSize, action: action, search: search),
        'Unable to load moderation logs',
      );

  Future<AdminPaginatedResponse<AdminReportModel>> getReports({
    String? cursor,
    int pageSize = 20,
    String? status,
  }) =>
      _guard(() => _api.getReports(cursor: cursor, pageSize: pageSize, status: status), 'Unable to load reports');

  Future<void> reviewReport(String id) => _guard(() => _api.reviewReport(id), 'Unable to review report');

  Future<void> dismissReport(String id) => _guard(() => _api.dismissReport(id), 'Unable to dismiss report');

  Future<AdminReporterProfileModel> getReporterProfile(String userId) =>
      _guard(() => _api.getReporterProfile(userId), 'Unable to load reporter profile');

  Future<AdminPaginatedResponse<AdminOtpDeliveryModel>> getOtpDeliveries({
    String? cursor,
    int pageSize = 20,
    String? status,
    String? mobile,
  }) =>
      _guard(
        () => _api.getOtpDeliveries(cursor: cursor, pageSize: pageSize, status: status, mobile: mobile),
        'Unable to load OTP deliveries',
      );
}
