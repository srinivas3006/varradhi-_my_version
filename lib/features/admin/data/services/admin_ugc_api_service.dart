import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/admin_bulk_action_model.dart';
import '../models/admin_moderation_log_model.dart';
import '../models/admin_otp_delivery_model.dart';
import '../models/admin_paginated_response.dart';
import '../models/admin_push_notification_payload.dart';
import '../models/admin_report_model.dart';
import '../models/admin_reporter_profile_model.dart';
import '../models/admin_ugc_submission_model.dart';
import 'admin_api_endpoints.dart';

class AdminUgcApiService {
  final Dio _dio = CoreDioClient().dio;

  Future<AdminPaginatedResponse<AdminUgcSubmissionModel>> getQueue({
    String? cursor,
    int pageSize = 20,
    String? status,
    String? district,
    bool? duplicateFlagged,
    int? reportCountMin,
    String? createdAt,
  }) async {
    final response = await _dio.get(AdminApiEndpoints.queue, queryParameters: {
      'page_size': pageSize,
      if (cursor != null) 'cursor': cursor,
      if (status != null) 'status': status,
      if (district != null) 'district': district,
      if (duplicateFlagged != null) 'duplicate_flagged': duplicateFlagged,
      if (reportCountMin != null) 'report_count': reportCountMin,
      if (createdAt != null) 'created_at': createdAt,
    });
    return AdminPaginatedResponse<AdminUgcSubmissionModel>.fromJson(response.data, AdminUgcSubmissionModel.fromJson);
  }

  Future<AdminUgcSubmissionModel> getSubmissionDetail(String id) async {
    final response = await _dio.get(AdminApiEndpoints.submissionDetail(id));
    return AdminUgcSubmissionModel.fromJson(response.data);
  }

  Future<AdminUgcSubmissionModel> patchSubmission(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch(AdminApiEndpoints.submissionDetail(id), data: body);
    return AdminUgcSubmissionModel.fromJson(response.data);
  }

  Future<AdminUgcSubmissionModel> uploadBrandedMedia(
    String id, {
    File? imageFile,
    File? videoFile,
    File? thumbnailFile,
    required String notes,
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'notes': notes,
      if (imageFile != null) 'image': await MultipartFile.fromFile(imageFile.path),
      if (videoFile != null) 'video': await MultipartFile.fromFile(videoFile.path),
      if (thumbnailFile != null) 'thumbnail': await MultipartFile.fromFile(thumbnailFile.path),
    });
    final response = await _dio.post(
      AdminApiEndpoints.brandedMedia(id),
      data: formData,
      onSendProgress: onSendProgress,
    );
    return AdminUgcSubmissionModel.fromJson(response.data);
  }

  Future<AdminUgcSubmissionModel> approveSubmission(
    String id, {
    required String notes,
    required String publicationLevel,
    AdminPushNotificationPayload? push,
  }) async {
    final response = await _dio.post(AdminApiEndpoints.approve(id), data: {
      'notes': notes,
      'publication_level': publicationLevel,
      if (push != null) 'push_notification': push.toJson(),
    });
    return AdminUgcSubmissionModel.fromJson(response.data);
  }

  Future<AdminUgcSubmissionModel> rejectSubmission(String id, {required String notes}) async {
    final response = await _dio.post(AdminApiEndpoints.reject(id), data: {'notes': notes});
    return AdminUgcSubmissionModel.fromJson(response.data);
  }

  Future<AdminUgcSubmissionModel> flagSubmission(String id, {String? notes}) async {
    final response = await _dio.post(AdminApiEndpoints.flag(id), data: {
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return AdminUgcSubmissionModel.fromJson(response.data);
  }

  Future<AdminBulkActionResult> bulkAction(AdminBulkActionRequest req) async {
    final response = await _dio.post(AdminApiEndpoints.bulkAction, data: req.toJson());
    return AdminBulkActionResult.fromJson(response.data, req.ids.length);
  }

  Future<void> blockUploader(String submissionId, {String? reason}) async {
    await _dio.post(AdminApiEndpoints.blockUploader(submissionId), data: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> unblockUploader(String submissionId) async {
    await _dio.post(AdminApiEndpoints.unblockUploader(submissionId));
  }

  Future<void> increaseTrust(String submissionId) async {
    await _dio.post(AdminApiEndpoints.increaseTrust(submissionId));
  }

  Future<void> decreaseTrust(String submissionId) async {
    await _dio.post(AdminApiEndpoints.decreaseTrust(submissionId));
  }

  Future<AdminPaginatedResponse<AdminModerationLogModel>> getModerationLogs({
    String? cursor,
    int pageSize = 20,
    String? action,
    String? search,
  }) async {
    final response = await _dio.get(AdminApiEndpoints.moderationLogs, queryParameters: {
      'page_size': pageSize,
      if (cursor != null) 'cursor': cursor,
      if (action != null) 'action': action,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return AdminPaginatedResponse<AdminModerationLogModel>.fromJson(response.data, AdminModerationLogModel.fromJson);
  }

  Future<AdminPaginatedResponse<AdminReportModel>> getReports({
    String? cursor,
    int pageSize = 20,
    String? status,
  }) async {
    final response = await _dio.get(AdminApiEndpoints.reports, queryParameters: {
      'page_size': pageSize,
      if (cursor != null) 'cursor': cursor,
      if (status != null) 'status': status,
    });
    return AdminPaginatedResponse<AdminReportModel>.fromJson(response.data, AdminReportModel.fromJson);
  }

  Future<void> reviewReport(String id) async {
    await _dio.post(AdminApiEndpoints.reviewReport(id));
  }

  Future<void> dismissReport(String id) async {
    await _dio.post(AdminApiEndpoints.dismissReport(id));
  }

  Future<AdminReporterProfileModel> getReporterProfile(String userId) async {
    final response = await _dio.get(AdminApiEndpoints.reporterDetail(userId));
    return AdminReporterProfileModel.fromJson(response.data);
  }

  Future<AdminPaginatedResponse<AdminOtpDeliveryModel>> getOtpDeliveries({
    String? cursor,
    int pageSize = 20,
    String? status,
    String? mobile,
  }) async {
    final response = await _dio.get(AdminApiEndpoints.otpDeliveries, queryParameters: {
      'page_size': pageSize,
      if (cursor != null) 'cursor': cursor,
      if (status != null) 'status': status,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
    });
    return AdminPaginatedResponse<AdminOtpDeliveryModel>.fromJson(response.data, AdminOtpDeliveryModel.fromJson);
  }
}
