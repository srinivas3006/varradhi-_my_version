Map<String, dynamic>? _asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

/// Which report queue: citizen posts (`/admin/api/ugc/reports/`) or desk
/// articles (`/admin/api/articles/reports/`). They are separate backend
/// queues; ids and actions must never cross between them.
enum AdminReportSource { citizen, desk }

class AdminReportModel {
  final String id;
  final String status;
  final String reason;
  final String targetSubmissionId;
  final String targetSubmissionTitle;
  final String reporterNote;
  final String reporterEmail;
  final DateTime createdAt;

  const AdminReportModel({
    required this.id,
    required this.status,
    required this.reason,
    required this.targetSubmissionId,
    required this.targetSubmissionTitle,
    required this.reporterNote,
    required this.reporterEmail,
    required this.createdAt,
  });

  String get reasonLabel => reason.replaceAll('_', ' ');

  factory AdminReportModel.fromJson(Map<String, dynamic> json) {
    final target = _asMap(json['target']) ??
        _asMap(json['submission']) ??
        _asMap(json['article']);
    return AdminReportModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      reason: json['reason']?.toString() ?? '',
      targetSubmissionId: (target?['id'] ??
                  json['submission_id'] ??
                  json['article_id'] ??
                  json['target_id'])
              ?.toString() ??
          '',
      targetSubmissionTitle: (target?['title'] ??
                  json['submission_title'] ??
                  json['article_title'] ??
                  json['target_title'])
              ?.toString() ??
          '',
      reporterNote:
          (json['notes'] ?? json['note'] ?? json['reporter_note'])?.toString() ?? '',
      reporterEmail: (json['reporter_email'] ?? json['email'])?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
