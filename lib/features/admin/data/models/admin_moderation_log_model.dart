class AdminModerationLogModel {
  final String id;
  final String action;
  final String submissionId;
  final String submissionTitle;
  final String oldStatus;
  final String newStatus;
  final String notes;
  final String adminEmail;
  final DateTime createdAt;

  const AdminModerationLogModel({
    required this.id,
    required this.action,
    required this.submissionId,
    required this.submissionTitle,
    required this.oldStatus,
    required this.newStatus,
    required this.notes,
    required this.adminEmail,
    required this.createdAt,
  });

  factory AdminModerationLogModel.fromJson(Map<String, dynamic> json) {
    return AdminModerationLogModel(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString().toUpperCase() ?? '',
      submissionId: (json['submission_id'] ?? json['submission'])?.toString() ?? '',
      submissionTitle: (json['submission_title'] ?? json['title'])?.toString() ?? '',
      oldStatus: (json['old_status'] ?? json['from_status'])?.toString() ?? '',
      newStatus: (json['new_status'] ?? json['to_status'])?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      adminEmail: (json['admin_email'] ?? json['admin'])?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
