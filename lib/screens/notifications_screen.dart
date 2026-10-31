import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '../models/app_notification.dart';
import '../theme/app_theme.dart';

import 'notification_settings_screen.dart';
import 'notifications_tab.dart';
import '../services/api_service.dart';
import '../core/navigation/notification_deep_link_resolver.dart';
import '../services/notification_service.dart';
import '../models/news_article.dart';
import '../models/notification_target.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // No login needed: guests get the device inbox plus pushes kept on the
    // device; logged-in readers get their account inbox as well.
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    await AppState.instance.fetchNotifications();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'నోటిఫికేషన్లు',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'ఇన్‌బాక్స్'),
              Tab(text: 'యాక్టివిటీ డైజెస్ట్'),
            ],
          ),
          actions: [
            AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                if (AppState.instance.unreadNotificationsCount == 0) {
                  return const SizedBox.shrink();
                }
                // An icon, so the screen title is not squeezed to "నో...".
                return IconButton(
                  key: const Key('notifications_mark_all_read'),
                  icon: const Icon(Icons.done_all_rounded,
                      color: AppColors.primary),
                  tooltip: 'అన్నీ చదివినట్లు గుర్తించు',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    AppState.instance.markAllNotificationsRead();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                      content: Text('అన్నీ చదివినట్లు గుర్తించబడ్డాయి'),
                    ));
                  },
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.tune_rounded,
                  color: isDark ? Colors.white70 : Colors.black87),
              tooltip: 'నోటిఫికేషన్ సెట్టింగ్‌లు',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                final notifications = AppState.instance.notifications;

                if (_isLoading && notifications.isEmpty) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }

                if (notifications.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _loadNotifications,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: _buildEmptyState(isDark),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.primary,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(
                          notifications[index], isDark);
                    },
                  ),
                );
              },
            ),
            const NotificationsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            'ఇంకా ఎలాంటి నోటిఫికేషన్లు లేవు',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'కొత్త అప్‌డేట్‌లు వచ్చినప్పుడు మీకు ఇక్కడ తెలియజేస్తాము.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, bool isDark) {
    final bool isUnread = !notification.isRead;

    // Determine icon and color based on type
    IconData icon;
    Color iconColor;
    switch (notification.type) {
      case NotificationType.approved:
        icon = Icons.check_circle_outline_rounded;
        iconColor = Colors.green;
        break;
      case NotificationType.rejected:
        icon = Icons.cancel_outlined;
        iconColor = Colors.red;
        break;
      case NotificationType.pending:
        icon = Icons.hourglass_empty_rounded;
        iconColor = Colors.amber;
        break;
      case NotificationType.announcement:
        // By delivery_category; `type` is targeting (all/single/segment).
        // Unknown: a neutral bell, not a party popper.
        switch (notification.deliveryCategory) {
          case 'breaking':
            icon = Icons.bolt_rounded;
            iconColor = Colors.red;
            break;
          case 'local':
            icon = Icons.location_on_outlined;
            iconColor = AppColors.primary;
            break;
          case 'alert':
            icon = Icons.warning_amber_rounded;
            iconColor = Colors.orange;
            break;
          case 'festival':
            icon = Icons.celebration_outlined;
            iconColor = AppColors.primary;
            break;
          case 'promotion':
            icon = Icons.local_offer_outlined;
            iconColor = AppColors.primary;
            break;
          default:
            icon = Icons.notifications_none_rounded;
            iconColor = Colors.grey;
        }
        break;
    }

    return GestureDetector(
      onTap: () async {
        if (isUnread) {
          HapticFeedback.lightImpact();
          // Sends the server row id; device-only copies sync at the merge.
          AppState.instance.markNotificationRead(notification.id);
        }

        final target = NotificationDeepLinkResolver.resolveFromAppNotification(
            notification);
        if (mounted) {
          NotificationService.instance
              .navigateToTarget(target, context: context);
        }
      },
      // News-style row: picture on the left; headline (2 lines), a short
      // summary (2 lines) and the time on the right — full width for text.
      child: Container(
        key: Key('notification_card_${notification.id}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : AppColors.primary.withValues(alpha: 0.04))
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.25)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumbnail(notification, icon, iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.35,
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  if (_showMessage(notification)) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.message.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatTimestamp(notification.timestamp),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black45,
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          key: const Key('notification_unread_dot'),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The news picture, or the type icon on a tinted square when there is none.
  Widget _thumbnail(AppNotification n, IconData icon, Color iconColor) {
    const size = 84.0;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 30),
    );
    final url = n.imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      // No picture in the notification: show the story's own photo.
      return _StoryImage(
        key: ValueKey('notification_story_image_${n.id}'),
        notification: n,
        size: size,
        fallback: fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 252,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                width: size,
                height: size,
                color: iconColor.withValues(alpha: 0.06),
              ),
      ),
    );
  }

  /// The summary line, unless it only repeats the headline (news pushes
  /// often send the same text as title and body).
  static bool _showMessage(AppNotification n) {
    String norm(String s) =>
        s.replaceAll(RegExp(r'[\s.…।,!?]+'), '').toLowerCase();
    final m = norm(n.message);
    if (m.isEmpty) return false;
    final t = norm(n.title);
    return m != t && !t.startsWith(m);
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return 'ఇప్పుడే';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} నిమిషాల కిందట';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} గంటల కిందట';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} రోజుల కిందట';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}

/// Thumbnail for a notification that carries no image: looks up the story it
/// opens (article or reader post) and shows that story's photo. Lookups are
/// cached per story, so scrolling the inbox does not refetch.
class _StoryImage extends StatefulWidget {
  const _StoryImage({
    super.key,
    required this.notification,
    required this.size,
    required this.fallback,
  });

  final AppNotification notification;
  final double size;
  final Widget fallback;

  static final Map<String, Future<String?>> _cache = {};

  @override
  State<_StoryImage> createState() => _StoryImageState();
}

class _StoryImageState extends State<_StoryImage> {
  Future<String?>? _image;

  @override
  void initState() {
    super.initState();
    final target = NotificationDeepLinkResolver.resolveFromAppNotification(
        widget.notification);
    final id = target.identifier?.trim() ?? '';
    if (id.isEmpty) return;
    final api = ApiService.instance;
    switch (target.type) {
      case NotificationTargetType.article:
        _image = _StoryImage._cache
            .putIfAbsent('article:$id', () => _pick(api.getArticleDetail(id)));
      case NotificationTargetType.ugc:
        _image = _StoryImage._cache
            .putIfAbsent('ugc:$id', () => _pick(api.getUgcDetail(id)));
      default:
        break;
    }
  }

  static Future<String?> _pick(Future<NewsArticle> detail) async {
    try {
      final a = await detail;
      final candidates = [a.imageUrl, ...?a.imageUrls];
      for (final c in candidates) {
        if (c.trim().startsWith('http')) return c.trim();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return widget.fallback;
    return FutureBuilder<String?>(
      future: image,
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) return widget.fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            cacheWidth: 252,
            errorBuilder: (_, __, ___) => widget.fallback,
          ),
        );
      },
    );
  }
}
