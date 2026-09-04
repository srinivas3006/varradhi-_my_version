import 'admin_ugc_status.dart';
import 'admin_ugc_submission_model.dart';

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

class AdminReporterRecentSubmission {
  final String id;
  final String title;
  final AdminUgcStatus status;

  const AdminReporterRecentSubmission({required this.id, required this.title, required this.status});

  factory AdminReporterRecentSubmission.fromJson(Map<String, dynamic> json) {
    return AdminReporterRecentSubmission(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: AdminUgcStatusX.fromWire(json['status']?.toString()),
    );
  }
}

class AdminReporterProfileModel {
  final String? userId;
  final String name;
  final String email;
  final String mobile;
  final AdminTrustLevel trustLevel;
  final int trustScore;
  final int submissionsCount;
  final int dailyUploadsCount;
  final bool isBlocked;
  final List<AdminReporterRecentSubmission> recentSubmissions;

  const AdminReporterProfileModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.mobile,
    required this.trustLevel,
    required this.trustScore,
    required this.submissionsCount,
    required this.dailyUploadsCount,
    required this.isBlocked,
    required this.recentSubmissions,
  });

  String get status => isBlocked ? 'BLOCKED' : 'ACTIVE';

  factory AdminReporterProfileModel.fromJson(Map<String, dynamic> raw) {
    final json = raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : raw;
    final recent = (json['recent_submissions'] as List?) ?? const [];
    return AdminReporterProfileModel(
      userId: (json['id'] ?? json['user_id'])?.toString(),
      name: (json['name'] ?? json['full_name'] ?? json['username'])?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: (json['mobile'] ?? json['phone'])?.toString() ?? '',
      trustLevel: AdminTrustLevelX.fromWire(json['trust_level']?.toString()),
      trustScore: _asInt(json['trust_score'] ?? json['score'], 0),
      submissionsCount: _asInt(json['submissions_count'] ?? json['total_submissions'], 0),
      dailyUploadsCount: _asInt(json['daily_uploads_count'] ?? json['daily_uploads'], 0),
      isBlocked: (json['is_blocked'] ?? json['blocked']) == true,
      recentSubmissions: recent
          .whereType<Map>()
          .map((e) => AdminReporterRecentSubmission.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Local fallback used when GET /reporters/{userId}/ fails or userId is
  /// null — built purely from fields already present on a queue/detail item.
  factory AdminReporterProfileModel.fromSubmission(AdminUgcSubmissionModel item) {
    return AdminReporterProfileModel(
      userId: item.reporterUserId,
      name: item.reporterName,
      email: item.reporterEmail,
      mobile: item.reporterMobile,
      trustLevel: item.trustLevel,
      trustScore: item.trustScore,
      submissionsCount: 1,
      dailyUploadsCount: 0,
      isBlocked: item.uploaderBlocked,
      recentSubmissions: [
        AdminReporterRecentSubmission(id: item.id, title: item.title, status: item.status),
      ],
    );
  }

  AdminReporterProfileModel copyWith({int? trustScore, bool? isBlocked}) {
    return AdminReporterProfileModel(
      userId: userId,
      name: name,
      email: email,
      mobile: mobile,
      trustLevel: trustLevel,
      trustScore: trustScore ?? this.trustScore,
      submissionsCount: submissionsCount,
      dailyUploadsCount: dailyUploadsCount,
      isBlocked: isBlocked ?? this.isBlocked,
      recentSubmissions: recentSubmissions,
    );
  }
}
