Map<String, dynamic>? _asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

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
    final target = _asMap(json['target']) ?? _asMap(json['submission']);
    return AdminReportModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      reason: json['reason']?.toString() ?? '',
      targetSubmissionId: (target?['id'] ?? json['submission_id'] ?? json['target_id'])?.toString() ?? '',
      targetSubmissionTitle: (target?['title'] ?? json['submission_title'] ?? json['target_title'])?.toString() ?? '',
      reporterNote: (json['note'] ?? json['reporter_note'])?.toString() ?? '',
      reporterEmail: (json['reporter_email'] ?? json['email'])?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
