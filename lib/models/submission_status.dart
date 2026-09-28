/// `GET /api/v1/ugc/reporter/submissions/{id}/status/` (handover §10).
///
/// The backend decides the workflow; the app renders these fields and never
/// invents transitions of its own.
class SubmissionStatus {
  const SubmissionStatus({
    required this.id,
    required this.title,
    required this.reporterStatus,
    required this.nextAction,
    required this.uploadStatus,
    required this.canUploadMedia,
    required this.canResubmit,
    required this.reviewNote,
    required this.timeline,
    required this.thumbnailUrl,
    required this.contentType,
  });

  final String id;
  final String title;

  /// `pending`, `published` or `rejected`.
  final String reporterStatus;

  /// `view_in_feed`, `create_new_submission`, `upload_failed_retry_media`,
  /// `wait_media_processing`, `wait_editor_review` or `none`.
  final String nextAction;

  /// e.g. `PENDING`, `PROCESSING`, `READY`, `FAILED`.
  final String uploadStatus;
  final bool canUploadMedia;
  final bool canResubmit;
  final String reviewNote;
  final List<TimelineEntry> timeline;
  final String thumbnailUrl;

  /// `TEXT`, `IMAGE` or `VIDEO`.
  final String contentType;

  static const viewInFeed = 'view_in_feed';
  static const createNew = 'create_new_submission';
  static const retryMedia = 'upload_failed_retry_media';
  static const waitMedia = 'wait_media_processing';
  static const waitReview = 'wait_editor_review';

  /// Media is still being processed: keep polling.
  bool get isProcessing {
    if (nextAction == waitMedia) return true;
    final u = uploadStatus.toUpperCase();
    return u == 'PENDING' || u == 'PROCESSING' || u == 'UPLOADING';
  }

  static SubmissionStatus parse(dynamic body) {
    final data = body is Map && body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : (body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{});

    String str(Object? v) => v?.toString() ?? '';
    final rawTimeline = data['moderation_timeline'];

    return SubmissionStatus(
      id: str(data['id'] ?? data['submission_id']),
      title: str(data['title']),
      reporterStatus: str(data['reporter_status']).toLowerCase(),
      nextAction: str(data['next_action']).toLowerCase(),
      uploadStatus: str(data['upload_status']).toUpperCase(),
      canUploadMedia: data['can_upload_media'] == true,
      canResubmit: data['can_resubmit'] == true,
      reviewNote: str(data['review_note']).trim(),
      timeline: rawTimeline is List
          ? rawTimeline
              .whereType<Map>()
              .map((m) => TimelineEntry.parse(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      thumbnailUrl: str(data['thumbnail_url'] ?? data['media_url']),
      contentType: str(data['content_type']).toUpperCase(),
    );
  }
}

class TimelineEntry {
  const TimelineEntry({
    required this.status,
    required this.note,
    required this.at,
  });

  final String status;
  final String note;
  final DateTime? at;

  static TimelineEntry parse(Map<String, dynamic> m) => TimelineEntry(
        status: (m['status'] ?? m['to_status'] ?? m['action'] ?? m['event'])
                ?.toString() ??
            '',
        note: (m['notes'] ?? m['note'] ?? m['message'])?.toString() ?? '',
        at: DateTime.tryParse(
            (m['created_at'] ?? m['at'] ?? m['timestamp'])?.toString() ?? ''),
      );
}
