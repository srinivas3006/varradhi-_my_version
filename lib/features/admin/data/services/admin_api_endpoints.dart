/// Admin UGC moderation endpoint paths. Kept feature-scoped (not merged
/// into core/config/api_endpoints.dart) since these are irregular relative
/// to the rest of the app's /api/v1/ convention — most live under
/// /admin/api/ugc/, except brandedMedia which lives under /api/v1/.
class AdminApiEndpoints {
  AdminApiEndpoints._();

  static const String queue = '/admin/api/ugc/queue/';
  static String submissionDetail(String id) => '/admin/api/ugc/submissions/$id/';
  static String brandedMedia(String id) => '/api/v1/ugc/admin/submissions/$id/branded-media/';
  static String approve(String id) => '/admin/api/ugc/submissions/$id/approve/';
  static String reject(String id) => '/admin/api/ugc/submissions/$id/reject/';
  static String flag(String id) => '/admin/api/ugc/submissions/$id/flag/';
  static const String bulkAction = '/admin/api/ugc/submissions/bulk-action/';
  static String blockUploader(String id) => '/admin/api/ugc/submissions/$id/block-uploader/';
  static String unblockUploader(String id) => '/admin/api/ugc/submissions/$id/unblock-uploader/';
  static String increaseTrust(String id) => '/admin/api/ugc/submissions/$id/increase-trust/';
  static String decreaseTrust(String id) => '/admin/api/ugc/submissions/$id/decrease-trust/';
  static const String moderationLogs = '/admin/api/ugc/moderation-logs/';
  static const String reports = '/admin/api/ugc/reports/';
  static String reviewReport(String id) => '/admin/api/ugc/reports/$id/review/';
  static String dismissReport(String id) => '/admin/api/ugc/reports/$id/dismiss/';
  static String reporterDetail(String userId) => '/admin/api/ugc/reporters/$userId/';
  static const String otpDeliveries = '/admin/api/ugc/otp-deliveries/';
}
