enum NotificationType {
  pending,
  approved,
  rejected,
  announcement,
}

class AppNotification {
  final String id;
  final String? notificationId;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final String? contentType;
  final String? contentId;
  final String? contentSlug;
  final String? notificationType;
  final String? imageUrl;
  final String? deepLink;
  bool isRead;

  AppNotification({
    required this.id,
    this.notificationId,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.contentType,
    this.contentId,
    this.contentSlug,
    this.notificationType,
    this.imageUrl,
    this.deepLink,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    NotificationType nType = NotificationType.announcement;
    final rawType = (json['type'] ?? json['notification_type'] ?? '').toString().toLowerCase();
    if (rawType.contains('approv')) {
      nType = NotificationType.approved;
    } else if (rawType.contains('reject')) {
      nType = NotificationType.rejected;
    } else if (rawType.contains('pend')) {
      nType = NotificationType.pending;
    }

    final createdAtStr = json['notification_created_at'] ?? json['created_at'] ?? json['timestamp'];
    DateTime dt = DateTime.now();
    if (createdAtStr != null) {
      dt = DateTime.tryParse(createdAtStr.toString()) ?? DateTime.now();
    }

    return AppNotification(
      id: json['id']?.toString() ?? json['notification_id']?.toString() ?? '',
      notificationId: json['notification_id']?.toString(),
      title: json['title']?.toString() ?? '',
      message: (json['body'] ?? json['message'])?.toString() ?? '',
      timestamp: dt,
      type: nType,
      contentType: json['content_type']?.toString(),
      contentId: json['content_id']?.toString(),
      contentSlug: json['content_slug']?.toString(),
      notificationType: (json['notification_type'] ?? json['type'])?.toString(),
      imageUrl: json['image_url']?.toString(),
      deepLink: json['deep_link']?.toString(),
      isRead: json['is_read'] == true,
    );
  }
}

