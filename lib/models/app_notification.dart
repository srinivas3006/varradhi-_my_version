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

  /// breaking | local | alert | festival | promotion — picks the icon.
  final String? deliveryCategory;
  final String? schemaVersion;
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
    this.deliveryCategory,
    this.schemaVersion,
    this.isRead = false,
  });

  /// Kept on the device only (a push not yet matched with the server inbox):
  /// its id is not a server inbox row id.
  bool get isLocal => id.startsWith('push_');

  /// `type` in a push is targeting (all | single | segment), never the kind
  /// of notification.
  static const _targetingTypes = {'all', 'single', 'segment'};

  static String? _clean(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    NotificationType nType = NotificationType.announcement;
    final legacyType = _clean(json['type']);
    final kind = _clean(json['notification_type']) ??
        _clean(json['event_type']) ??
        (_targetingTypes.contains(legacyType?.toLowerCase())
            ? null
            : legacyType);
    final rawType = (kind ?? '').toLowerCase();
    if (rawType.contains('approv')) {
      nType = NotificationType.approved;
    } else if (rawType.contains('reject')) {
      nType = NotificationType.rejected;
    } else if (rawType.contains('pend')) {
      nType = NotificationType.pending;
    }

    final createdAtStr = json['notification_created_at'] ??
        json['created_at'] ??
        json['timestamp'];
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
      notificationType: kind,
      imageUrl: imageFrom(json),
      deepLink: json['deep_link']?.toString(),
      deliveryCategory: _clean(json['delivery_category'])?.toLowerCase(),
      schemaVersion: _clean(json['schema_version']),
      isRead: json['is_read'] == true,
    );
  }

  static const _imageKeys = [
    'image_url',
    'image',
    'imageUrl',
    'thumbnail_url',
    'thumbnail',
    'cover_image_url',
    'cover_image',
    'featured_image',
    'featured_image_url',
    'media_url',
  ];

  /// The picture's URL under any key the inbox API or a push payload uses,
  /// including a nested `data` / `payload` / `content` map; null if none.
  static String? imageFrom(Map<String, dynamic> json) {
    for (final k in _imageKeys) {
      final v = json[k]?.toString().trim() ?? '';
      if (v.startsWith('http')) return v;
    }
    for (final nest in const ['data', 'payload', 'content', 'extra_data']) {
      final m = json[nest];
      if (m is Map) {
        final found = imageFrom(Map<String, dynamic>.from(m));
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Round-trips through [AppNotification.fromJson]; used for the on-device
  /// inbox that keeps received pushes (guests included).
  Map<String, dynamic> toJson() => {
        'id': id,
        if (notificationId != null) 'notification_id': notificationId,
        'title': title,
        'body': message,
        'created_at': timestamp.toIso8601String(),
        if (notificationType != null) 'notification_type': notificationType,
        if (contentType != null) 'content_type': contentType,
        if (contentId != null) 'content_id': contentId,
        if (contentSlug != null) 'content_slug': contentSlug,
        if (imageUrl != null) 'image_url': imageUrl,
        if (deepLink != null) 'deep_link': deepLink,
        if (deliveryCategory != null) 'delivery_category': deliveryCategory,
        if (schemaVersion != null) 'schema_version': schemaVersion,
        'is_read': isRead,
      };
}
