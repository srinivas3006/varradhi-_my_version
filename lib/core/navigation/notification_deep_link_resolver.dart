import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/app_notification.dart';
import '../../models/notification_target.dart';

/// Centralized parser for deep link URIs and push notification payloads.
/// Decouples raw string URLs and FCM payload structures from UI widgets and navigation code.
class NotificationDeepLinkResolver {
  const NotificationDeepLinkResolver._();

  /// Resolves a raw deep link string into a strongly-typed [NotificationTarget].
  /// Handles custom schemes (`varadhi://`, `article://`, `screen://`) as well as relative paths.
  static NotificationTarget resolveFromUri(
    String? rawUriString, {
    String? notificationId,
    Map<String, dynamic>? originalPayload,
  }) {
    if (rawUriString == null || rawUriString.trim().isEmpty) {
      return NotificationTarget.unknown(
        rawUri: rawUriString,
        originalPayload: originalPayload,
      );
    }

    final trimmed = rawUriString.trim();

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (e) {
      debugPrint('[DeepLinkResolver] Failed to parse URI "$trimmed": $e');
      return NotificationTarget.unknown(
        rawUri: trimmed,
        originalPayload: originalPayload,
      );
    }

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    // 1. Handle scheme: "varadhi://"
    if (scheme == 'varadhi') {
      // e.g. varadhi://category/education -> host = "category", pathSegments = ["education"]
      // e.g. varadhi:///category/education -> host = "", pathSegments = ["category", "education"]
      final primaryType = host.isNotEmpty
          ? host
          : (segments.isNotEmpty ? segments[0].toLowerCase() : '');
      final remainingSegments = host.isNotEmpty
          ? segments
          : (segments.length > 1 ? segments.sublist(1) : <String>[]);

      return _resolveSegments(
        type: primaryType,
        segments: remainingSegments,
        notificationId: notificationId,
        originalPayload: originalPayload,
        rawUri: trimmed,
      );
    }

    // 1b. Handle the public site over https — Android App Links and iOS
    // Universal Links arrive as real URLs, not as varadhi:// . Without this
    // a tapped share link resolved to unknown and opened Home.
    //
    // Paths are /article/{slug}/, /poster/{id}/, /video/{id}/, /poll/{id}/
    // and /ugc/{id}/ — the trailing slash leaves an empty last segment,
    // which is dropped here.
    if ((scheme == 'https' || scheme == 'http') &&
        (host == 'vaaradhinews.com' || host == 'www.vaaradhinews.com')) {
      final parts = segments.where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2) {
        return _resolveSegments(
          type: parts.first.toLowerCase(),
          segments: parts.sublist(1),
          notificationId: notificationId,
          originalPayload: originalPayload,
          rawUri: trimmed,
        );
      }
    }

    // 2. Handle scheme: "article://"
    if (scheme == 'article') {
      final slug =
          host.isNotEmpty ? host : (segments.isNotEmpty ? segments[0] : null);
      if (slug != null && slug.isNotEmpty) {
        return NotificationTarget.article(
          slugOrId: slug,
          notificationId: notificationId,
          originalPayload: originalPayload,
        );
      }
    }

    // 3. Handle scheme: "screen://"
    if (scheme == 'screen') {
      final screen =
          host.isNotEmpty ? host : (segments.isNotEmpty ? segments[0] : null);
      if (screen != null && screen.isNotEmpty) {
        final requiresAuth = screen == 'profile' || screen == 'bookmarks';
        return NotificationTarget.screen(
          screenName: screen,
          notificationId: notificationId,
          requiresAuth: requiresAuth,
          originalPayload: originalPayload,
        );
      }
    }

    // 4. Handle relative paths like "/article/slug" or "/category/slug"
    if (trimmed.startsWith('/')) {
      if (segments.isNotEmpty) {
        // Forward every remaining segment: multi-segment paths like
        // "/admin/ugc/reports" and "/ugc/reporter/dashboard" need more than
        // the first one, and each case below validates what it receives.
        return _resolveSegments(
          type: segments[0].toLowerCase(),
          segments: segments.sublist(1),
          notificationId: notificationId,
          originalPayload: originalPayload,
          rawUri: trimmed,
        );
      }
    }

    return NotificationTarget.unknown(
      rawUri: trimmed,
      originalPayload: originalPayload,
    );
  }

  /// Resolves an FCM push notification payload map.
  static NotificationTarget resolveFromPayload(Map<String, dynamic> rawData) {
    if (rawData.isEmpty) {
      return NotificationTarget.unknown(originalPayload: rawData);
    }

    // Unwrap nested JSON payload if present (e.g. backend sends serialized json string under 'payload' or 'data')
    Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
    if (data.containsKey('data') && data['data'] is String) {
      try {
        final decoded = Uri.decodeComponent(data['data'] as String);
        if (decoded.trim().startsWith('{')) {
          // Attempt JSON parse if valid string
          data.addAll(Map<String, dynamic>.from(
            // ignore: unnecessary_cast
            (jsonDecode(decoded) as Map),
          ));
        }
      } catch (_) {}
    } else if (data.containsKey('data') && data['data'] is Map) {
      data.addAll(Map<String, dynamic>.from(data['data'] as Map));
    }

    if (data.containsKey('payload') && data['payload'] is Map) {
      data.addAll(Map<String, dynamic>.from(data['payload'] as Map));
    }

    final notificationId =
        data['notification_id']?.toString() ?? data['id']?.toString();
    final deepLink = data['deep_link']?.toString() ?? data['click_action']?.toString();

    // 1. If explicit deep_link is present, prioritize it
    if (deepLink != null && deepLink.trim().isNotEmpty) {
      final fromUri = resolveFromUri(
        deepLink,
        notificationId: notificationId,
        originalPayload: data,
      );
      if (fromUri.type != NotificationTargetType.unknown) {
        return fromUri;
      }
    }

    // 2. Fall back to structured backend payload fields
    //
    // `content_type` is only one of the spellings the backend uses. Reading
    // it alone meant a payload keyed `type` or `entity_type` resolved to
    // unknown, the gate discarded it, and the tap left the reader on Home —
    // which is what "notifications always open Home" actually was.
    final contentType = (data['content_type'] ??
            data['type'] ??
            data['entity_type'] ??
            data['notification_type'])
        ?.toString()
        .toLowerCase();
    final contentSlug = data['content_slug']?.toString() ?? data['slug']?.toString();
    final contentId = data['content_id']?.toString() ?? data['article_id']?.toString() ?? data['id']?.toString();
    final categorySlug = data['category_slug']?.toString() ?? data['category']?.toString();

    // Category target
    if (contentType == 'category' ||
        (categorySlug != null && categorySlug.isNotEmpty && contentType != 'article')) {
      final cat = (categorySlug != null && categorySlug.isNotEmpty)
          ? categorySlug
          : contentSlug;
      if (cat != null && cat.isNotEmpty) {
        return NotificationTarget.category(
          categorySlug: cat,
          notificationId: notificationId,
          originalPayload: data,
        );
      }
    }

    // Article target
    if (contentType == 'article' ||
        contentType == 'news' ||
        contentType == 'quote' ||
        contentType == 'breaking' ||
        // No dedicated video target exists; a video notification opens the
        // story that carries it. 'ugc' is deliberately NOT here — it has its
        // own branch below, and listing it here shadowed that.
        contentType == 'video' ||
        (contentSlug != null && contentSlug.isNotEmpty && contentType == null)) {
      final slug = (contentSlug != null && contentSlug.isNotEmpty)
          ? contentSlug
          : contentId;
      if (slug != null && slug.isNotEmpty) {
        return NotificationTarget.article(
          slugOrId: slug,
          notificationId: notificationId,
          originalPayload: data,
        );
      }
    }

    // Poster target
    if (contentType == 'poster') {
      final pId =
          (contentId != null && contentId.isNotEmpty) ? contentId : contentSlug;
      if (pId != null && pId.isNotEmpty) {
        return NotificationTarget.poster(
          posterId: pId,
          notificationId: notificationId,
          originalPayload: data,
        );
      }
    }

    // Admin moderation target. Checked before plain UGC so a moderation
    // alert opens the console rather than the public submission view.
    if (contentType == 'admin' || contentType == 'admin_ugc') {
      final section = data['admin_section']?.toString().toLowerCase();
      final aId =
          (contentId != null && contentId.isNotEmpty) ? contentId : contentSlug;
      return NotificationTarget.admin(
        section: (aId == null || aId.isEmpty) ? (section ?? 'queue') : section,
        submissionId: aId,
        notificationId: notificationId,
        originalPayload: data,
      );
    }

    // UGC target
    if (contentType == 'ugc') {
      final uId =
          (contentId != null && contentId.isNotEmpty) ? contentId : contentSlug;
      return NotificationTarget.ugc(
        submissionId: uId,
        notificationId: notificationId,
        requiresAuth: false,
        originalPayload: data,
      );
    }

    return NotificationTarget.unknown(originalPayload: data);
  }

  /// Resolves an [AppNotification] domain model from the inbox.
  static NotificationTarget resolveFromAppNotification(
      AppNotification notification) {
    if (notification.deepLink != null &&
        notification.deepLink!.trim().isNotEmpty) {
      final target = resolveFromUri(
        notification.deepLink,
        notificationId: notification.notificationId ?? notification.id,
      );
      if (target.type != NotificationTargetType.unknown) {
        return target;
      }
    }

    // Fall back to notification model attributes
    final payload = <String, dynamic>{
      'notification_id': notification.notificationId ?? notification.id,
      'content_type': notification.contentType,
      'content_id': notification.contentId,
      'content_slug': notification.contentSlug,
      'deep_link': notification.deepLink,
    };

    return resolveFromPayload(payload);
  }

  static NotificationTarget _resolveSegments({
    required String type,
    required List<String> segments,
    required String? notificationId,
    required Map<String, dynamic>? originalPayload,
    required String rawUri,
  }) {
    switch (type) {
      case 'category':
        if (segments.isNotEmpty && segments[0].isNotEmpty) {
          return NotificationTarget.category(
            categorySlug: segments[0],
            notificationId: notificationId,
            originalPayload: originalPayload,
          );
        }
        break;

      case 'article':
        if (segments.isNotEmpty && segments[0].isNotEmpty) {
          return NotificationTarget.article(
            slugOrId: segments[0],
            notificationId: notificationId,
            originalPayload: originalPayload,
          );
        }
        break;

      case 'poster':
        if (segments.isNotEmpty && segments[0].isNotEmpty) {
          return NotificationTarget.poster(
            posterId: segments[0],
            notificationId: notificationId,
            originalPayload: originalPayload,
          );
        }
        break;

      // A video or Short opens the story that carries it; there is no
      // dedicated video target, and the article screen already plays it.
      case 'video':
      case 'short':
        if (segments.isNotEmpty && segments[0].isNotEmpty) {
          return NotificationTarget.article(
            slugOrId: segments[0],
            notificationId: notificationId,
            originalPayload: originalPayload,
          );
        }
        break;

      // Polls live in the feed rather than on their own screen, so a poll
      // link opens the feed. Replace with a poll target once one exists.
      case 'poll':
        if (segments.isNotEmpty && segments[0].isNotEmpty) {
          return NotificationTarget.screen(
            screenName: 'home',
            notificationId: notificationId,
            originalPayload: originalPayload,
          );
        }
        break;

      case 'ugc':
        // e.g. varadhi://ugc/reporter/dashboard or varadhi://ugc/submit or varadhi://ugc/{id}
        String? action;
        String? id;
        if (segments.isNotEmpty) {
          if (segments[0] == 'reporter' &&
              segments.length > 1 &&
              segments[1] == 'dashboard') {
            action = 'dashboard';
          } else if (segments[0] == 'submit') {
            action = 'submit';
          } else {
            id = segments[0];
          }
        }
        return NotificationTarget.ugc(
          submissionId: id,
          action: action,
          notificationId: notificationId,
          requiresAuth: action != null,
          originalPayload: originalPayload,
        );

      case 'admin':
        // e.g. /admin/ugc, /admin/ugc/reports, /admin/ugc/logs, /admin/ugc/{id}
        // — the paths the admin backend sends. Anything that is not a known
        // section is read as a submission id.
        if (segments.isEmpty || segments[0].toLowerCase() != 'ugc') {
          break;
        }
        const sections = {'reports', 'logs', 'otp', 'queue'};
        final tail = segments.length > 1 ? segments[1] : '';
        if (tail.isEmpty) {
          return NotificationTarget.admin(
            section: 'queue',
            notificationId: notificationId,
            originalPayload: originalPayload,
          );
        }
        if (sections.contains(tail.toLowerCase())) {
          return NotificationTarget.admin(
            section: tail.toLowerCase(),
            notificationId: notificationId,
            originalPayload: originalPayload,
          );
        }
        return NotificationTarget.admin(
          submissionId: tail,
          notificationId: notificationId,
          originalPayload: originalPayload,
        );

      case 'screen':
        if (segments.isNotEmpty && segments[0].isNotEmpty) {
          final screen = segments[0];
          return NotificationTarget.screen(
            screenName: screen,
            notificationId: notificationId,
            requiresAuth: screen == 'profile' || screen == 'bookmarks',
            originalPayload: originalPayload,
          );
        }
        break;
    }

    return NotificationTarget.unknown(
      rawUri: rawUri,
      originalPayload: originalPayload,
    );
  }
}
