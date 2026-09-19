class AccountDeletionRequest {
  final String id;
  final String status;
  final String reason;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final DateTime? executedAt;
  final String? userEmail;
  final String? adminNotes;

  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.reason,
    this.notes,
    this.createdAt,
    this.reviewedAt,
    this.executedAt,
    this.userEmail,
    this.adminNotes,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return AccountDeletionRequest(
      id: json['id']?.toString() ?? '',
      status: (json['status']?.toString() ?? 'pending').toLowerCase().trim(),
      reason: json['reason']?.toString() ?? 'other',
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['created_at']),
      reviewedAt: parseDate(json['reviewed_at']),
      executedAt: parseDate(json['executed_at']),
      userEmail: json['user_email']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'reason': reason,
        if (notes != null) 'notes': notes,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
        if (executedAt != null) 'executed_at': executedAt!.toIso8601String(),
      };

  static const List<DeletionReasonOption> reasonOptions = [
    DeletionReasonOption(
      code: 'privacy',
      titleEn: 'Privacy concerns / Remove my data',
      titleTe: 'వ్యక్తిగత గోప్యత / నా డేటా తొలగించండి',
    ),
    DeletionReasonOption(
      code: 'no_longer_used',
      titleEn: 'I no longer use or need the app',
      titleTe: 'నేను ఇకపై యాప్ ఉపయోగించడం లేదు',
    ),
    DeletionReasonOption(
      code: 'too_many_notifications',
      titleEn: 'Too many notifications',
      titleTe: 'నోటిఫికేషన్‌లు చాలా ఎక్కువగా వస్తున్నాయి',
    ),
    DeletionReasonOption(
      code: 'content_quality',
      titleEn: 'Content quality or relevance issues',
      titleTe: 'కంటెంట్ నాణ్యత లేదా సమస్యలు',
    ),
    DeletionReasonOption(
      code: 'another_account',
      titleEn: 'Created or using another account',
      titleTe: 'మరొక ఖాతా ఉపయోగిస్తున్నాను',
    ),
    DeletionReasonOption(
      code: 'other',
      titleEn: 'Other reason',
      titleTe: 'ఇతర కారణం',
    ),
  ];

  static String getReasonLabel(String code, {bool isTelugu = false}) {
    final option = reasonOptions.firstWhere(
      (opt) => opt.code == code,
      orElse: () => const DeletionReasonOption(
        code: 'other',
        titleEn: 'Other',
        titleTe: 'ఇతర కారణం',
      ),
    );
    return isTelugu ? option.titleTe : option.titleEn;
  }
}

class DeletionReasonOption {
  final String code;
  final String titleEn;
  final String titleTe;

  const DeletionReasonOption({
    required this.code,
    required this.titleEn,
    required this.titleTe,
  });
}
