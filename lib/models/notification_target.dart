/// Types of destinations that can be resolved from push notifications or deep links.
enum NotificationTargetType {
  article,
  category,
  poster,
  ugc,
  screen,
  unknown,
}

/// Represents a validated, strongly-typed destination for notification
/// and deep link navigation.
class NotificationTarget {
  final NotificationTargetType type;
  final String? identifier;
  final String? screenName;
  final String? notificationId;
  final bool requiresAuth;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic>? originalPayload;

  const NotificationTarget({
    required this.type,
    this.identifier,
    this.screenName,
    this.notificationId,
    this.requiresAuth = false,
    this.parameters = const {},
    this.originalPayload,
  });

  factory NotificationTarget.article({
    required String slugOrId,
    String? notificationId,
    Map<String, dynamic>? originalPayload,
  }) {
    return NotificationTarget(
      type: NotificationTargetType.article,
      identifier: slugOrId,
      notificationId: notificationId,
      originalPayload: originalPayload,
    );
  }

  factory NotificationTarget.category({
    required String categorySlug,
    String? notificationId,
    Map<String, dynamic>? originalPayload,
  }) {
    return NotificationTarget(
      type: NotificationTargetType.category,
      identifier: categorySlug,
      notificationId: notificationId,
      originalPayload: originalPayload,
    );
  }

  factory NotificationTarget.poster({
    required String posterId,
    String? notificationId,
    Map<String, dynamic>? originalPayload,
  }) {
    return NotificationTarget(
      type: NotificationTargetType.poster,
      identifier: posterId,
      notificationId: notificationId,
      originalPayload: originalPayload,
    );
  }

  factory NotificationTarget.ugc({
    String? submissionId,
    String? action, // 'dashboard' or 'submit' or null
    String? notificationId,
    bool requiresAuth = false,
    Map<String, dynamic>? originalPayload,
  }) {
    return NotificationTarget(
      type: NotificationTargetType.ugc,
      identifier: submissionId,
      screenName: action,
      notificationId: notificationId,
      requiresAuth: requiresAuth,
      originalPayload: originalPayload,
    );
  }

  factory NotificationTarget.screen({
    required String screenName,
    String? notificationId,
    bool requiresAuth = false,
    Map<String, dynamic>? originalPayload,
  }) {
    return NotificationTarget(
      type: NotificationTargetType.screen,
      screenName: screenName,
      notificationId: notificationId,
      requiresAuth: requiresAuth,
      originalPayload: originalPayload,
    );
  }

  factory NotificationTarget.unknown({
    String? rawUri,
    Map<String, dynamic>? originalPayload,
  }) {
    return NotificationTarget(
      type: NotificationTargetType.unknown,
      identifier: rawUri,
      originalPayload: originalPayload,
    );
  }

  @override
  String toString() =>
      'NotificationTarget(type: $type, id: $identifier, screen: $screenName, requiresAuth: $requiresAuth)';
}
