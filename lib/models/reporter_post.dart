enum PostType { image, video }

enum PostStatus { pending, approved, published, rejected }

class ReporterPost {
  final String id;
  final String reporterName;
  final PostType type;
  final String caption;
  final String category;
  final String mediaUrl;
  PostStatus status;
  final DateTime submittedAt;
  String? rejectionReason;

  ReporterPost({
    required this.id,
    required this.reporterName,
    required this.type,
    required this.caption,
    required this.category,
    required this.mediaUrl,
    this.status = PostStatus.pending,
    required this.submittedAt,
    this.rejectionReason,
  });
}
